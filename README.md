# dotfiles

Personal dotfiles, managed with [GNU Stow](https://www.gnu.org/software/stow/). Each top-level folder is a package whose contents mirror `$HOME`. The layout and the Neovim config are adapted from [mdzhang/dotfiles](https://github.com/mdzhang/dotfiles).

| Package | Links into `$HOME` |
|---|---|
| `mise` | `.config/mise/config.toml` |
| `brew` | `.Brewfile` (install with `make brew`) |
| `claude` | `~/.claude/skills/*`, `~/.claude/hooks/guard.py` |
| `editorconfig` | `.editorconfig` (applies to every repo under `$HOME` that lacks its own) |
| `git` | `.gitconfig`, `.config/git/ignore` |
| `nvim` | `.config/nvim` (LazyVim) |
| `pi` | `.pi/agent/AGENTS.md` (Linux only) |
| `tmux` | `.tmux.conf` (vi copy mode, mouse, reload; plugins need [tpm](https://github.com/tmux-plugins/tpm) cloned to `~/.tmux/plugins/tpm`) |
| `zsh` | `.zshrc`, `.zprofile` |

## Setup

Works on macOS and Ubuntu.

```sh
git clone https://github.com/laurenzhang/dotfiles ~/dotfiles
GIT_EMAIL=you@example.com ~/dotfiles/scripts/bootstrap.sh
```

On a new Mac, the first `git` command offers to install the Command Line Tools; accept it. Run the script as your normal user, not root. `GIT_EMAIL` is optional and writes `user.email` into `~/.gitconfig.local` the first time.

The script checks before each step, so it is safe to re-run. It:

1. Installs Homebrew (Linuxbrew on Linux) if it is missing, then the packages in `brew/.Brewfile` on macOS or `workstation/Brewfile` on Linux. It never upgrades packages that are already installed.
2. Does a dry run of `stow`, then links the packages. If a file such as `~/.gitconfig` already exists, it lists the conflicts and stops without changing anything. Move those files aside and run it again.
3. Installs oh-my-zsh and the tmux plugin manager (tpm), and creates `~/.gitconfig.local`.

On Linux it also installs `zsh` and `stow` with apt, writes the Linux path for the `gh` credential helper into `~/.gitconfig.local`, and sets zsh as the login shell. It skips the `mise` and `brew` packages there, because the pinned versions would override the machine's own runtimes. It also sets a global git hook that refuses pushes to `main`, `master` and `production` (override once with `git push --no-verify`; each repository's own hooks still run), and installs the [Pi](https://pi.dev) coding agent under `~/.local` when Node 22.19 or newer is present. Global rules for Pi live in `~/.pi/agent/AGENTS.md`. Pi's model providers and credentials are set up by hand and stay out of this repo.

When it finishes:

1. Open a new shell.
2. In tmux, press the prefix (`Ctrl-b`), then `Shift-i` to install the plugins.
3. Open `nvim`. The first launch installs the plugins at the versions pinned in `lazy-lock.json`.
4. On macOS, install the runtimes pinned in `~/.config/mise/config.toml`: `mise install`

On workstations where only `/home` survives a restart, the apt packages and login shell are reset. Re-run `scripts/bootstrap.sh` after a restart to restore them.

## Pi on a workstation

`workstation/pi-settings.json` holds Pi settings that `scripts/bootstrap.sh` merges into `~/.pi/agent/settings.json` when a key is not already set. `tuiMode: regular` lets the terminal select and copy text; in Pi's default fullscreen mode, Pi captures the mouse and copying does not reach the clipboard. tmux has the same limit when its mouse mode is on, so press `<prefix> m` to turn it off before selecting text. Neither tmux-yank nor OSC 52 reach a local clipboard from a headless workstation.

## Claude Code guard

`claude/.claude/hooks/guard.py` is a PreToolUse hook for Bash. It denies pushes to main, master and production, force-pushes without `--force-with-lease`, `gh api` writes, `gh pr comment/review/merge`, `gh issue comment`, `gh repo delete`, `gh secret set`, and `terraform apply/destroy/import/state`. Unlike a permission deny list it still runs when prompts are off. `scripts/bootstrap.sh` registers it in `~/.claude/settings.json` without touching other settings. To allow a rule, start Claude Code with `CLAUDE_GUARD_OVERRIDE=<rule>` set. A bare `git push` is not checked; the git `pre-push` hook covers it. Run `make test` after editing the hook.

## Files that stay out of the repo

Per-machine and private settings live in untracked files that the tracked config includes if present.

- `~/.gitconfig.local`: set `user.email` here.
- `~/.zshrc.local`: JDK paths and other machine-specific exports.
- `~/.claude/skills/<skill>/LOCAL.md`: employer-specific conventions for the `pr-description` and `kafka-cli` skills. Each skill reads this file first when it exists.
- `~/.config/dotfiles/private-terms.txt`: terms that must never appear in this repo, one per line.

Run `make check` before every push. It scans for secrets and for the private terms above.
