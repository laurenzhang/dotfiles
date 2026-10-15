#!/usr/bin/env python3
"""Registers the Bash guard hook in ~/.claude/settings.json, keeping every other setting. Safe to re-run."""
import json
import os
import sys
import tempfile

settings_path = os.path.join(os.environ["HOME"], ".claude", "settings.json")
command = "/usr/bin/python3 $HOME/.claude/hooks/guard.py"

try:
    with open(settings_path) as f:
        settings = json.load(f)
except FileNotFoundError:
    settings = {}
except ValueError as error:
    sys.exit(f"error: {settings_path} is not valid JSON ({error}); fix it, then re-run")

entries = settings.setdefault("hooks", {}).setdefault("PreToolUse", [])
if any(h.get("command") == command for e in entries for h in e.get("hooks", [])):
    print("Claude guard hook already registered")
    sys.exit(0)

entries.append({"matcher": "Bash", "hooks": [{"type": "command", "command": command, "timeout": 5}]})
os.makedirs(os.path.dirname(settings_path), exist_ok=True)
fd, tmp = tempfile.mkstemp(dir=os.path.dirname(settings_path))
with os.fdopen(fd, "w") as f:
    json.dump(settings, f, indent=2)
    f.write("\n")
os.replace(tmp, settings_path)
print(f"Registered the Claude guard hook in {settings_path}")
