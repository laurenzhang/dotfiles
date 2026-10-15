#!/usr/bin/env python3
"""PreToolUse hook for Bash that denies commands that are hard to undo or that act as the user.

Unlike a permission deny list, a hook still runs when permission prompts are off. To allow a rule, start Claude Code
with CLAUDE_GUARD_OVERRIDE=<rule>[,<rule>] in its environment; the model cannot set that variable.
"""
import json
import os
import re
import shlex
import sys

PROTECTED_BRANCHES = {"main", "master", "production"}
WRAPPERS = {"sudo", "command", "env", "nohup", "time", "exec"}
SHELLS = {"bash", "sh", "zsh"}
SEPARATORS = {"&&", "||", ";", "|", "&", "|&"}
GH_FLAGS_WITH_VALUE = {"-R", "--repo", "--hostname"}
GIT_FLAGS_WITH_VALUE = {"-C", "-c", "--git-dir", "--work-tree", "--namespace"}
GH_WRITES = {("pr", "comment"), ("pr", "review"), ("pr", "merge"), ("issue", "comment"), ("repo", "delete")}


def _newlines_to_semicolons(command):
    """Treat a newline outside quotes as a command separator."""
    out, quote, escaped = [], None, False
    for char in command:
        if escaped:
            escaped = False
        elif char == "\\" and quote != "'":
            escaped = True
        elif quote:
            if char == quote:
                quote = None
        elif char in "'\"":
            quote = char
        elif char == "\n":
            char = ";"
        out.append(char)
    return "".join(out)


def _segments(command):
    lexer = shlex.shlex(_newlines_to_semicolons(command), posix=True, punctuation_chars=True)
    lexer.whitespace_split = True
    try:
        tokens = list(lexer)
    except ValueError:
        tokens = command.split()
    segment = []
    for token in tokens:
        if token in SEPARATORS:
            if segment:
                yield segment
            segment = []
        else:
            segment.append(token)
    if segment:
        yield segment


def _strip_prefix(tokens):
    while tokens:
        if tokens[0] in WRAPPERS:
            tokens = tokens[1:]
            while tokens and tokens[0].startswith("-"):
                tokens = tokens[1:]
        elif re.match(r"^\w+=", tokens[0]):
            tokens = tokens[1:]
        else:
            break
    return tokens


def _git_push_args(tokens):
    """Return the arguments after `git push`, or None when this is not a push."""
    i = 1
    while i < len(tokens) and tokens[i].startswith("-"):
        i += 2 if tokens[i] in GIT_FLAGS_WITH_VALUE else 1
    if i < len(tokens) and tokens[i] == "push":
        return tokens[i + 1:]
    return None


def _check_git_push(args):
    positional = [a for a in args if not a.startswith("-")]
    has_lease = any(a.startswith(("--force-with-lease", "--force-if-includes")) for a in args)
    short_force = any(re.match(r"^-[a-zA-Z]*f", a) for a in args if not a.startswith("--"))
    plus_refspec = any(a.startswith("+") for a in positional[1:])
    if (("--force" in args or short_force or plus_refspec) and not has_lease):
        return ("push-force", "Force-push without --force-with-lease can overwrite other people's commits.")
    if "--all" in args or "--mirror" in args:
        return ("push-protected", "--all and --mirror push every branch, including the default branch.")
    for refspec in positional[1:]:
        destination = refspec.lstrip("+").split(":")[-1]
        destination = destination.removeprefix("refs/heads/")
        if destination in PROTECTED_BRANCHES:
            return ("push-protected", f"Do not push to {destination}. Push a feature branch and open a pull request.")
    return None


def _gh_api_writes(args, text):
    method = None
    has_fields = False
    for i, arg in enumerate(args):
        if arg in ("-X", "--method") and i + 1 < len(args):
            method = args[i + 1].upper()
        elif arg.startswith("--method="):
            method = arg.split("=", 1)[1].upper()
        elif re.match(r"^-X.", arg):
            method = arg[2:].upper()
        elif arg in ("-f", "-F", "--field", "--raw-field", "--input") or arg.startswith(("--field=", "--raw-field=", "--input=")):
            has_fields = True
    if method is not None:
        return method != "GET"
    if "graphql" in args:
        return "mutation" in text.lower()
    return has_fields


def _check_gh(tokens, text):
    i = 1
    while i < len(tokens) and tokens[i].startswith("-"):
        i += 2 if tokens[i] in GH_FLAGS_WITH_VALUE else 1
    words = [t for t in tokens[i:i + 2]]
    if not words:
        return None
    if words[0] == "api" and _gh_api_writes(tokens[i + 1:], text):
        return ("gh-api-write", "gh api with a write method changes GitHub directly. Use a dedicated gh command.")
    if tuple(words) in GH_WRITES:
        return ("gh-write", f"gh {' '.join(words)} acts as you on GitHub. Run it yourself if you want it.")
    if words[0] == "secret" and len(words) > 1 and words[1] in ("set", "delete", "remove"):
        return ("gh-write", "gh secret changes repository secrets.")
    return None


def _check_terraform(tokens):
    args = [t for t in tokens[1:] if not t.startswith("-")]
    if args[:1] and args[0] in ("apply", "destroy", "import"):
        return ("terraform-write", f"terraform {args[0]} changes real infrastructure. Run it yourself.")
    if args[:2] and args[0] == "state" and args[1] in ("rm", "mv", "push", "replace-provider"):
        return ("terraform-write", f"terraform state {args[1]} edits Terraform state. Run it yourself.")
    return None


def decide(command):
    """Return (rule, reason) for the first rule the command breaks, or None."""
    for segment in _segments(command):
        tokens = _strip_prefix(segment)
        if not tokens:
            continue
        program = os.path.basename(tokens[0])
        found = None
        if program in SHELLS and "-c" in tokens[1:-1]:
            found = decide(tokens[tokens.index("-c") + 1])
        elif program == "git":
            args = _git_push_args(tokens)
            found = _check_git_push(args) if args is not None else None
        elif program == "gh":
            found = _check_gh(tokens, " ".join(segment))
        elif program in ("terraform", "tofu"):
            found = _check_terraform(tokens)
        if found:
            return found
    return None


def main():
    try:
        payload = json.load(sys.stdin)
    except ValueError:
        return
    if payload.get("tool_name") != "Bash":
        return
    found = decide((payload.get("tool_input") or {}).get("command", ""))
    if not found:
        return
    rule, reason = found
    if rule in os.environ.get("CLAUDE_GUARD_OVERRIDE", "").split(","):
        return
    json.dump({"hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "deny",
        "permissionDecisionReason": f"[{rule}] {reason} Override: start Claude Code with CLAUDE_GUARD_OVERRIDE={rule}.",
    }}, sys.stdout)


if __name__ == "__main__":
    main()
