#!/usr/bin/env bash
# bootstrap.sh — install everything this dotfiles repo expects, then stow.
# Idempotent: safe to re-run on the same machine.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGES=(zsh tmux nvim)

SUDO=""
[ "$(id -u)" -ne 0 ] && SUDO="sudo"

log()  { printf '\n\033[1;34m==>\033[0m %s\n' "$*"; }
info() { printf '    %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m  %s\n' "$*" >&2; }
die()  { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }
has()  { command -v "$1" >/dev/null 2>&1; }

detect_pm() {
  if   has apt-get; then echo apt
  elif has dnf;     then echo dnf
  elif has pacman;  then echo pacman
  elif has zypper;  then echo zypper
  elif has brew;    then echo brew
  else die "no supported package manager (apt/dnf/pacman/zypper/brew)"
  fi
}

install_packages() {
  local pm
  pm=$(detect_pm)
  local pkgs=(stow zsh tmux git curl ca-certificates build-essential pkg-config libssl-dev ripgrep)
  log "Installing system packages via $pm: ${pkgs[*]}"
  case "$pm" in
    apt)    $SUDO apt-get update -qq && DEBIAN_FRONTEND=noninteractive $SUDO apt-get install -y "${pkgs[@]}" ;;
    dnf)    $SUDO dnf install -y "${pkgs[@]}" ;;
    pacman) $SUDO pacman -S --noconfirm --needed "${pkgs[@]}" ;;
    zypper) $SUDO zypper install -y "${pkgs[@]}" ;;
    brew)   brew install "${pkgs[@]}" ;;
  esac
}

install_omz() {
  if [ -d "$HOME/.oh-my-zsh" ]; then
    info "oh-my-zsh already installed"
    return
  fi
  log "Installing Oh My Zsh"
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" \
    "" --unattended --keep-zshrc
}

install_omz_plugin() {
  local name=$1 url=$2
  local dest="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/$name"
  if [ -d "$dest" ]; then
    info "omz plugin '$name' already installed"
    return
  fi
  log "Cloning omz plugin: $name"
  git clone --depth 1 "$url" "$dest"
}

install_tpm() {
  local dest="$HOME/.tmux/plugins/tpm"
  if [ -d "$dest" ]; then
    info "tpm already installed"
    return
  fi
  log "Cloning tpm"
  git clone --depth 1 https://github.com/tmux-plugins/tpm "$dest"
}

install_rust() {
  if has cargo || [ -x "$HOME/.cargo/bin/cargo" ]; then
    info "rustup/cargo already installed"
  else
    log "Installing rustup (non-interactive)"
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
      | sh -s -- -y --default-toolchain stable --profile minimal
  fi
  export PATH="$HOME/.cargo/bin:$PATH"
}

install_bob() {
  if has bob || [ -x "$HOME/.cargo/bin/bob" ] || [ -x "$HOME/.local/bin/bob" ]; then
    info "bob already installed"
    export PATH="$HOME/.cargo/bin:$HOME/.local/bin:$PATH"
    return
  fi
  install_rust
  log "Building bob from source (cargo install — takes a few minutes)"
  cargo install --git https://github.com/MordechaiHadad/bob --locked
  info "bob → $HOME/.cargo/bin/bob"
}

install_nvim() {
  local bob_bin=""
  for candidate in "$HOME/.cargo/bin/bob" "$HOME/.local/bin/bob"; do
    [ -x "$candidate" ] && { bob_bin="$candidate"; break; }
  done
  has bob && bob_bin="$(command -v bob)"
  [ -n "$bob_bin" ] || die "bob not found on PATH or in ~/.cargo/bin / ~/.local/bin"
  if [ -x "$HOME/.local/share/bob/nvim-bin/nvim" ]; then
    info "neovim already installed via bob"
  else
    log "Installing neovim (stable) via bob"
    "$bob_bin" install stable
    "$bob_bin" use stable
  fi
  mkdir -p "$HOME/.local/bin"
  ln -sf "$HOME/.local/share/bob/nvim-bin/nvim" "$HOME/.local/bin/nvim"
  info "nvim → $HOME/.local/bin/nvim"
}

backup_conflicts() {
  local backup_suffix=".pre-stow.bak"
  local backed_up=0
  local pkg pkg_dir rel target
  for pkg in "${PACKAGES[@]}"; do
    pkg_dir="$REPO_DIR/$pkg"
    [ -d "$pkg_dir" ] || continue
    while IFS= read -r -d '' f; do
      rel="${f#$pkg_dir/}"
      target="$HOME/$rel"
      # Only back up real files in the way — leave symlinks (stow --restow handles)
      # and directories (stow merges into them) alone.
      if [ -e "$target" ] && [ ! -L "$target" ] && [ ! -d "$target" ]; then
        warn "conflict: $target exists — moving to $target$backup_suffix"
        mv "$target" "$target$backup_suffix"
        backed_up=$((backed_up + 1))
      fi
    done < <(find "$pkg_dir" -type f -print0)
  done
  [ "$backed_up" -eq 0 ] || info "backed up $backed_up file(s) with suffix '$backup_suffix' — review and delete when satisfied"
}

stow_packages() {
  backup_conflicts
  log "Stowing packages: ${PACKAGES[*]}"
  for pkg in "${PACKAGES[@]}"; do
    info "→ stow $pkg"
    stow --restow --verbose --target="$HOME" --dir="$REPO_DIR" "$pkg"
  done
}

print_next_steps() {
  cat <<EOF

──────────────────────────────────────────────────
✓ Dotfiles installed
──────────────────────────────────────────────────

One-time manual steps:

  • Set zsh as the default shell:
      chsh -s "\$(command -v zsh)"      (log out + back in to take effect)

  • Ensure ~/.local/bin is on PATH (your .zshrc already exports it).
    For bash users:
      echo 'export PATH="\$HOME/.local/bin:\$PATH"' >> ~/.bashrc

  • Install tmux plugins (first run):
      tmux  →  press  C-s  then  I  (capital i)

  • Bootstrap Neovim plugins:
      nvim  →  LazyVim will sync on first launch

Re-run this script any time — it's idempotent.
EOF
}

main() {
  install_packages
  install_omz
  install_omz_plugin zsh-autosuggestions     https://github.com/zsh-users/zsh-autosuggestions
  install_omz_plugin zsh-syntax-highlighting https://github.com/zsh-users/zsh-syntax-highlighting
  install_tpm
  install_bob
  install_nvim
  stow_packages
  print_next_steps
}

main "$@"
