{ ... }: {
  networking.hostName = "k3s-server";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.initrd.availableKernelModules = [
    "hv_vmbus" "hv_storvsc" "hv_blkvsc" "hv_netvsc" "sd_mod"
  ];

  virtualisation.hypervGuest.enable = true;

  networking.useDHCP = true;

  mylab.k3s.role = "server";

  system.stateVersion = "24.11";
}
