{...}: {
  # Caps Lock: Ctrl held, Esc tapped; Shift+Caps is a real Caps Lock.
  services.keyd = {
    enable = true;
    keyboards.default = {
      ids = ["*"];
      settings = {
        main.capslock = "overload(control, esc)";
        shift.capslock = "capslock";
      };
    };
  };
}
