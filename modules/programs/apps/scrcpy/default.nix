{pkgs, ...}: let
  phone-mirror = pkgs.writeShellApplication {
    name = "phone-mirror";
    runtimeInputs = with pkgs; [
      android-tools
      avahi
      coreutils
      gawk
      libnotify
      procps
      scrcpy
    ];
    text = builtins.readFile ./phone-mirror.sh;
  };
in {
  environment.systemPackages = with pkgs; [
    android-tools # adb, for pairing the phone over wireless debugging
    phone-mirror # fuzzel's "Phone Mirroring" and waybar's phone right-click
    scrcpy # mirror and control the phone
  ];

  homeManagerModules = [./home.nix];
}
