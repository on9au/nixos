{ config, lib, pkgs, inputs, ... }:

{
  imports = [
    inputs.home-manager.nixosModules.home-manager
    ../common/unfree.nix
    ../common/home-manager.nix
  ];

  unfree.allow = [ "claude-code" "unrar" ];

  time.timeZone = "Australia/Melbourne";
  i18n.defaultLocale = "en_AU.UTF-8";

  users.users.djpro = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    shell = pkgs.zsh;
  };

  programs.zsh.enable = true;
  # home-manager's zsh already runs compinit.
  programs.zsh.enableGlobalCompInit = false;

  # Mason's prebuilt LSP binaries.
  programs.nix-ld.enable = true;

  environment.systemPackages = with pkgs; [
    vim wget curl git pciutils usbutils
    # Not home.packages: gcc and clang both provide `cc`, which collides there.
    gcc gnumake clang
  ];

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };
  nix.optimise.automatic = true;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
}
