PACKAGES := brew claude editorconfig git mise nvim tmux zsh

.PHONY: plan stow unstow restow brew check test

# show what stow would link and any conflicts, without changing anything
plan:
	stow --no --verbose --target=$(HOME) $(PACKAGES)

stow:
	stow --verbose --target=$(HOME) $(PACKAGES)

unstow:
	stow --delete --verbose --target=$(HOME) $(PACKAGES)

restow:
	stow --restow --verbose --target=$(HOME) $(PACKAGES)

brew:
	brew bundle --global

# run the unit tests
test:
	/usr/bin/python3 -m unittest discover -s tests

# scan for secrets and private terms before pushing
check:
	scripts/check-private.sh

.PHONY: bootstrap
# set up this machine (macOS or Ubuntu; see README)
bootstrap:
	scripts/bootstrap.sh
