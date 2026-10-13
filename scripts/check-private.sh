#!/usr/bin/env bash
# Scans files that git would commit for secrets and for private terms. Private terms (one per line,
# matched case-insensitively) come from an untracked file so this script can be published.
set -euo pipefail

cd "$(dirname "$0")/.."
terms_file="${DOTFILES_PRIVATE_TERMS:-$HOME/.config/dotfiles/private-terms.txt}"
self=scripts/check-private.sh
status=0

files() { git ls-files --cached --others --exclude-standard | grep --invert-match --fixed-strings --line-regexp "$self"; }

secret_patterns='BEGIN [A-Z ]*PRIVATE KEY|AKIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{20,}|xox[abprs]-[A-Za-z0-9-]{10,}|sk-[A-Za-z0-9_-]{20,}|sasl\.password=[^<[:space:]]|password *= *[^<[:space:]]'
if files | xargs grep --extended-regexp --line-number --with-filename "$secret_patterns" 2>/dev/null; then
  echo "check-private: possible secret found" >&2
  status=1
fi

if [ -f "$terms_file" ]; then
  if files | xargs grep --ignore-case --fixed-strings --file="$terms_file" --line-number --with-filename 2>/dev/null; then
    echo "check-private: private term found" >&2
    status=1
  fi
else
  echo "check-private: no private terms file at $terms_file; only secret patterns were checked" >&2
fi

[ "$status" -eq 0 ] && echo "check-private: clean"
exit "$status"
