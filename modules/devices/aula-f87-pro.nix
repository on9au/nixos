# AULA F87 Pro, on the monitor KVM's hub chain. Enumerates as
# 258a:010c "BY Tech Gaming Keyboard".
{...}: {
  # The keyboard's MCU is not awake when the kernel first asks for its device
  # descriptor, so enumeration eats the full 5s USB_CTRL_GET_TIMEOUT before a
  # retry succeeds -- on roughly three boots in four. That lands after the LUKS
  # passphrase prompt, leaving it unable to take input. DELAY_INIT trades 100ms
  # of settling time for the timeout.
  boot.kernelParams = ["usbcore.quirks=258a:010c:g"];
}
