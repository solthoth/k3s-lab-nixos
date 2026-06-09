{
  description = "Home lab NixOS configs";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, disko, sops-nix, ... }:
    let
      sharedModules = host: [
        disko.nixosModules.disko
        sops-nix.nixosModules.sops
        ./hosts/${host}/configuration.nix
        ./hosts/${host}/disko.nix
        ./modules/common.nix
        ./modules/k3s.nix
      ];
    in {
      nixosConfigurations = {
        k3s-server  = nixpkgs.lib.nixosSystem { system = "x86_64-linux"; modules = sharedModules "k3s-server";  };
        k3s-agent   = nixpkgs.lib.nixosSystem { system = "x86_64-linux"; modules = sharedModules "k3s-agent";   };
        k3s-agent-2 = nixpkgs.lib.nixosSystem { system = "x86_64-linux"; modules = sharedModules "k3s-agent-2"; };
      };
    };
}
