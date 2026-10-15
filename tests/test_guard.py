import importlib.util
import json
import os
import subprocess
import sys
import unittest

HOOK = os.path.join(os.path.dirname(__file__), "..", "claude", ".claude", "hooks", "guard.py")
spec = importlib.util.spec_from_file_location("guard", HOOK)
guard = importlib.util.module_from_spec(spec)
spec.loader.exec_module(guard)

DENIED = {
    "git push origin main": "push-protected",
    "git push origin HEAD:main": "push-protected",
    "git push origin feature:refs/heads/master": "push-protected",
    "git push origin :production": "push-protected",
    "git push origin --delete main": "push-protected",
    "git push --all": "push-protected",
    "git -C /repo push origin main": "push-protected",
    "git status && git push origin main": "push-protected",
    "git status\ngit push origin main": "push-protected",
    "bash -c 'git push origin main'": "push-protected",
    "FOO=1 sudo git push origin main": "push-protected",
    "git push --force origin feature": "push-force",
    "git push -f origin feature": "push-force",
    "git push -uf origin feature": "push-force",
    "git push origin +feature": "push-force",
    "gh api repos/o/r --method DELETE": "gh-api-write",
    "gh api -X POST repos/o/r/issues": "gh-api-write",
    "gh api repos/o/r/issues -f title=x": "gh-api-write",
    "gh api graphql -f query='mutation { x }'": "gh-api-write",
    "gh pr comment 1 --body hi": "gh-write",
    "gh -R o/r pr review 1 --approve": "gh-write",
    "gh pr merge 1": "gh-write",
    "gh issue comment 1 -b hi": "gh-write",
    "gh repo delete o/r --yes": "gh-write",
    "gh secret set X": "gh-write",
    "terraform apply": "terraform-write",
    "terraform -chdir=infra destroy": "terraform-write",
    "tofu state rm aws_x.y": "terraform-write",
}

ALLOWED = [
    "git push origin feature",
    "git push -u origin my-main-fix",
    "git push --force-with-lease origin feature",
    "git push --force-with-lease --force-if-includes origin feature",
    "git push",
    "git commit -m 'do not git push origin main'",
    "git log --oneline main",
    "gh pr create --draft",
    "gh pr view 1 --comments",
    "gh pr checks",
    "gh api repos/o/r/pulls",
    "gh api repos/o/r --method GET",
    "gh api repos/o/r/issues -X GET -f state=open",
    "gh api graphql -f query='query { viewer { login } }'",
    "terraform plan",
    "terraform state list",
    "terraform fmt",
    "echo main",
    "",
]


class DecideTest(unittest.TestCase):
    def test_denied(self):
        for command, rule in DENIED.items():
            with self.subTest(command=command):
                found = guard.decide(command)
                self.assertIsNotNone(found)
                self.assertEqual(found[0], rule)

    def test_allowed(self):
        for command in ALLOWED:
            with self.subTest(command=command):
                self.assertIsNone(guard.decide(command))


class HookProtocolTest(unittest.TestCase):
    def run_hook(self, payload, **env):
        result = subprocess.run(
            [sys.executable, HOOK], input=json.dumps(payload), capture_output=True, text=True,
            env={**{k: v for k, v in os.environ.items() if k != "CLAUDE_GUARD_OVERRIDE"}, **env},
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        return result.stdout

    def bash(self, command):
        return {"tool_name": "Bash", "tool_input": {"command": command}}

    def test_deny_output(self):
        out = json.loads(self.run_hook(self.bash("git push origin main")))
        decision = out["hookSpecificOutput"]
        self.assertEqual(decision["permissionDecision"], "deny")
        self.assertIn("[push-protected]", decision["permissionDecisionReason"])

    def test_allow_is_silent(self):
        self.assertEqual(self.run_hook(self.bash("git status")), "")

    def test_other_tools_are_ignored(self):
        self.assertEqual(self.run_hook({"tool_name": "Write", "tool_input": {"command": "git push origin main"}}), "")

    def test_override(self):
        self.assertEqual(self.run_hook(self.bash("git push origin main"), CLAUDE_GUARD_OVERRIDE="push-protected"), "")
        self.assertNotEqual(self.run_hook(self.bash("git push origin main"), CLAUDE_GUARD_OVERRIDE="gh-write"), "")

    def test_bad_input_is_ignored(self):
        result = subprocess.run([sys.executable, HOOK], input="not json", capture_output=True, text=True)
        self.assertEqual((result.returncode, result.stdout), (0, ""))


if __name__ == "__main__":
    unittest.main()
