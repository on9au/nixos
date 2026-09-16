{...}: {
  services.btrbk.instances.default = {
    onCalendar = "hourly";
    settings = {
      timestamp_format = "long";

      snapshot_preserve = "12h 7d 4w";
      snapshot_preserve_min = "latest";
    };
  };
}
