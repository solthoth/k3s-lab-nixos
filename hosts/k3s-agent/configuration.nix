{ ... }: {
  networking.hostName = "k3s-agent";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.initrd.availableKernelModules = [
    "hv_vmbus" "hv_storvsc" "hv_netvsc" "sd_mod"
  ];

  virtualisation.hypervGuest.enable = true;

  networking.useDHCP = true;

  mylab.k3s = {
    role = "agent";
    # Update serverAddr to the actual IP or resolvable hostname of k3s-server
    # if mDNS (.local) does not work on your Hyper-V switch.
    serverAddr = "https://k3s-server.local:6443";
  };

  system.stateVersion = "25.11";
}
