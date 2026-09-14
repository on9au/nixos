{...}: {
  services.pipewire.wireplumber.extraConfig."51-apple-dongle" = {
    "monitor.alsa.rules" = [
      {
        matches = [
          {"device.name" = "alsa_card.usb-Apple__Inc._USB-C_to_3.5mm_Headphone_Jack_Adapter_DWH5373010Z2FN3AQ-00";}
        ];
        actions.update-props = {
          "api.alsa.period-num" = 3;
          "api.alsa.period-size" = 64;
          "audio.rate" = 48000;
          "device.profile" = "pro-audio";
        };
      }

      # Period size and rate are read from the nodes, not the device.
      {
        matches = [
          {"node.name" = "~alsa_.*\\.usb-Apple__Inc\\._USB-C_to_3\\.5mm_Headphone_Jack_Adapter_DWH5373010Z2FN3AQ-00\\..*";}
        ];
        actions.update-props = {
          "api.alsa.period-num" = 3;
          "api.alsa.period-size" = 64;
          "audio.rate" = 48000;
        };
      }
    ];
  };
}
