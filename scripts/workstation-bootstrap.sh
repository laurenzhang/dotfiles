#!/usr/bin/env bash
# Sets up a Linux workstation from this repo. Safe to re-run: each step checks before it acts.
# Run as your normal user. Only the apt and login-shell steps use sudo.
# Set GIT_EMAIL to write user.email into ~/.gitconfig.local the first time.
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# asdf is left out because its pinned versions would override the workstation's own runtimes.
stow_packages=(claude editorconfig git nvim tmux zsh)
apt_packages=(build-essential curl file git procps stow zsh)

log() { printf '==> %s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

[ "$(uname -s)" = Linux ] || die "this script is for Linux; on macOS use brew/.Brewfile and make stow"
[ "$(id -u)" -ne 0 ] || die "run as your normal user, not root"

missing=()
for package in "${apt_packages[@]}"; do
  dpkg --status "$package" > /dev/null 2>&1 || missing+=("$package")
done
if [ "${#missing[@]}" -gt 0 ]; then
  log "installing apt packages: ${missing[*]}"
  sudo apt-get update
  sudo apt-get install --yes "${missing[@]}"
fi

brew_bin=""
for candidate in /home/linuxbrew/.linuxbrew/bin/brew "$HOME/.linuxbrew/bin/brew"; do
  if [ -x "$candidate" ]; then brew_bin="$candidate"; break; fi
done
if [ -z "$brew_bin" ]; then
  log "installing Linuxbrew"
  NONINTERACTIVE=1 /bin/bash -c "$(curl --fail --silent --show-error --location https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  brew_bin=/home/linuxbrew/.linuxbrew/bin/brew
fi
eval "$("$brew_bin" shellenv)"

log "installing Homebrew packages"
brew bundle --file="$repo/workstation/Brewfile"

# Link into directories that already exist so tools that write there (such as Claude Code) do not write into this repo.
mkdir -p "$HOME/.claude/skills" "$HOME/.config"

log "checking for files that stow would overwrite"
cd "$repo"
if ! plan="$(stow --no --target="$HOME" "${stow_packages[@]}" 2>&1)"; then
  printf '%s\n' "$plan" >&2
  die "move the files listed above aside, then re-run"
fi
log "linking dotfiles"
stow --target="$HOME" "${stow_packages[@]}"

if [ ! -d "$HOME/.oh-my-zsh" ]; then
  log "installing oh-my-zsh"
  RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c "$(curl --fail --silent --show-error --location https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
  log "cloning tmux plugin manager"
  git clone --depth 1 https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
fi

# The tracked .gitconfig points at the macOS path of gh; this include overrides it.
local_git="$HOME/.gitconfig.local"
if [ ! -e "$local_git" ]; then
  log "creating $local_git"
  {
    printf '[credential "https://github.com"]\n\thelper =\n\thelper = !gh auth git-credential\n'
    if [ -n "${GIT_EMAIL:-}" ]; then printf '[user]\n\temail = %s\n' "$GIT_EMAIL"; fi
  } > "$local_git"
fi

zsh_bin="$(command -v zsh)"
user_name="$(id -un)"
if [ "$(getent passwd "$user_name" | cut -d: -f7)" != "$zsh_bin" ]; then
  log "setting login shell to $zsh_bin"
  grep --quiet --fixed-strings --line-regexp "$zsh_bin" /etc/shells || echo "$zsh_bin" | sudo tee --append /etc/shells > /dev/null
  sudo chsh --shell "$zsh_bin" "$user_name"
fi

log "done"
git config --file "$local_git" user.email > /dev/null || echo "Set your email: git config --file ~/.gitconfig.local user.email <address>"
echo "Open a new shell. In tmux, press prefix then Shift-i to install plugins. Open nvim to finish the plugin install."
