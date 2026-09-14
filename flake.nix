{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    lanzaboote = {
      url = "github:nix-community/lanzaboote/v1.1.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-darwin = {
      url = "github:nix-darwin/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-flatpak.url = "github:gmodena/nix-flatpak/?ref=latest";

    # Source only, built with nixpkgs' recipe in home/desktop.nix.
    waybar = {
      url = "github:Alexays/Waybar";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, nix-darwin, ... }@inputs:
    let
      inherit (nixpkgs) lib;
      specialArgs = { inherit inputs; };
      nixos = host: lib.nixosSystem {
        inherit specialArgs;
        modules = [ ./hosts/${host} ];
      };
    in
    {
      nixosConfigurations = {
        DESKTOP-DYLAN = nixos "DESKTOP-DYLAN";
        G3JC7G4 = nixos "G3JC7G4";
      }
      # Appears once the install's hardware-configuration.nix is committed.
      // lib.optionalAttrs (builtins.pathExists ./hosts/LAPTOP-ON9AU/hardware-configuration.nix) {
        LAPTOP-ON9AU = nixos "LAPTOP-ON9AU";
      };

      darwinConfigurations.MBP-DYLAN = nix-darwin.lib.darwinSystem {
        inherit specialArgs;
        modules = [ ./hosts/MBP-DYLAN ];
      };
    };
}
