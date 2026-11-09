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

Every `VMD_FEAT_*` flag in `drivers/pci/controller/vmd.c` is about membar
shadowing, bus numbering, MSI remapping or power management; none is about
interrupt ordering. `7d0b` gets plain `VMD_FEATS_CLIENT`, and `vmd_irq()` is a
bare demultiplex loop with no `udelay` and no dummy read.

Read the flag list from the tree rather than trusting a copy of it here — which
bit is free is what the local patch depends on, and upstream does claim new
ones (7.3 added `VMD_FEAT_USE_BIOS_INFO`):

```bash
sed -n '/^enum vmd_features/,/^};/p' drivers/pci/controller/vmd.c
```

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

Deployed, as `boot.kernelParams` in [`default.nix`](default.nix). They stay on
alongside the patch below, which narrows the race rather than closing it.

| parameter | why |
| --- | --- |
| `nvme_core.io_timeout=5` | the freeze *is* this timeout. Safe to shorten here specifically because all 634 events recovered by polling — none was a real device failure, so there is nothing being cut short |
| `nvme.use_threaded_interrupts=1` | defers CQ processing into a threaded handler, giving the DMA time to land. Approximates the rejected upstream `udelay` patch |
| `nvme_core.default_ps_max_latency_us=0` | disables APST. The drive otherwise descends to PS4 (45ms exit latency, permitted by the 100000 default). Aimed at the idle correlation |

Revert by deleting them from `default.nix` and rebuilding.

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

## The patch

[`vmd-mtl016.patch`](vmd-mtl016.patch), applied via `boot.kernelPatches` in
[`default.nix`](default.nix) — which is also where the reasoning for patching
the kernel in-tree, rather than shipping a module that replaces `vmd.ko`,
lives. It adds the `VMD_FEAT_INTERRUPT_QUIRK` flag upstream rejected, gated to
`8086:7d0b` alone, and delays 4us in `vmd_irq()` before demuxing.

It is the rejected workaround, not the fix that was asked for: expect the
stalls to become rare, not to vanish. If they persist, the answer is the
firmware route above, not a longer delay.

Two consequences worth knowing before a kernel bump:

- **The kernel is built from source.** It and everything built against it
  (nvidia) stop coming from the binary cache, so `nh os build` on a kernel bump
  is a local compile, not a download.
- **The build fails on a new kernel series, deliberately.** The patch is gated
  to the series it was verified against, and the assertion message says what to
  do. The gate matters more than `patch` succeeding: the quirk occupies a free
  `VMD_FEAT_*` bit, and a rebase that aliases it onto a flag upstream has since
  claimed would apply cleanly and then enable unrelated behaviour on the boot
  device's own controller. Re-read the flag list by hand, every time.

### Re-porting it to a new series

1. Get the new `drivers/pci/controller/vmd.c` and read the `vmd_features` enum.
   **Pick a bit nothing else uses** and update the patch's flag.
2. Re-apply the other edits — the include, the `vmd_irq_list` field and its
   kernel-doc line, the `udelay` in `vmd_irq()`, the `vmd_alloc_irqs` signature,
   its per-vector assignment, its call site, and the `0x7d0b` table entry.
3. Regenerate the patch, confirm `patch -p1 --dry-run` is clean with no fuzz,
   and widen the gate in `default.nix`.

### Verifying it took

The patch adds a delay and no log line, so it leaves no runtime fingerprint —
nothing in `dmesg` or `/proc` will say whether it is in. There are two checks
worth doing instead.

That the booted kernel really is the patched build:

```bash
nix derivation show "$(nix-store -q --deriver "$(readlink -f /run/booted-system/kernel)")" \
  | grep vmd-mtl016
```

And the symptom, which is the number that actually matters:

```bash
journalctl --no-pager _TRANSPORT=kernel | grep -c "timeout, completion polled"
```

Note `journalctl -k` implies `-b` and reports the current boot only. Compare
against the baseline in **Confirming it** above — every boot affected. Under
this same patch on EndeavourOS the count stopped advancing entirely, across
roughly 85 boots.

### Rollback

Comment out `boot.kernelPatches` in [`default.nix`](default.nix) and rebuild;
the next generation runs the stock kernel straight from the cache. The previous
generation stays bootable in the meantime, which is the real rollback path if a
patched kernel ever fails to boot.
