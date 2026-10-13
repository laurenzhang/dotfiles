# Global rules for Pi

These apply in every repository. A repository's own `AGENTS.md` can add rules; follow both.

## Git
- Never push to `main`, `master` or `production`. Create a branch, commit there and open a pull request.
- Never merge a pull request, force-push, delete a remote branch or rewrite history that has been pushed.
- Do not edit CI workflow files or any file that holds credentials.

## Working style
- Start by reading and explaining. Ask before the first edit in a task.
- Make the smallest change that does the job, and show the diff before committing.
- Ask before any command that deletes data, changes access, or touches a production system.
- Never run `sudo`.

## Credentials
- Do not read, print or copy credentials: files under `~/.config/gh`, `~/.ssh` or `~/.pi/agent`, any key or token file under `~/.config`, and any token or key in the environment.
- If a task seems to need a credential, stop and ask.
