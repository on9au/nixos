{...}: {
  # GUI apps stay casks: Accessibility/Input Monitoring grants attach to the app
  # path, and a store path changes on every update.
  homebrew = {
    enable = true;
    onActivation.cleanup = "none";
  };
}
