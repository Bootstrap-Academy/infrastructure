import contextlib
import importlib.util
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch


def load(name):
    spec = importlib.util.spec_from_file_location(name, Path(__file__).with_name(f"{name}.py"))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


receiver = load("alertmanager-config")
metrics = load("backup-metrics")


class AlertingTests(unittest.TestCase):
    def test_missing_or_invalid_secret_disables_delivery_without_exposing_it(self):
        with tempfile.TemporaryDirectory() as directory:
            secret = Path(directory) / "url"
            for value in [None, "invalid-private-value"]:
                if value is not None:
                    secret.write_text(value)
                base = {"receivers": [{"name": "n8n"}]}
                log = io.StringIO()
                with contextlib.redirect_stderr(log):
                    result = receiver.render(base, secret)
                self.assertNotIn("webhook_configs", result["receivers"][0])
                self.assertIn("delivery disabled", log.getvalue())
                self.assertNotIn("invalid-private-value", log.getvalue())

    def test_present_secret_selects_native_webhook_with_resolutions(self):
        with tempfile.TemporaryDirectory() as directory:
            secret = Path(directory) / "url"
            secret.write_text("https://receiver.example.test/webhook/test\n")
            result = receiver.render({"receivers": [{"name": "n8n"}]}, secret)
            webhook = result["receivers"][0]["webhook_configs"][0]
            self.assertTrue(webhook["send_resolved"])
            self.assertEqual(webhook["url"], secret.read_text().strip())

    def test_failed_backup_retains_last_success_and_restart_does_not_invent_one(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for timestamp, result in [(100.1, "init"), (101.1, "success"), (101.2, "timeout"), (102.1, "init")]:
                with patch.object(metrics.time, "time", return_value=timestamp):
                    metrics.record(root, "restic-backups-box", result)
            state = json.loads((root / "restic-backups-box.json").read_text())
            self.assertEqual(state, {"observed_since": 100.1, "last_success": 101.1, "last_failure": 101.2})
            text = (root / "restic-backups-box.prom").read_text()
            self.assertIn('unit="restic-backups-box"', text)
            self.assertIn("last_failure_seconds", text)
            self.assertEqual(list(root.glob("*.tmp")), [])


if __name__ == "__main__":
    unittest.main()
