# dotfiles

Personal dotfiles, managed with [GNU Stow](https://www.gnu.org/software/stow/). Each top-level folder is a package whose contents mirror `$HOME`. The layout and the Neovim config are adapted from [mdzhang/dotfiles](https://github.com/mdzhang/dotfiles).

| Package | Links into `$HOME` |
|---|---|
| `asdf` | `.asdfrc`, `.tool-versions` |
| `brew` | `.Brewfile` (install with `make brew`) |
| `claude` | `~/.claude/skills/*` |
| `editorconfig` | `.editorconfig` (applies to every repo under `$HOME` that lacks its own) |
| `git` | `.gitconfig`, `.config/git/ignore` |
| `nvim` | `.config/nvim` (LazyVim) |
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

On Linux it also installs `zsh` and `stow` with apt, writes the Linux path for the `gh` credential helper into `~/.gitconfig.local`, and sets zsh as the login shell. It skips the `asdf` and `brew` packages there, because the pinned versions would override the machine's own runtimes.

When it finishes:

1. Open a new shell.
2. In tmux, press the prefix (`Ctrl-b`), then `Shift-i` to install the plugins.
3. Open `nvim`. The first launch installs the plugins at the versions pinned in `lazy-lock.json`.
4. On macOS, install the runtimes pinned in `.tool-versions`: `asdf plugin add nodejs && asdf plugin add python && asdf install`

On managed workstations where only `/home` survives an image update, the apt packages and login shell are wiped but everything under `/home` stays. Re-running the script restores the rest, so it can be called from the machine's boot hook as your normal user.

## Files that stay out of the repo

Per-machine and private settings live in untracked files that the tracked config includes if present.

- `~/.gitconfig.local`: set `user.email` here.
- `~/.zshrc.local`: JDK paths and other machine-specific exports.
- `~/.claude/skills/<skill>/LOCAL.md`: employer-specific conventions for the `pr-description` and `kafka-cli` skills. Each skill reads this file first when it exists.
- `~/.config/dotfiles/private-terms.txt`: terms that must never appear in this repo, one per line.

Run `make check` before every push. It scans for secrets and for the private terms above.
