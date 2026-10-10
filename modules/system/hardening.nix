# For the headless hosts: nothing here suits a desktop, where dmesg and
# debuggers are everyday tools.
{...}: {
  boot.kernel.sysctl = {
    "kernel.dmesg_restrict" = 1;
    "kernel.kptr_restrict" = 2;
    "kernel.unprivileged_bpf_disabled" = 1;
    "net.core.bpf_jit_harden" = 2;
  };

  # Only wheel can execute sudo at all, so a bug in it is out of a service's reach.
  security.sudo.execWheelOnly = true;
}
