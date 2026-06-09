#!/usr/bin/env bash
set -euo pipefail

log() { echo "[setup] $*"; }

# --- Nix tools ---
log "Installing nil (Nix LSP) and nixfmt..."
nix-env -iA nixpkgs.nil nixpkgs.nixfmt-rfc-style
log "Nix tools installed"

# --- uv ---
log "Installing uv..."
curl -LsSf https://astral.sh/uv/install.sh | sh
UV="$HOME/.local/bin/uv"
log "uv installed: $($UV --version)"

# Persist uv tool bin dir to PATH for future shell sessions
echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
export PATH="$HOME/.local/bin:$PATH"

# --- graphifyy ---
log "Installing graphifyy via uv..."
"$UV" tool install graphifyy
log "graphifyy installed"

# --- graphify ---
log "Running graphify on workspace..."
"$HOME/.local/bin/graphify" .
log "graphify complete"

log "Dev environment ready."
log "  Nix flake check : nix flake check"
log "  Nix build       : nix build .#nixosConfigurations.k3s-server.config.system.build.toplevel"
