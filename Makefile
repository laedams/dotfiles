SHELL    := /bin/bash
STOW_DIR := $(CURDIR)
TARGET   := $(HOME)
PACKAGES := zsh tmux nvim

STOW_FLAGS  ?= --target=$(TARGET) --dir=$(STOW_DIR)
UNSTOW_PKGS := $(addprefix un-,$(PACKAGES))

.PHONY: help install uninstall reinstall check $(PACKAGES) $(UNSTOW_PKGS)

help:
	@echo "Dotfiles — bootstrap.sh handles installs, stow handles symlinks"
	@echo ""
	@echo "Targets:"
	@echo "  make install      Run ./bootstrap.sh (full setup, idempotent)"
	@echo "  make uninstall    Remove every stow symlink"
	@echo "  make reinstall    Unstow then re-stow every package"
	@echo "  make check        Dry-run stow — preview symlink plan"
	@echo "  make <pkg>        Stow one package (e.g. make zsh)"
	@echo "  make un-<pkg>     Unstow one package (e.g. make un-zsh)"
	@echo ""
	@echo "Packages: $(PACKAGES)"

install:
	@./bootstrap.sh

uninstall: $(UNSTOW_PKGS)

reinstall:
	@$(MAKE) --no-print-directory uninstall
	@for pkg in $(PACKAGES); do \
		echo "→ stow $$pkg"; \
		stow --restow --verbose $(STOW_FLAGS) $$pkg; \
	done

check:
	@command -v stow >/dev/null 2>&1 || { echo "stow not installed — run 'make install' first" >&2; exit 1; }
	@for pkg in $(PACKAGES); do \
		echo "→ check $$pkg"; \
		stow --no --verbose $(STOW_FLAGS) $$pkg || true; \
	done

$(PACKAGES):
	@echo "→ stow $@"
	@stow --restow --verbose $(STOW_FLAGS) $@

$(UNSTOW_PKGS):
	@pkg=$(@:un-%=%); \
	echo "→ unstow $$pkg"; \
	stow --delete --verbose $(STOW_FLAGS) $$pkg
