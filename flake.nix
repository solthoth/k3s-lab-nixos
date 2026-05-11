{
  description = "Home lab NixOS configs";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, disko, ... }: {
    nixosConfigurations = {
      k3s-server = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          disko.nixosModules.disko
          ./hosts/k3s-server/configuration.nix
          ./hosts/k3s-server/disko.nix
          ./modules/common.nix
          ./modules/k3s.nix
        ];
      };
      k3s-agent = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          disko.nixosModules.disko
          ./hosts/k3s-agent/configuration.nix
          ./hosts/k3s-agent/disko.nix
          ./modules/common.nix
          ./modules/k3s.nix
        ];
      };
    };
  };
}