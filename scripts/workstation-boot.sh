#!/usr/bin/env bash
# Re-applies this repo at every boot of a workstation that resets everything outside /home.
# Call it from the workstation's boot hook, as root or as the user that owns the clone.
set -uo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ "$(id -u)" -eq 0 ]; then
  exec runuser -l "$(stat -c %U "$repo")" -c "'$repo/scripts/workstation-boot.sh'"
fi

log_dir="$HOME/.local/state/dotfiles"
mkdir -p "$log_dir"
exec >> "$log_dir/boot.log" 2>&1

echo "$(date -Iseconds) boot: start"
"$repo/scripts/bootstrap.sh"
status=$?
echo "$(date -Iseconds) boot: bootstrap exited $status"
# A failure is logged above, and never blocks the workstation from starting.
exit 0
