# k3s-lab-nixos

NixOS flake configuration for a 3-node home lab [k3s](https://k3s.io/) cluster running on Hyper-V VMs.
Intended to host GitHub Actions self-hosted runners, Atlantis, and other GitOps tooling.

## Hosts

| Host | Role | Platform |
|------|------|----------|
| `k3s-server` | k3s control plane | x86_64-linux |
| `k3s-agent` | k3s worker node | x86_64-linux |
| `k3s-agent-2` | k3s worker node | x86_64-linux |

> **Sizing note:** The server node handles both the Kubernetes control plane and any pods scheduled on it. 8 GB RAM / 4 vCPUs recommended for the server; 4 GB / 2 vCPUs is sufficient for agent nodes.

---

## Working Environment

### From the Dev Container

Everything NixOS-related can be done from the included dev container:

| Task | Command |
|------|---------|
| Validate flake syntax | `nix flake check` |
| Build a host config (no activation) | `nix build .#nixosConfigurations.<host>.config.system.build.toplevel` |
| Deploy to a running node | `nixos-rebuild switch --flake .#<host> --target-host root@<IP>` |
| Edit/create sops secrets | `sops secrets/secrets.yaml` |
| Rotate host keys in `.sops.yaml` | `sops updatekeys secrets/secrets.yaml` |
| Update flake inputs | `nix flake update` |

### From the Windows Host (PowerShell as Administrator)

These tasks require direct Hyper-V access and cannot be done from the dev container:

| Task | How |
|------|-----|
| Create `K3sLabSwitch` (once) | See [Prerequisites](#prerequisites) |
| Provision VMs | `.\scripts\create-hyperv-vm.ps1 -VMName <name>` |
| Open VM consoles | Hyper-V Manager |
| Initial install (disko + nixos-install) | Boot VM from ISO, run commands below |
| Start / stop / snapshot VMs | Hyper-V Manager or `Stop-VM`, `Start-VM` |

---

## Prerequisites

- Windows 11 with Hyper-V enabled
- NixOS minimal ISO at `C:\NixOS\ISOs\nixos-minimal-25.11.10470.0c88e1f2bdb9-x86_64-linux.iso`
- A Hyper-V internal switch named `K3sLabSwitch`

Create the switch once (run as Administrator in PowerShell):

```powershell
New-VMSwitch -Name K3sLabSwitch -SwitchType Internal
```

---

## Full Provisioning Walkthrough

### Step 1 — Set up your admin age key (dev container, once)

```bash
# Generate an age key for yourself (run on your admin machine / dev container)
age-keygen -o ~/.config/sops/age/keys.txt
# The public key is printed to stdout — paste it into secrets/.sops.yaml
```

### Step 2 — Provision VMs (Windows host, PowerShell as Administrator)

```powershell
.\scripts\create-hyperv-vm.ps1 -VMName k3s-server  -MemoryGB 8 -DiskGB 60 -CPUs 4
.\scripts\create-hyperv-vm.ps1 -VMName k3s-agent
.\scripts\create-hyperv-vm.ps1 -VMName k3s-agent-2
```

Default specs (overridable): 4 GB RAM, 30 GB disk, 2 vCPUs, Generation 2, Secure Boot off.

### Step 3 — Install each node (Hyper-V Manager console)

Boot from the ISO, then run the following for each host (substitute `k3s-server`, `k3s-agent`, `k3s-agent-2`):

```bash
# Clone this repo onto the live ISO environment
nix-shell -p git --run "git clone <your-repo-url> /mnt/repo"
cd /mnt/repo

# Partition and format the disk
nix run github:nix-community/disko -- --mode disko ./hosts/<hostname>/disko.nix

# Install NixOS
nixos-install --flake .#<hostname>
```

### Step 4 — Collect host age public keys (dev container)

After each node boots for the first time, retrieve its SSH host key and convert it to an age public key:

```bash
ssh-keyscan k3s-server  | grep ed25519 | ssh-to-age
ssh-keyscan k3s-agent   | grep ed25519 | ssh-to-age
ssh-keyscan k3s-agent-2 | grep ed25519 | ssh-to-age
```

Paste each output into `secrets/.sops.yaml`, replacing the `age1TODO_*` placeholders.

### Step 5 — Create and encrypt the k3s token (dev container)

```bash
# Create the encrypted secrets file interactively
sops secrets/secrets.yaml
```

Add this content (sops will encrypt it on save):

```yaml
k3s-token: "$(openssl rand -hex 32)"
```

Commit `secrets/secrets.yaml` — it is safe to version-control once encrypted.

### Step 6 — Deploy final configuration (dev container)

```bash
nixos-rebuild switch --flake .#k3s-server  --target-host root@<SERVER_IP>
nixos-rebuild switch --flake .#k3s-agent   --target-host root@<AGENT_IP>
nixos-rebuild switch --flake .#k3s-agent-2 --target-host root@<AGENT2_IP>
```

k3s will start automatically. Verify the cluster from the server:

```bash
ssh admin@<SERVER_IP> kubectl get nodes
```

---

## Node Hostname Resolution

Nodes use mDNS (`avahi`) so they can resolve each other as `k3s-server.local`, `k3s-agent.local`, etc. Agent nodes are pre-configured to join at `https://k3s-server.local:6443`.

If mDNS does not work on your Hyper-V switch, either:
- Set a DHCP reservation for `k3s-server` so it gets a fixed IP, or
- Update `mylab.k3s.serverAddr` in each agent's `configuration.nix` to the server's actual IP.

---

## Disk Layout

All hosts use the same GPT layout on `/dev/sda`:

| Partition | Size | Format | Mount |
|-----------|------|--------|-------|
| ESP | 512 MB | FAT32 | `/boot` |
| root | remainder | ext4 | `/` |

---

## Deploying Configuration Changes

After editing the flake, redeploy from the dev container:

```bash
nixos-rebuild switch --flake .#k3s-server  --target-host root@<SERVER_IP>
nixos-rebuild switch --flake .#k3s-agent   --target-host root@<AGENT_IP>
nixos-rebuild switch --flake .#k3s-agent-2 --target-host root@<AGENT2_IP>
```

---

## Repository Structure

```
.
├── flake.nix                          # Flake inputs and NixOS host declarations
├── flake.lock                         # Pinned input revisions
├── secrets/
│   ├── .sops.yaml                     # sops-nix age key configuration
│   └── secrets.yaml                   # sops-encrypted secrets (k3s-token, etc.)
├── hosts/
│   ├── k3s-server/
│   │   ├── configuration.nix          # Host settings (hostname, role, hardware)
│   │   └── disko.nix                  # Disk layout
│   ├── k3s-agent/
│   │   ├── configuration.nix
│   │   └── disko.nix
│   └── k3s-agent-2/
│       ├── configuration.nix
│       └── disko.nix
├── modules/
│   ├── common.nix                     # Shared baseline (users, SSH, avahi, sops)
│   └── k3s.nix                        # k3s service + mylab.k3s options
└── scripts/
    └── create-hyperv-vm.ps1           # Hyper-V VM provisioning (run on Windows host)
```

---

## Flake Inputs

| Input | Version |
|-------|---------|
| nixpkgs | nixos-24.11 |
| disko | latest (follows nixpkgs) |
| sops-nix | latest (follows nixpkgs) |
