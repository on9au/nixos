# Whole-machine freezes on `LAPTOP-ON9AU` (NVMe behind Intel VMD)

Investigated 2026-08-17, on kernel `7.1.8-arch1-3`.

**Symptom.** Everything stops for ~30 seconds. Not a crash — the cursor still
moves, audio may keep playing, and it comes back on its own. It happens when
you come back to the machine and touch something, almost never in the middle of
sustained work.

**Cause.** The SSD sits behind an Intel VMD controller with a known hardware
erratum (**MTL016**) that loses interrupts. Each freeze is one NVMe command
hitting the 30-second timeout.

```
nvme nvme0: I/O tag 391 (8187) QID 4 timeout, completion polled
```

There is no kernel fix and none planned — see **Upstream status**. Skip to
**What to actually do** if you just want it to stop.

## Reading that message

`completion polled` is the whole diagnosis, and it means the drive is *fine*.

The drive received the command, executed it, and wrote the result into the
completion queue. What never arrived was the interrupt announcing it. Nothing
notices the result sitting there until `nvme_core.io_timeout` (30s) expires and
the driver polls the queue as a last resort — finds the completion already
present — and carries on. Whatever process was blocked on that read waited the
full 30 seconds for data that was ready almost immediately.

It freezes the *whole desktop* because the blocked read is usually something on
the critical path, and everything else queues behind it.

The erratum: the VMD raises the MSI **before** the DMA'd completion data has
landed — a PCIe write-ordering violation. The driver reads a completion queue
entry that is not yet valid, sees nothing, and goes back to sleep.

## The hardware

```
0000:00:0e.0 RAID bus controller: Intel Core Ultra 200H/200V Series VMD [8086:7d0b]
10000:e1:00.0 Non-Volatile memory controller: Sandisk SN8000S NVMe SSD [15b7:5049]
```

`8086:7d0b` is precisely the device ID MTL016 is written against.

The `10000:` PCI domain is the tell that VMD is in the path — VMD invents a
synthetic domain for the devices it hides behind itself. This is Intel RST /
VMD being enabled in the Dell firmware, which is how the machine shipped
(Windows needs it for RST).

### `/proc/interrupts` looks broken here, and isn't

```
185: nvme0q0  sum=0
186: nvme0q1  sum=0        <- every nvme queue reads zero
...
168: vmd0     sum=7931
169: vmd0     sum=5954     <- the real counts are here
```

Zero interrupts on every NVMe queue while the disk is clearly working is
alarming and completely normal under VMD: child MSI-X vectors are remapped onto
the VMD controller's own IRQs, and `vmd_irq()` demultiplexes them. The per-queue
counters are never incremented. **Do not chase this** — it is not evidence of
anything.

## Confirming it

Count them across every boot in the journal. Note `journalctl -k` implies
`-b` (current boot only), which will badly understate it — use `_TRANSPORT`:

```bash
journalctl --no-pager _TRANSPORT=kernel | grep -c "timeout, completion polled"
```

At time of writing: **634 across 20 boots, every boot affected**, 11 in the
first 20 minutes of one ordinary session.

Check that the running kernel still has no mitigation — if this ever prints an
interrupt-related flag, the situation has changed:

```bash
sudo zstd -dc /lib/modules/$(uname -r)/kernel/drivers/pci/controller/vmd.ko.zst \
  | strings | grep -oE "VMD_FEAT_[A-Z_]+" | sort -u
```

## Why it hits when the machine is idle

| test | duration | timeouts |
| --- | --- | --- |
| sustained 4GB `O_DIRECT` read | ~30s | **0** |
| idle, with periodic small reads | ~6 min | **3** |

Backwards from each timeout (they are logged 30s *after* the command was
issued) puts every affected command inside an idle window.

This is the erratum behaving exactly as described, not a second problem. Under
sustained load the queues are busy, and the *next* interrupt reaps the orphaned
completion along with its own — the race is lost but nothing notices. With
sporadic, low-queue-depth I/O there is no next interrupt, so the completion sits
untouched for the full 30 seconds.

Hence the symptom: it bites when you return to an idle machine and open
something, and it stays quiet while you are actually hammering the disk. **A
benchmark will not reproduce this.** Leave the machine alone for a minute first.

## Ruled out

Worth keeping, because every one of these is a plausible-looking dead end:

| suspected | finding |
| --- | --- |
| dying SSD | SMART **PASSED**, 1% used, **0** media/data integrity errors, 31°C, 100% spare |
| filesystem damage | **zero** ext4 errors, `blk_update_request` failures, or `Buffer I/O error` — ever |
| controller giving up | **zero** controller resets or command aborts; all 634 recovered by polling |
| kernel deadlock | **zero** `hung_task` / soft-lockup / RCU stall events |
| memory pressure | 62GB RAM, 48GB free, swap untouched at 0B |
| stale firmware | SSD (`63112104`) **and** system firmware already latest per `fwupdmgr` |

No data is at risk. Every affected I/O completed correctly, just late.

## Upstream status

There is no fix in mainline, and no patch pending.

Current `drivers/pci/controller/vmd.c` defines six feature flags —
`HAS_MEMBAR_SHADOW`, `HAS_BUS_RESTRICTIONS`, `HAS_MEMBAR_SHADOW_VSCAP`,
`OFFSET_FIRST_VECTOR`, `CAN_BYPASS_MSI_REMAP`, `BIOS_PM_QUIRK` — none about
interrupt ordering. `7d0b` gets plain `VMD_FEATS_CLIENT`, and `vmd_irq()` is a
bare demultiplex loop with no `udelay` and no dummy read.

One attempt was made in September 2024 ([patch][p], [review][r]): a
`VMD_FEAT_INTERRUPT_QUIRK` flag gating a `udelay(4)` before
`generic_handle_irq()`. It was rejected —

- **Manivannan Sadhasivam:** *"Adding a delay for PCIe ordering is not going to
  work always."*
- **Keith Busch:** a register read is required because it *"flushes pending
  device-to-host writes, which is most likely what the errata really requires"*.
  Also that the quirk had to be device-specific rather than global.

They are right: a delay makes the race less likely, it does not enforce
ordering. Intel's own erratum text prescribes the dummy read. No v2 was ever
sent; the thread trails off into a build-warning bot reply.

It is unlikely to land soon, because the correct fix is awkward. `vmd_irq()` is
the hot path for *every* interrupt from *every* device behind VMD, and a dummy
MMIO read is a synchronous round trip to the device. Doing that per interrupt
costs throughput for everyone, including unaffected hardware — hence the
insistence on narrow device gating, which nobody has done.

**Consequence: upgrading the kernel will not fix this.** A rolling Arch kernel
buys nothing here. Do not wait it out.

[p]: https://lkml.iu.edu/2409.0/02004.html
[r]: https://lkml.iu.edu/hypermail/linux/kernel/2409.0/03089.html

## What to actually do

### The real fix: turn VMD off in the Dell firmware

Set the storage/SATA mode from **RAID On / Intel RST with VMD** to
**AHCI/NVMe**. The drive then attaches directly, the VMD interrupt path is gone,
and the erratum cannot fire. Linux does not care — root is mounted by UUID.

> [!WARNING]
> **Windows dual-boots off this disk and `nvme0n1p3`/`p4` are BitLocker.**
> Do not flip this switch unprepared:
>
> - Windows will bugcheck `INACCESSIBLE_BOOT_DEVICE` unless you first boot it
>   once in safe mode (`bcdedit /set {current} safeboot minimal`) so it loads
>   `stornvme` instead of the RST driver.
> - **BitLocker will demand the recovery key**, because changing the firmware
>   storage mode changes the PCR measurements its key is sealed against. Have
>   the keys in hand *before* touching the setting, not after.

### Stopgap: kernel parameters

Does not fix the lost interrupt — turns a 30s freeze into a ~5s one, which is
the difference between unusable and irritating.

Boot is dracut + `kernel-install` + systemd-boot (Type #1 entries, **not** UKI
— `/etc/kernel/cmdline` is the source, the ESP entry is generated). Add to
`/etc/kernel/cmdline`:

```
nvme_core.io_timeout=5 nvme.use_threaded_interrupts=1 nvme_core.default_ps_max_latency_us=0
```

```bash
sudo reinstall-kernels     # regenerates initrd + the loader entry
```

| parameter | why |
| --- | --- |
| `nvme_core.io_timeout=5` | the freeze *is* this timeout. Safe to shorten here specifically because all 634 events recovered by polling — none was a real device failure, so there is nothing being cut short |
| `nvme.use_threaded_interrupts=1` | defers CQ processing into a threaded handler, giving the DMA time to land. Approximates the rejected upstream `udelay` patch |
| `nvme_core.default_ps_max_latency_us=0` | disables APST. The drive otherwise descends to PS4 (45ms exit latency, permitted by the 100000 default). Aimed at the idle correlation |

Revert by deleting the three parameters and re-running `reinstall-kernels`.

To try a value before committing to it, there is a live per-queue knob in
**milliseconds** that needs no reboot and reverts by itself:

```bash
echo 5000 | sudo tee /sys/block/nvme0n1/queue/io_timeout   # default 30000
```

(The `nvme_core.io_timeout` module param is mode `0644`, but writing it only
seeds `rq_timeout` at queue creation — it will not move the running queue. Use
the block-queue path above.)

### Looks like a fix, isn't

**`nvme_core.io_timeout=0`.** Not "no timeout" — **every I/O expires
immediately.** It is a plain `uint` with no validation, and `blk_add_timer()`
has no zero guard, so `expiry = jiffies + 0` is a deadline of *now*.

The deeper mistake is the direction, though. **The timeout is the recovery
mechanism here, not the bug.** The interrupt is gone for good, and in the
sporadic case nothing else will ever reap that completion — `nvme_timeout()`
polling the CQ is the only thing that unsticks it, which is exactly what
`completion polled` reports. The freeze is the *wait for* the rescue. A genuinely
infinite timeout would hang that I/O forever and take the filesystem with it.

Shorter, never longer. And not *too* short: when the poll finds no completion
(a real slow command — large discard, flush barrier, GC, thermal throttle) the
driver escalates to aborting the command and then **resetting the controller**,
which is far worse than a stall and can surface as I/O errors or a read-only
remount. There are currently zero resets on this machine; keep it that way.

**`nvme.poll_queues=N`.** The obvious move when interrupts are the problem is to
stop using them — but Linux polled queues only serve `RWF_HIPRI` / io_uring
high-priority submissions. Ordinary buffered I/O, which is what is actually
freezing you, never touches them. It will change nothing.

**Waiting for a kernel update.** See **Upstream status**.

**Replacing the SSD.** The drive is healthy and the bug is in the VMD
controller, on the CPU package. A new drive lands behind the same VMD.

## Unrelated, found on the way

`warp-svc` (Cloudflare WARP) logs at DEBUG: **1333 of 5362** journal lines in
one boot, and the journal has grown to **855MB**. It is not causing the freezes.
It is constant background writes, which widen the sporadic-idle-I/O window where
the bug bites, and it is most of what `journalctl` has to sift through when
investigating anything at all. Worth turning down.
