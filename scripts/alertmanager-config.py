"""Select a native webhook receiver without requiring an unprovisioned secret.

Only the private runtime file contains a URL. Never print URLs or exception text.
"""
import json
import os
from pathlib import Path
import sys
from urllib.parse import urlsplit


def render(configuration, secret):
    try:
        url = secret.read_text().strip()
    except FileNotFoundError:
        print("n8n webhook URL missing; alert delivery disabled", file=sys.stderr)
        return configuration
    except OSError:
        print("n8n webhook URL unreadable; alert delivery disabled", file=sys.stderr)
        return configuration
    try:
        valid = bool(urlsplit(url).hostname) and urlsplit(url).scheme in ("http", "https")
    except ValueError:
        valid = False
    if not valid:
        print("n8n webhook URL invalid; alert delivery disabled", file=sys.stderr)
        return configuration
    configuration["receivers"][0]["webhook_configs"] = [
        {"url": url, "send_resolved": True, "max_alerts": 10, "timeout": "10s"}
    ]
    return configuration


if __name__ == "__main__":
    source, secret, output = map(Path, sys.argv[1:])
    os.umask(0o077)
    output.write_text(json.dumps(render(json.loads(source.read_text()), secret)))
