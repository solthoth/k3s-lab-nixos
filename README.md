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

### Step 3 — Partition disk and collect host age key (Hyper-V Manager console)

Boot from the ISO. The live environment runs as the `nixos` user with passwordless `sudo` — disk and install commands require root.

> **Do not run `nixos-install` yet.** sops-nix decrypts secrets during activation, so `secrets/secrets.yaml` must exist and be encrypted for this host before the install runs. Steps 3–5 get you there.

```bash
# Switch to root for the whole session
sudo -i

# Setup sshd for local access
## Optional
passwd nixos
systemctl start sshd

# Clone this repo using HTTPS — the live ISO has no SSH keys.
# Use the HTTPS URL (https://github.com/...) not the SSH URL (git@github.com:...).
nix-shell -p git --run "git clone https://github.com/<your-org>/<your-repo> /tmp/repo"
cd /tmp/repo

# Partition and format the disk
# --extra-experimental-features is required; nix-command and flakes are off by default on the ISO.
nix --extra-experimental-features 'nix-command flakes' run github:nix-community/disko -- --mode disko ./hosts/<hostname>/disko.nix

# Pre-generate the SSH host key into the installed system's /etc/ssh.
# sops-nix derives the age key from this file — it must exist before nixos-install.
mkdir -p /mnt/etc/ssh
ssh-keygen -t ed25519 -f /mnt/etc/ssh/ssh_host_ed25519_key -N ""

# Print the age public key — copy this value, you will need it in Step 4.
nix-shell -p ssh-to-age --run "cat /mnt/etc/ssh/ssh_host_ed25519_key.pub | ssh-to-age"
```

**Pause here** and complete Steps 4 and 5 in the dev container before continuing.

### Step 4 — Update `.sops.yaml` with host age keys (dev container)

Paste the age public key printed in Step 3 into `secrets/.sops.yaml`, replacing the matching `age1TODO_*` placeholder. Repeat for each node before creating the secrets file.

### Step 5 — Create and encrypt the k3s token (dev container)

```bash
# Install sops if not already available
nix-shell -p sops

# Create the encrypted secrets file interactively (sops encrypts on save)
sops secrets/secrets.yaml
```

Add this content, replacing the value with a random string:

```yaml
k3s-token: "change-me-to-a-long-random-string"
```

Then commit and push so the live ISO can pull it:

```bash
git add secrets/.sops.yaml secrets/secrets.yaml
git commit -m "chore: add encrypted k3s secrets"
git push
```

### Step 6 — Run nixos-install (Hyper-V Manager console)

Back on the live ISO:

```bash
cd /tmp/repo
git pull

# Now install — secrets.yaml exists and is encrypted for this host
nixos-install --flake .#<hostname>
```

Repeat Steps 3–6 for each node. All nodes share the same `secrets/secrets.yaml`, so once created you only need to re-encrypt it with each new host key (`sops updatekeys secrets/secrets.yaml`) rather than recreating it.

### Step 7 — Verify the cluster (dev container)

Once all nodes are running:

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
| nixpkgs | nixos-25.11 |
| disko | latest (follows nixpkgs) |
| sops-nix | latest (follows nixpkgs) |
