{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # atuin 18.21.0 for the macbook: 18.23.0 fails its tests on darwin and isn't
    # cached (nixpkgs#573527). Drop once nixpkgs has #574509.
    nixpkgs-atuin.url = "github:NixOS/nixpkgs/e7439b6b14ad3cc35d05608ebca9bce01a25f5f8";

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

    lanzaboote = {
      url = "github:nix-community/lanzaboote/v1.2.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    betterfox-nix.url = "github:HeitorAugustoLN/betterfox-nix";

    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-flatpak.url = "github:gmodena/nix-flatpak/?ref=latest";

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Source only, built with nixpkgs' recipe in modules/programs/desktop/waybar/home.nix.
    waybar = {
      url = "github:Alexays/Waybar";
      flake = false;
    };
  };

  outputs = {
    self,
    nixpkgs,
    ...
  } @ inputs: let
    linuxPkgs = nixpkgs.legacyPackages.x86_64-linux;
    specialArgs = {
      inputs = inputs;
    };
  in {
    nixosConfigurations =
      {
        DESKTOP-DYLAN = nixpkgs.lib.nixosSystem {
          specialArgs = specialArgs;

          # nix-style: ignore-order
          modules = [
            ./modules/hosts/desktop

            inputs.home-manager.nixosModules.home-manager
            inputs.lanzaboote.nixosModules.lanzaboote
            inputs.nix-flatpak.nixosModules.nix-flatpak
            inputs.sops-nix.nixosModules.sops
          ];
        };

        G3JC7G4 = nixpkgs.lib.nixosSystem {
          specialArgs = specialArgs;

          # nix-style: ignore-order
          modules = [
            ./modules/hosts/wsl

            inputs.home-manager.nixosModules.home-manager
            inputs.nixos-wsl.nixosModules.default
          ];
        };
      }
      # Appears once the install's hardware.nix is committed.
      // nixpkgs.lib.optionalAttrs (builtins.pathExists ./modules/hosts/laptop/hardware.nix) {
        LAPTOP-ON9AU = nixpkgs.lib.nixosSystem {
          specialArgs = specialArgs;

          # nix-style: ignore-order
          modules = [
            ./modules/hosts/laptop

            inputs.home-manager.nixosModules.home-manager
            inputs.lanzaboote.nixosModules.lanzaboote
          ];
        };
      }
      // nixpkgs.lib.optionalAttrs (builtins.pathExists ./modules/hosts/homelab/hardware.nix) {
        jia-opena0 = nixpkgs.lib.nixosSystem {
          specialArgs = specialArgs;

          # nix-style: ignore-order
          modules = [
            ./modules/hosts/homelab

            inputs.home-manager.nixosModules.home-manager
            inputs.sops-nix.nixosModules.sops
          ];
        };
      }
      // nixpkgs.lib.optionalAttrs (builtins.pathExists ./modules/hosts/proxy/hardware.nix) {
        proxy-jia-opena0 = nixpkgs.lib.nixosSystem {
          specialArgs = specialArgs;

          # nix-style: ignore-order
          modules = [
            ./modules/hosts/proxy

            inputs.disko.nixosModules.disko
            inputs.home-manager.nixosModules.home-manager
            inputs.sops-nix.nixosModules.sops
          ];
        };
      };

    darwinConfigurations.MBP-DYLAN = inputs.nix-darwin.lib.darwinSystem {
      specialArgs = specialArgs;

      # nix-style: ignore-order
      modules = [
        ./modules/hosts/macbook

        inputs.home-manager.darwinModules.home-manager
      ];
    };

    # `nix flake init -t ~/nixos#<name>` in a new project.
    templates.java = {
      path = ./templates/java;
      description = "Java project — a JDK and javac, no build file";
    };

    templates.rojo = {
      path = ./templates/rojo;
      description = "Roblox project — Rojo and the Luau toolchain";
    };

    templates.rust = {
      path = ./templates/rust;
      description = "Rust project — a cargo toolchain and rust-analyzer";
    };

    # Every host, and the formatting; CI builds each one as its own job.
    checks.aarch64-darwin.MBP-DYLAN = self.darwinConfigurations.MBP-DYLAN.system;
    checks.x86_64-linux =
      builtins.mapAttrs (_: host: host.config.system.build.toplevel) self.nixosConfigurations
      // {
        formatting = linuxPkgs.runCommand "formatting" {} ''
          ${linuxPkgs.alejandra}/bin/alejandra --check ${self}
          touch $out
        '';
      };

    formatter.aarch64-darwin = nixpkgs.legacyPackages.aarch64-darwin.alejandra;
    formatter.x86_64-linux = linuxPkgs.alejandra;
  };
}
