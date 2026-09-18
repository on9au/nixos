# Installing `LAPTOP-ON9AU`: EndeavourOS -> NixOS

Replaces the EndeavourOS install on `nvme0n1p7` with NixOS on LUKS2 + btrfs,
TPM2 unlock, and Secure Boot via lanzaboote — **without changing the partition
table**, because Windows on this machine is BitLocker-sealed against a PCR set
that includes the GPT.

Read [Before you start](#before-you-start) in full. The rest is safe to follow
step by step.

## The disk as it stands

Surveyed 2026-09-18. `nvme0n1`, 1907.73 GiB, GPT, behind Intel VMD.

| part | start | size | type | contents |
| --- | --- | --- | --- | --- |
| `p1` | 0.00 G | 420 MiB | EFI System | **shared ESP** — Windows, Dell, EndeavourOS |
| `p2` | 0.41 G | 128 MiB | MS Reserved | leave alone |
| `p3` | 0.54 G | 672.68 G | NTFS `OS` (C:) | Windows, **BitLocker XtsAes256** |
| `p7` | 673.22 G | 871.72 G | Linux filesystem | **ext4 `endeavouros`, 306 G used — this gets destroyed** |
| `p8` | 1544.94 G | 59.60 G | Linux swap | becomes dead space, see [step 11](#11-optional-reclaim-p8) |
| `p4` | 1604.54 G | 300.00 G | ReFS `Dev Drive` (G:) | **BitLocker XtsAes256** |
| — | 1904.54 G | 685 MiB | unallocated | OEM alignment gap |
| `p5` | 1905.21 G | 0.97 G | Recovery | `WINRETOOLS` |
| `p6` | 1906.18 G | 1.55 G | Recovery | `DELLSUPPORT` |

Identifiers this runbook pins:

```
ESP  filesystem UUID   FE84-625A                              (Windows made it; do not reformat)
p7   partition  GUID   bdb6dd36-f103-4f7d-b6cb-6a0f72591317
p8   partition  GUID   68b615f6-7a0f-4df6-8192-d51646392909
LUKS container  UUID   e873a998-2eac-4755-85cb-17a36baceb9e   (forced at luksFormat)
btrfs filesystem UUID  6a5b62b6-0573-41d3-ab37-58da1d87d4b0   (forced at mkfs)
```

The last two are *chosen*, not discovered — that is why `hardware.nix` could be
written before the install. If you deviate from the `--uuid`/`-U` flags below,
`hardware.nix` stops matching and the machine will not boot.

There is **no Linux recovery or live partition on this disk**, and after this
you will have wiped the only other Linux install. Keep the USB stick.

## Before you start

### 1. Get the BitLocker recovery keys, and verify them

Non-negotiable. `C:` is sealed to the TPM, Secure Boot is currently **off**, so
BitLocker is using the legacy PCR profile — which measures **PCR 5, the GPT**,
and **PCR 7, the Secure Boot state**. Enabling Secure Boot in [step 8](#8-secure-boot)
*will* move PCR 7. Without the key at that point you are locked out of Windows.

In an **admin** PowerShell:

```powershell
manage-bde -protectors -get C:
manage-bde -protectors -get G:
```

Write down the 48-digit numerical passwords. If policy blocks the readout,
get them from whoever administers BitLocker for this machine *before* continuing.

### 2. Back up the 306 GiB on p7

You can do this from Windows without booting Linux — WSL2 can mount the ext4
partition directly. In an **admin** shell:

```powershell
wsl --mount \\.\PHYSICALDRIVE0 --partition 7 --type ext4
```

It appears under `/mnt/wsl/PHYSICALDRIVE0p7`. Copy what you want out, then:

```powershell
wsl --unmount \\.\PHYSICALDRIVE0
```

### 3. Write a USB stick anyway

[Step 4](#4-kexec-into-the-installer) avoids needing one, but a kexec that hangs
on this VMD controller leaves you with a wiped disk and no installer. Write the
NixOS minimal ISO to a stick and keep it in the bag.

### 4. Suspend BitLocker

Do this last, immediately before you begin. Admin PowerShell:

```powershell
manage-bde -protectors -disable C: -rebootcount 0
manage-bde -protectors -disable G: -rebootcount 0
manage-bde -status
```

`-rebootcount 0` suspends indefinitely rather than for N reboots — you want
that, because this runbook spans several reboots and a firmware change.
`-status` must show `Protection Off` for both. **Re-enabling is
[step 10](#10-re-enable-bitlocker), do not skip it.**

---

## 1. kexec into the installer

From the running EndeavourOS, as root. This boots the NixOS installer entirely
into RAM (you have 63 GiB), which frees `p7` completely — no USB, no partition
changes.

```bash
curl -L https://github.com/nix-community/nixos-images/releases/download/nixos-unstable/nixos-kexec-installer-noninteractive-x86_64-linux.tar.gz \
  | tar -xzf- -C /root
```

**Add the VMD parameters before running it.** Without them the installer eats
30-second I/O stalls throughout ([nvme-vmd-stalls.md](nvme-vmd-stalls.md)).
Open `/root/kexec/kexec-boot` and append to the existing kernel command line
argument:

```
nvme_core.io_timeout=5 nvme.use_threaded_interrupts=1 nvme_core.default_ps_max_latency_us=0
```

Then:

```bash
/root/kexec/run
```

The console comes back as the NixOS installer after a few seconds. Confirm the
disk is visible before going further:

```bash
lsblk -o NAME,SIZE,FSTYPE,LABEL,PARTUUID /dev/nvme0n1
```

If `nvme0n1` is missing, the `vmd` module did not load — reboot into the USB
stick and continue from step 2 there.

## 2. Create the LUKS container

> [!CAUTION]
> This destroys the EndeavourOS install. Confirm you are pointed at `p7` by
> its partition GUID, not by its number:
>
> ```bash
> lsblk -no PARTUUID /dev/nvme0n1p7   # must print bdb6dd36-f103-4f7d-b6cb-6a0f72591317
> ```

```bash
cryptsetup luksFormat \
  --type luks2 \
  --uuid e873a998-2eac-4755-85cb-17a36baceb9e \
  --pbkdf argon2id \
  /dev/nvme0n1p7
```

The passphrase you set here is the **break-glass key**. It stays in keyslot 0
forever; TPM2 becomes the routine unlock in [step 9](#9-enroll-the-tpm) but never
replaces this. Use something long, and put it wherever you keep the BitLocker
keys.

```bash
cryptsetup open /dev/nvme0n1p7 cryptroot
```

## 3. btrfs and subvolumes

Mirrors DESKTOP-DYLAN minus `@games`.

```bash
mkfs.btrfs -L nixos -U 6a5b62b6-0573-41d3-ab37-58da1d87d4b0 /dev/mapper/cryptroot

mount /dev/mapper/cryptroot /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@nix
btrfs subvolume create /mnt/@log
btrfs subvolume create /mnt/@snapshots
btrfs subvolume create /mnt/@swap
umount /mnt
```

Mount them the way `hardware.nix` declares them:

```bash
mount -o subvol=@,compress=zstd:1,noatime          /dev/mapper/cryptroot /mnt
mkdir -p /mnt/{home,nix,var/log,.snapshots,swap,boot}
mount -o subvol=@home,compress=zstd:1,noatime      /dev/mapper/cryptroot /mnt/home
mount -o subvol=@nix,compress=zstd:1,noatime       /dev/mapper/cryptroot /mnt/nix
mount -o subvol=@log,compress=zstd:1,noatime       /dev/mapper/cryptroot /mnt/var/log
mount -o subvol=@snapshots,compress=zstd:1,noatime /dev/mapper/cryptroot /mnt/.snapshots
mount -o subvol=@swap,noatime                      /dev/mapper/cryptroot /mnt/swap
```

Swapfile. `mkswapfile` sets NOCOW and disables compression in one go — btrfs
refuses to swap on a CoW or compressed extent, so do not just `fallocate`:

```bash
btrfs filesystem mkswapfile --size 64g --uuid random /mnt/swap/swapfile
```

64 GiB is sized for hibernation against 63 GiB of RAM ([step 12](#12-optional-hibernation)).

## 4. Mount and clean the shared ESP

```bash
mount -o fmask=0077,dmask=0077 /dev/disk/by-uuid/FE84-625A /mnt/boot
```

> [!WARNING]
> `/mnt/boot/EFI/Microsoft`, `/mnt/boot/EFI/Dell` and `/mnt/boot/EFI/Boot` are
> Windows' and Dell's. Deleting any of them costs you the Windows bootloader or
> the Dell diagnostics. Remove **only** the EndeavourOS subtrees:

```bash
rm -rf /mnt/boot/936f97a5094a4f62a804acd22b0ed518
rm -rf /mnt/boot/EFI/EOS
rm -f  /mnt/boot/loader/entries/936f97a5094a4f62a804acd22b0ed518-*.conf
df -h /mnt/boot
```

That reclaims ~163 MiB, taking free space from 147 MiB to roughly 310 MiB. That
number is the whole reason `configurationLimit` is forced to 3 in
[`default.nix`](default.nix).

Clear the stale firmware entry too — lanzaboote writes a fresh one:

```bash
efibootmgr        # find "Linux Boot Manager"
efibootmgr -b <N> -B
```

## 5. Pre-seed the Secure Boot keys

lanzaboote signs during `nixos-install`, so the keys must exist *before* it
runs, otherwise the install aborts with nothing to sign with. `pkiBundle` is
`/var/lib/sbctl` ([`../../system/boot/lanzaboote.nix`](../../system/boot/lanzaboote.nix)),
so generate into the installer and copy the tree across:

```bash
nix-shell -p sbctl --run 'sbctl create-keys'
mkdir -p /mnt/var/lib
cp -a /var/lib/sbctl /mnt/var/lib/sbctl
```

This only *creates* keys. Nothing is enrolled into firmware yet and Secure Boot
stays off until [step 8](#8-secure-boot) — that ordering is deliberate.

## 6. Get the flake onto the target

The checkout belongs at `~/nixos` — **not** `/etc/nixos`. Two things depend on
that exact path: `programs.nh.flake` is `/home/djpro/nixos`
([`../../programs/tools/nh/default.nix`](../../programs/tools/nh/default.nix)),
and `dotfiles.root` defaults to `${config.home.homeDirectory}/nixos`, so every
out-of-store symlink `config.lib.dotfiles.link` produces points into it.

It cannot be cloned there *during* the install, though. NixOS only sets
ownership on a home directory it creates itself; pre-creating `/mnt/home/djpro`
as root leaves it root-owned and home-manager activation then fails on first
boot. `djpro` also has no static uid (`users.users.djpro.uid` is null, so it is
allocated at activation), so there is no correct number to `chown` to yet.

So build from a throwaway clone in the installer's RAM, and clone to `~/nixos`
as the user after first boot. That is safe because `dotfiles.link` strips the
`inputs.self` store prefix and re-anchors on `dotfiles.root` — the link targets
come out as `/home/djpro/nixos/...` no matter where you build from:

```bash
nix-shell -p git --run 'git clone https://github.com/on9au/nixos.git /tmp/nixos'
```

Cross-check the generated hardware config against the committed one and
reconcile any difference in the module lists (the UUIDs and filesystems should
be identical — if they are not, stop and work out why):

```bash
nixos-generate-config --root /mnt --show-hardware-config > /tmp/generated.nix
diff /tmp/generated.nix /tmp/nixos/modules/hosts/laptop/hardware.nix
```

## 7. Install

```bash
nixos-install --flake /tmp/nixos#LAPTOP-ON9AU --no-root-password
```

If lanzaboote errors on signing, fall back to the two-phase path: temporarily
swap `../../system/boot/lanzaboote.nix` for `../../system/boot/systemd-boot.nix`
in `default.nix`, install, boot, then swap it back and `nixos-rebuild switch`.

Reboot. **First boot asks for the LUKS passphrase** — the TPM is not enrolled
yet.

Log in as `djpro` and put the checkout where everything expects it. Until this
exists, the live-linked nvim/tmux/mimeapps symlinks dangle and `nh` has no
flake to point at:

```bash
git clone https://github.com/on9au/nixos.git ~/nixos
```

Then confirm the install before continuing:

```bash
bootctl status                  # "Secure Boot: disabled (setup)" is expected here
findmnt -t btrfs
swapon --show
grep reboot-for-bitlocker /boot/loader/loader.conf
readlink ~/.config/nvim        # must resolve into ~/nixos, not dangle
nh os info
```

Also confirm Windows still boots, from the sd-boot menu, before you change
anything else.

## 8. Secure Boot

Order matters: **enroll keys and turn Secure Boot on before touching the TPM**,
because the TPM binding in the next step is against PCR 7, which *is* the
Secure Boot state. Do it the other way round and the unlock breaks immediately.

**a.** Put the firmware in Setup Mode. Reboot, `F2`, Security -> Secure Boot ->
Expert Key Management -> Enable Custom Mode -> **Delete All Keys**. Leave
Secure Boot itself *disabled* for now. Save and boot NixOS.

```bash
sbctl status     # must report: Setup Mode: Enabled
```

**b.** Enroll. The `--microsoft` flag is the part that keeps this machine
working:

```bash
sudo sbctl enroll-keys --microsoft
```

It enrolls Microsoft's certificates alongside yours. Without it you lose, all
at once: Windows Boot Manager, Dell's `EFI\Dell\SOS` diagnostics, and the
NVIDIA option ROM — the RTX PRO 2000's firmware is signed by the Microsoft
UEFI CA, and an unsigned option ROM under Secure Boot means no dGPU.

**c.** Verify everything that must boot is covered:

```bash
sudo sbctl verify
```

Your UKIs and `systemd-bootx64.efi` should be signed. Windows' `bootmgfw.efi`
will show as not signed *by your keys* — that is correct, it is signed by
Microsoft's, which you just enrolled.

**d.** Reboot, `F2`, set **Secure Boot Enable = On**. Save.

**e.** Back in NixOS:

```bash
bootctl status   # "Secure Boot: enabled (user)"
```

**f. Boot Windows now, before going further.** It should come up without a
recovery prompt, because you suspended protection in the prep step. If Windows
is broken, you still have an unenrolled TPM and a passphrase-unlockable disk —
this is the cheapest point to back out (`sbctl reset` plus re-enabling the
factory keys in firmware).

## 9. Enroll the TPM

Only now, with Secure Boot on and PCR 7 at its final value:

```bash
sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=7 /dev/nvme0n1p7
sudo cryptsetup luksDump /dev/nvme0n1p7 | grep -A2 systemd-tpm2
```

PCR 7 alone is deliberate. PCR 11 covers the UKI and PCR 4 the bootloader, so
binding to either would invalidate the enrollment on **every** kernel update or
lanzaboote bump, and you would re-enroll after each rebuild. PCR 7 only moves
when the Secure Boot key state moves.

The honest trade-off: PCR 7 is satisfied by *any* boot chain your enrolled keys
validate, and you just enrolled Microsoft's CA (you had to, for Windows). A
Microsoft-signed bootloader on this machine therefore also satisfies it. Adding
`--tpm2-with-pin=yes` closes that gap at the cost of typing a PIN each boot;
you asked for TPM-only, so this is noted, not applied.

Reboot. It should go straight to the desktop with no passphrase prompt. If it
prompts, the passphrase still works — check `journalctl -b -u systemd-cryptsetup@cryptroot`.

## 10. Re-enable BitLocker

Once Windows has booted cleanly at least once post-Secure-Boot:

```powershell
manage-bde -protectors -enable C:
manage-bde -protectors -enable G:
manage-bde -status
```

Both must read `Protection On`. Reboot once more through the sd-boot Windows
entry to prove `reboot-for-bitlocker yes` is doing its job — you should see the
machine reset itself once and then land in Windows with no recovery prompt.

---

## 11. Optional: reclaim p8

`p8` (59.60 GiB of ex-swap) is dead space once the swapfile is in use. Deleting
it is a **GPT write**, which is the one thing this runbook otherwise avoids, so
it needs BitLocker suspended again first. Worth batching with any other
partition work rather than doing on its own.

Note that growing `p7` into it is not free either: `p7` is LUKS, so it is
`cryptsetup resize` after the partition grows, then `btrfs filesystem resize max`.

## 12. Optional: hibernation

EndeavourOS had `resume=` configured; the equivalent here needs the swapfile's
physical offset:

```bash
sudo btrfs inspect-internal map-swapfile -r /swap/swapfile
```

Then in [`default.nix`](default.nix):

```nix
boot.resumeDevice = "/dev/mapper/cryptroot";
boot.kernelParams = [ ... "resume_offset=<the number above>" ];
```

The offset changes if the swapfile is ever recreated.

## If it goes wrong

| symptom | cause | fix |
| --- | --- | --- |
| Windows demands a recovery key | PCR 5 or 7 moved with protection on | enter the 48-digit key, then suspend protection before retrying |
| `INACCESSIBLE_BOOT_DEVICE` in Windows | VMD/RST firmware mode changed | revert the storage mode; see [nvme-vmd-stalls.md](nvme-vmd-stalls.md) |
| NixOS asks for the passphrase every boot | PCR 7 moved after enrollment | re-run [step 9](#9-enroll-the-tpm); `systemd-cryptenroll --wipe-slot=tpm2` first |
| dGPU missing after Secure Boot | keys enrolled without `--microsoft` | `sbctl enroll-keys --microsoft` again |
| `/boot` full on rebuild | UKIs larger than budgeted | drop `configurationLimit` to 2, `nix-collect-garbage -d`, rebuild |
| nothing boots at all | — | USB stick, `cryptsetup open` with the passphrase, chroot |
