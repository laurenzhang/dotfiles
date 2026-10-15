#!/usr/bin/env python3
"""Adds the defaults in workstation/pi-settings.json to ~/.pi/agent/settings.json, keeping every other setting.

A key that is already set is left alone, so a value you changed by hand survives a re-run.
"""
import json
import os
import sys
import tempfile

repo = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
settings_path = os.path.join(os.environ["HOME"], ".pi", "agent", "settings.json")

with open(os.path.join(repo, "workstation", "pi-settings.json")) as f:
    defaults = json.load(f)

try:
    with open(settings_path) as f:
        settings = json.load(f)
except FileNotFoundError:
    settings = {}
except ValueError as error:
    sys.exit(f"error: {settings_path} is not valid JSON ({error}); fix it, then re-run")

missing = {key: value for key, value in defaults.items() if key not in settings}
if not missing:
    print("Pi settings already set")
    sys.exit(0)

settings.update(missing)
os.makedirs(os.path.dirname(settings_path), exist_ok=True)
fd, tmp = tempfile.mkstemp(dir=os.path.dirname(settings_path))
with os.fdopen(fd, "w") as f:
    json.dump(settings, f, indent=2)
    f.write("\n")
os.replace(tmp, settings_path)
print(f"Set {', '.join(missing)} in {settings_path}")
