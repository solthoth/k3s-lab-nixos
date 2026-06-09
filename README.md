# k3s-lab-nixos

NixOS flake configuration for a home lab [k3s](https://k3s.io/) cluster running on Hyper-V VMs.

## Hosts

| Host | Role | Platform |
|------|------|----------|
| `k3s-server` | k3s control plane | x86_64-linux |
| `k3s-agent` | k3s worker node | x86_64-linux |

## Prerequisites

- Windows 11 with Hyper-V enabled
- NixOS minimal ISO downloaded to `C:\NixOS\ISOs\`
- A Hyper-V virtual switch named `K3sLabSwitch`

To create the virtual switch (run once, as Administrator):

```powershell
New-VMSwitch -Name K3sLabSwitch -SwitchType Internal
```

## Provisioning VMs

Run from PowerShell as Administrator on the Windows host:

```powershell
.\scripts\create-hyperv-vm.ps1 -VMName k3s-server
.\scripts\create-hyperv-vm.ps1 -VMName k3s-agent
```

Default VM specs: 4 GB RAM, 30 GB disk, 2 vCPUs, Generation 2, Secure Boot disabled, attached to `K3sLabSwitch`. All parameters are overridable:

```powershell
.\scripts\create-hyperv-vm.ps1 -VMName k3s-server -MemoryGB 8 -DiskGB 60 -CPUs 4
```

## Fresh Install

Boot the VM from the NixOS ISO using Hyper-V Manager, then run from the live environment:

```bash
# Partition and format the disk
nix run github:nix-community/disko -- --mode disko ./hosts/k3s-server/disko.nix

# Install NixOS
nixos-install --flake .#k3s-server
```

Repeat for `k3s-agent`, substituting the appropriate host name.

### Disk layout

Both hosts use GPT on `/dev/sda`:

| Partition | Size | Format | Mount |
|-----------|------|--------|-------|
| ESP | 512 MB | FAT32 | `/boot` |
| root | remainder | ext4 | `/` |

## Deploying Configuration Changes

After making changes to the flake, deploy to a running host:

```bash
nixos-rebuild switch --flake .#k3s-server --target-host root@<SERVER_IP>
nixos-rebuild switch --flake .#k3s-agent  --target-host root@<AGENT_IP>
```

## Development

### Validate the flake (syntax check, no build)

```bash
nix flake check
```

### Build without activating

```bash
nix build .#nixosConfigurations.k3s-server.config.system.build.toplevel
nix build .#nixosConfigurations.k3s-agent.config.system.build.toplevel
```

### Update flake inputs

```bash
nix flake update
```

## Repository Structure

```
.
├── flake.nix                        # Flake inputs and NixOS host declarations
├── hosts/
│   ├── k3s-server/
│   │   ├── configuration.nix        # Host-specific settings (hostname, networking, hardware)
│   │   └── disko.nix                # Disk layout
│   └── k3s-agent/
│       ├── configuration.nix        # Host-specific settings
│       └── disko.nix                # Disk layout
├── modules/
│   ├── common.nix                   # Shared baseline (users, SSH, packages)
│   └── k3s.nix                      # k3s service configuration
└── scripts/
    └── create-hyperv-vm.ps1         # Hyper-V VM provisioning script
```

## Flake Inputs

| Input | Version |
|-------|---------|
| nixpkgs | nixos-24.11 |
| disko | latest (follows nixpkgs) |
