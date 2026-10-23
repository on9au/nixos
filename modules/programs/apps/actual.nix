{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    actual-client # budgeting; syncs with budget.opena0.net
  ];
}
