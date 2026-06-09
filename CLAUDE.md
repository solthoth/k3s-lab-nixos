# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

NixOS Flake configuration for a home lab k3s cluster running on Hyper-V VMs. Two hosts are declared: `k3s-server` and `k3s-agent`, both `x86_64-linux`.

## Common Commands

### Validate the flake (syntax check, no build)
```bash
nix flake check
```

### Build a host config without activating
```bash
nix build .#nixosConfigurations.k3s-server.config.system.build.toplevel
nix build .#nixosConfigurations.k3s-agent.config.system.build.toplevel
```

### Deploy to a running NixOS host
```bash
nixos-rebuild switch --flake .#k3s-server --target-host root@<IP>
nixos-rebuild switch --flake .#k3s-agent  --target-host root@<IP>
```

### Fresh install with disko (run from NixOS live ISO on target)
```bash
nix run github:nix-community/disko -- --mode disko ./hosts/k3s-server/disko.nix
nixos-install --flake .#k3s-server
```

### Update flake inputs
```bash
nix flake update
```

### Provision a new Hyper-V VM (Windows host, PowerShell)
```powershell
.\scripts\create-hyperv-vm.ps1 -VMName k3s-server
.\scripts\create-hyperv-vm.ps1 -VMName k3s-agent
```
Defaults: 4 GB RAM, 30 GB disk, 2 vCPUs, Generation 2, Secure Boot off, attached to `K3sLabSwitch`.

## Architecture

### Flake inputs
- `nixpkgs` pinned to `nixos-24.11`
- `disko` (follows nixpkgs) — declarative disk partitioning used at install time

### Module composition (per host)
Each host loads four modules:
1. `disko.nixosModules.disko` — wires disko into the NixOS module system
2. `hosts/<name>/configuration.nix` — host-specific settings (hostname, networking, hardware)
3. `hosts/<name>/disko.nix` — disk layout for that host
4. `modules/common.nix` — shared baseline (users, SSH, packages, etc.)
5. `modules/k3s.nix` — k3s service config, role is expected to be toggled per-host via an option or conditional

### Disk layout (k3s-server)
GPT on `/dev/sda`: 512 MB FAT32 ESP at `/boot`, remainder ext4 at `/`.  
The agent host's `disko.nix` does not exist yet and should mirror this layout.

### Files still needed
The flake references several files that have not been created yet:
- `hosts/k3s-server/configuration.nix`
- `hosts/k3s-agent/configuration.nix`
- `hosts/k3s-agent/disko.nix`
- `modules/common.nix`
- `modules/k3s.nix`
