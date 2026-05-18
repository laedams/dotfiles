# dotfiles

Personal terminal setup. One script installs the tools, [GNU Stow](https://www.gnu.org/software/stow/) symlinks the configs.

## Layout

```
dotfiles/
├── bootstrap.sh    install tools (zsh, omz, plugins, tmux, tpm, bob, nvim)
├── Makefile        thin wrapper around stow for day-to-day use
├── zsh/            → ~/.zshrc
├── tmux/           → ~/.tmux.conf
└── nvim/           → ~/.config/nvim/
```

## First-time setup on a fresh machine

```sh
git clone <repo-url> ~/Projects/dotfiles
cd ~/Projects/dotfiles
make install            # or: ./bootstrap.sh
```

That installs everything and stows the configs. Re-run any time — it's idempotent.

One-time manual steps the script prints at the end:

- `chsh -s "$(command -v zsh)"` — make zsh the default shell
- Launch tmux, press `C-s` then `I` — install tmux plugins via tpm
- Launch `nvim` — LazyVim bootstraps plugins on first run

## Day-to-day

```sh
make help         # list targets
make check        # dry-run: preview the symlink plan
make zsh          # (re)stow only the zsh package
make un-zsh       # unstow only the zsh package
make uninstall    # remove every symlink
make reinstall    # unstow + re-stow everything (after adding files)
```

## Adding a new config

1. Drop the file under the matching package, mirroring its target path under `$HOME`.
   E.g. `~/.config/foo/bar.toml` → `dotfiles/foo/.config/foo/bar.toml`
2. Add `foo` to `PACKAGES` in both `Makefile` and `bootstrap.sh`.
3. `make reinstall`.

## Conflicts

Stow refuses to overwrite existing files in `$HOME`. If `make install` fails with a conflict, back up or remove the offending file:

```sh
mv ~/.zshrc ~/.zshrc.bak
make install
```
