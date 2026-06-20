{ config, lib, ... }:
let
  cfg = config.mylab.k3s;
in {
  options.mylab.k3s = {
    role = lib.mkOption {
      type = lib.types.enum [ "server" "agent" ];
      description = "k3s node role: 'server' for control plane, 'agent' for worker.";
    };
    serverAddr = lib.mkOption {
      type = lib.types.str;
      default = "https://k3s-server.local:6443";
      description = "k3s server URL used by agent nodes to join the cluster.";
    };
  };

  config = {
    sops.secrets."k3s-token" = {
      owner = "root";
      mode = "0400";
    };

    services.k3s = {
      enable = true;
      role = cfg.role;
      tokenFile = config.sops.secrets."k3s-token".path;
      serverAddr = lib.mkIf (cfg.role == "agent") cfg.serverAddr;
      extraFlags = lib.mkIf (cfg.role == "server") "--write-kubeconfig-mode=0644";
    };

    environment.interactiveShellInit = lib.mkIf (cfg.role == "server") ''
      export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
    '';

    # k3s inter-node communication ports
    networking.firewall = {
      allowedTCPPorts =
        if cfg.role == "server"
        then [ 6443 10250 ]   # API server + kubelet
        else [ 10250 ];       # kubelet only
      allowedUDPPorts = [ 8472 ];  # flannel VXLAN
    };
  };
}
