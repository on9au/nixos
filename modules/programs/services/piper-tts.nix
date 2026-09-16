{
  lib,
  pkgs,
  ...
}: let
  voiceUrl = "https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/en/en_US/lessac/medium/en_US-lessac-medium";
  voice = pkgs.linkFarm "piper-voice-en_US-lessac-medium" {
    "voice.onnx" = pkgs.fetchurl {
      url = "${voiceUrl}.onnx";
      hash = "sha256-Xv4J5pkCGHgnr2RuGm6dJp3udp+Yd9F7FrG0buqvAZ8=";
    };
    "voice.onnx.json" = pkgs.fetchurl {
      url = "${voiceUrl}.onnx.json";
      hash = "sha256-7+GcQXvtBV8taZCCSMa6ZQ+hNbyGiw5quz2hgdq2kKA=";
    };
  };
in {
  environment.systemPackages = [pkgs.piper-tts];

  # Setting `config` replaces the packaged /etc/speech-dispatcher, so piper is
  # the only output module.
  services.speechd = {
    enable = true;
    config = ''
      AudioOutputMethod "pulse"
      AddModule "piper" "sd_generic" "piper.conf"
      DefaultModule piper
      DefaultLanguage "en"
    '';
    # speechd's multipliers are integers ×100, so rate (-100..100) becomes a
    # 150..50 percent length scale and volume becomes paplay's 0..131072 (100% at 0).
    # Medium-quality voices are 22050 Hz mono.
    modules.piper = ''
      GenericExecuteSynth "printf %s \'$DATA\' | ${lib.getExe pkgs.piper-tts} --model ${voice}/voice.onnx --length-scale $(${lib.getExe pkgs.gawk} \'BEGIN { print $RATE / 100 }\') --output-raw | ${pkgs.pulseaudio}/bin/paplay --raw --rate=22050 --format=s16le --channels=1 --volume=$VOLUME"
      GenericRateAdd 100
      GenericRateMultiply -50
      GenericRateForceInteger 1
      GenericVolumeAdd 65536
      GenericVolumeMultiply 65536
      GenericVolumeForceInteger 1
      AddVoice "en" "FEMALE1" "en_US-lessac-medium"
      DefaultVoice "en_US-lessac-medium"
    '';
  };
}
