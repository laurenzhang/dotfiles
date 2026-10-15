#!/usr/bin/env bash
# Sets up a macOS or Ubuntu machine from this repo. Safe to re-run: each step checks before it acts.
# Run as your normal user. On Linux, sudo is used only to install apt packages and set the login shell.
# Set GIT_EMAIL to write user.email into ~/.gitconfig.local the first time.
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
os="$(uname -s)"

log() { printf '==> %s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

[ "$(id -u)" -ne 0 ] || die "run as your normal user, not root"

case "$os" in
  Darwin)
    brewfile="$repo/brew/.Brewfile"
    stow_packages=(brew claude editorconfig git mise nvim tmux zsh)
    ;;
  Linux)
    brewfile="$repo/workstation/Brewfile"
    # mise is left out because its pinned versions would override the workstation's own runtimes.
    stow_packages=(claude editorconfig git nvim pi tmux zsh)
    apt_packages=(build-essential curl file git procps stow zsh)
    ;;
  *) die "unsupported OS: $os" ;;
esac

if [ "$os" = Linux ]; then
  missing=()
  for package in "${apt_packages[@]}"; do
    # dpkg --status also succeeds for a removed package whose config files remain.
    [ "$(dpkg-query --show --showformat='${db:Status-Status}' "$package" 2> /dev/null)" = installed ] || missing+=("$package")
  done
  if [ "${#missing[@]}" -gt 0 ]; then
    log "installing apt packages: ${missing[*]}"
    sudo apt-get update
    sudo apt-get install --yes "${missing[@]}"
  fi
fi

# Pi needs Node 22.19 or newer. Install under ~/.local, because only /home survives a restart on a workstation.
install_pi() {
  local want=22.19.0 have
  if ! command -v node > /dev/null || ! command -v npm > /dev/null; then
    echo "Skipping Pi: node and npm were not found"
    return 0
  fi
  have="$(node --version | sed 's/^v//')"
  if [ "$(printf '%s\n%s\n' "$want" "$have" | sort --version-sort | head --lines=1)" != "$want" ]; then
    echo "Skipping Pi: it needs Node $want or newer and this is $have"
    return 0
  fi
  log "installing Pi"
  npm install --global --prefix "$HOME/.local" --ignore-scripts @earendil-works/pi-coding-agent || echo "Pi install failed; re-run this script to retry"
}

find_brew() {
  local candidate
  for candidate in /opt/homebrew/bin/brew /usr/local/bin/brew /home/linuxbrew/.linuxbrew/bin/brew "$HOME/.linuxbrew/bin/brew"; do
    if [ -x "$candidate" ]; then printf '%s\n' "$candidate"; return 0; fi
  done
  return 1
}

# The installers prompt on a terminal and run unattended otherwise.
run_installer() {
  local script
  script="$(curl --fail --silent --show-error --location "$1")"
  shift
  if [ -t 0 ]; then env "$@" /bin/bash -c "$script"; else env NONINTERACTIVE=1 "$@" /bin/bash -c "$script"; fi
}

brew_bin="$(find_brew || true)"
if [ -z "$brew_bin" ]; then
  log "installing Homebrew"
  run_installer https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh
  brew_bin="$(find_brew)" || die "Homebrew installed but brew was not found"
fi
eval "$("$brew_bin" shellenv)"

log "installing Homebrew packages"
brew bundle --no-upgrade --file="$brewfile"

# Link into directories that already exist so tools that write there (such as Claude Code) do not write into this repo.
mkdir -p "$HOME/.claude/skills" "$HOME/.claude/hooks" "$HOME/.config"
# Pi stores credentials and sessions next to the linked AGENTS.md, so link only that file into this directory.
if [ "$os" = Linux ]; then mkdir -p "$HOME/.pi/agent"; fi

log "checking for files that stow would overwrite"
cd "$repo"
if ! plan="$(stow --no --target="$HOME" "${stow_packages[@]}" 2>&1)"; then
  printf '%s\n' "$plan" >&2
  die "move the files listed above aside, then re-run"
fi
log "linking dotfiles"
stow --target="$HOME" "${stow_packages[@]}"

# The hook runs on /usr/bin/python3; settings.json is edited in place because Claude Code also writes to it.
if [ -x /usr/bin/python3 ]; then
  /usr/bin/python3 "$repo/scripts/wire-claude-hooks.py" || echo "Claude guard hook not registered; fix ~/.claude/settings.json and re-run"
else
  echo "Skipping the Claude guard hook: /usr/bin/python3 was not found"
fi

if [ ! -d "$HOME/.oh-my-zsh" ]; then
  log "installing oh-my-zsh"
  # ZSH= clears an exported $ZSH, which makes the installer refuse to run.
  run_installer https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh ZSH= RUNZSH=no CHSH=no KEEP_ZSHRC=yes
fi

if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
  log "cloning tmux plugin manager"
  git clone --depth 1 https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
fi

local_git="$HOME/.gitconfig.local"
if [ ! -e "$local_git" ]; then
  log "creating $local_git"
  {
    # The tracked .gitconfig points at the macOS path of gh; this include overrides it on Linux.
    if [ "$os" = Linux ]; then
      for host in github.com gist.github.com; do
        printf '[credential "https://%s"]\n\thelper =\n\thelper = !gh auth git-credential\n' "$host"
      done
    fi
    if [ -n "${GIT_EMAIL:-}" ]; then printf '[user]\n\temail = %s\n' "$GIT_EMAIL"; fi
  } > "$local_git"
fi

if [ "$os" = Linux ]; then
  # Refuses pushes to main, master and production; see git/.config/git/hooks.
  git config --file "$local_git" core.hooksPath "$HOME/.config/git/hooks"
  if [ ! -x "$HOME/.local/bin/pi" ]; then install_pi; fi
fi

if [ "$os" = Linux ]; then
  zsh_bin="$(command -v zsh)"
  user_name="$(id -un)"
  if [ "$(getent passwd "$user_name" | cut -d: -f7)" != "$zsh_bin" ]; then
    log "setting login shell to $zsh_bin"
    grep --quiet --fixed-strings --line-regexp "$zsh_bin" /etc/shells || echo "$zsh_bin" | sudo tee --append /etc/shells > /dev/null
    sudo chsh --shell "$zsh_bin" "$user_name"
  fi
fi

log "done"
git config --file "$local_git" user.email > /dev/null || echo "Set your email: git config --file ~/.gitconfig.local user.email <address>"
echo "Open a new shell. In tmux, press prefix then Shift-i to install plugins. Open nvim to finish the plugin install."
if [ "$os" = Darwin ]; then echo "Then: mise install"; fi
if [ "$os" = Linux ] && [ -x "$HOME/.local/bin/pi" ]; then echo "Pi is installed. Add a model provider in ~/.pi/agent/models.json, then run pi inside tmux."; fi
