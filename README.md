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

## Setup on a new laptop

1. Install [Homebrew](https://brew.sh), then clone this repo to `~/dotfiles` and install the packages:

   ```sh
   git clone https://github.com/laurenzhang/dotfiles ~/dotfiles && cd ~/dotfiles
   brew bundle --file=brew/.Brewfile
   ```

2. Install oh-my-zsh, which `.zshrc` loads. The two variables stop the installer from replacing `.zshrc`:

   ```sh
   RUNZSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
   ```

3. Create the untracked files from the section below, at least `~/.gitconfig.local` so commits have an email.

4. Link everything. Move or delete any existing file that `make plan` reports as a conflict first, because stow aborts if any file conflicts.

   ```sh
   make plan
   make stow
   ```

5. Install the language runtimes pinned in `.tool-versions`:

   ```sh
   asdf plugin add nodejs
   asdf plugin add python
   asdf install
   ```

6. Install the tmux plugin manager, then press `prefix I` inside tmux to install the plugins:

   ```sh
   git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
   ```

7. Open `nvim`. The first launch installs the plugins at the commits pinned in `lazy-lock.json`, and downloads the treesitter parsers and Mason tools in the background. `:Lazy update` moves the plugins forward and rewrites the lockfile.

## Files that stay out of the repo

Per-machine and private settings live in untracked files that the tracked config includes if present.

- `~/.gitconfig.local`: set `user.email` here.
- `~/.zshrc.local`: JDK paths and other machine-specific exports.
- `~/.claude/skills/<skill>/LOCAL.md`: employer-specific conventions for the `pr-description` and `kafka-cli` skills. Each skill reads this file first when it exists.
- `~/.config/dotfiles/private-terms.txt`: terms that must never appear in this repo, one per line.

Run `make check` before every push. It scans for secrets and for the private terms above.
