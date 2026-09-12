#!/usr/bin/env python3
"""Offline source/pin/schema inventory. Never connects, activates or migrates."""

import argparse
import ast
import hashlib
import json
from pathlib import Path
import subprocess
import sys


def git(repo, *args):
    return subprocess.check_output(
        ["git", "-C", str(repo), *args], text=True, stderr=subprocess.PIPE
    ).strip()


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def event_chain(repo):
    revisions = {}
    for path in sorted((repo / "alembic/versions").glob("*.py")):
        values = {}
        for node in ast.parse(path.read_text()).body:
            if isinstance(node, ast.Assign):
                for target in node.targets:
                    if isinstance(target, ast.Name) and target.id in (
                        "revision", "down_revision"
                    ):
                        values[target.id] = ast.literal_eval(node.value)
        if "revision" in values:
            revision = values["revision"]
            if revision in revisions:
                raise ValueError("Duplicate Events revision")
            revisions[revision] = values["down_revision"]
    ordered = []
    previous = None
    while len(ordered) < len(revisions):
        next_ids = [r for r, parent in revisions.items() if parent == previous]
        if len(next_ids) != 1 or next_ids[0] in ordered:
            raise ValueError("Events migrations are not one complete linear chain")
        previous = next_ids[0]
        ordered.append(previous)
    return ordered


def schema_plan(backend, events, backend_file, events_file):
    names = sorted(p.name for p in (backend / "academy_persistence/postgres/migrations").iterdir() if p.is_dir())
    applied = backend_file.read_text().splitlines()
    if len(applied) != len(set(applied)) or sorted(applied) != names[:len(applied)]:
        raise ValueError("Backend applied names are unknown, duplicate or not a release prefix")
    current = events_file.read_text().splitlines()
    chain = event_chain(events)
    if len(current) > 1 or (current and current[0] not in chain):
        raise ValueError("Events database has an unknown or multiple migration heads")
    offset = chain.index(current[0]) + 1 if current else 0
    return {"backend_applied": sorted(applied), "backend_pending": names[len(applied):],
            "events_applied_head": current, "events_pending": chain[offset:]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--workspace", type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument("--manifest", type=Path, required=True, help="path to the separately maintained release manifest")
    parser.add_argument("--check-pins", action="store_true", help="also fail if locked prod/test source trees differ from selected applications")
    parser.add_argument("--backend-applied", type=Path, help="one exact _migrations.name per line; empty only for a verified new database")
    parser.add_argument("--events-applied", type=Path, help="events_alembic_version.version_num; empty only for a verified new database")
    args = parser.parse_args()
    if bool(args.backend_applied) != bool(args.events_applied):
        parser.error("provide both schema inventory files")
    root = args.workspace.resolve()
    manifest = json.loads(args.manifest.read_text())
    errors = []
    report = {"scope": "offline inventory only; not release approval", "manifest_sha256": sha(args.manifest), "repositories": {}, "pins": {}}
    for name, selected in manifest["applications"].items():
        repo = root / name
        actual = {"commit": git(repo, "rev-parse", "HEAD"), "tree": git(repo, "rev-parse", "HEAD^{tree}")}
        report["repositories"][name] = actual
        if actual != selected or git(repo, "status", "--porcelain", "--untracked-files=normal"):
            errors.append(f"{name}: selected commit/tree or clean worktree mismatch")
    infra = root / "infrastructure"
    report["infrastructure_commit"] = git(infra, "rev-parse", "HEAD")
    report["infrastructure_tree"] = git(infra, "rev-parse", "HEAD^{tree}")
    git(infra, "merge-base", "--is-ancestor", manifest["infrastructure_base_commit"], "HEAD")
    if git(infra, "status", "--porcelain", "--untracked-files=normal"):
        errors.append("infrastructure: uncommitted files; commit reviewed source before recording release inventory")
    for relative, expected in manifest["source_sha256"].items():
        path = root / relative
        if not path.is_file() or sha(path) != expected:
            errors.append(f"source digest mismatch: {relative}")
    lock = json.loads((infra / "flake.lock").read_text())
    for host, suffix in (("prod", ""), ("test", "-develop")):
        for name in ("backend", "events-ms", "skills-ms", "jobs-ms", "challenges-ms"):
            key = name + suffix
            node = lock["nodes"][lock["nodes"]["root"]["inputs"][key]]["locked"]
            pin = {"revision": node["rev"], "narHash": node["narHash"]}
            try:
                pin["tree"] = git(root / name, "rev-parse", "--verify", node["rev"] + "^{tree}")
                pin["matches_selected_tree"] = pin["tree"] == manifest["applications"][name]["tree"]
            except subprocess.CalledProcessError:
                pin["matches_selected_tree"] = False
                pin["error"] = "pinned commit object unavailable locally; no fetch attempted"
            report["pins"][host + "/" + key] = pin
            if args.check_pins and not pin["matches_selected_tree"]:
                errors.append(f"{host}/{key}: locked tree is not the selected reviewed tree")
    if args.backend_applied:
        report["schema_plan"] = schema_plan(root / "backend", root / "events-ms", args.backend_applied, args.events_applied)
        report["schema_inventory_sha256"] = {"backend": sha(args.backend_applied), "events": sha(args.events_applied)}
    report["errors"] = errors
    print(json.dumps(report, indent=2, sort_keys=True))
    return bool(errors)


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError, KeyError, subprocess.CalledProcessError) as error:
        print(f"preflight refused: {error}", file=sys.stderr)
        sys.exit(2)
