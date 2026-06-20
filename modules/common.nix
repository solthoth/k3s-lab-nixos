{ pkgs, ... }: {
  # Admin user — add your SSH public key before deploying
  users.users.admin = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPD6qvcdzveT483cjVxqHxWfXnQfKyrzeptgmmyIQLYG soldotsol@gmail.com"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFWDjt4xNdeeKtX6gj1pQAjdRhrWeLtqlVRIawnoJlcY soldotsol@gmail.com"
    ];
  };

  security.sudo.wheelNeedsPassword = false;

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
    };
    # Ensure a stable ed25519 host key exists; sops-nix derives the age key from it.
    hostKeys = [{
      path = "/etc/ssh/ssh_host_ed25519_key";
      type = "ed25519";
    }];
  };

  # sops-nix: decrypt secrets using the host's SSH ed25519 key as an age key
  sops = {
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    defaultSopsFile = ../secrets/secrets.yaml;
  };

  # mDNS so nodes can resolve each other by <hostname>.local
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    publish = {
      enable = true;
      addresses = true;
    };
  };

  environment.systemPackages = with pkgs; [ curl git htop kubectl vim wget ];

  networking.firewall.enable = true;
  time.timeZone = "UTC";
}
