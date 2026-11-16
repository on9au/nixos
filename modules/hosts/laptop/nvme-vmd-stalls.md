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

Fixed in the kernel since 7.3.4 (7.4 in mainline) — see **Upstream status**.
The rest is the diagnosis, kept for if the stalls ever come back.

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

If it is still advancing, check the running kernel is 7.3.4 or later
(`uname -r`); older ones lack the fix.

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

Fixed by [`7307899e381c`][fix], "PCI: vmd: Flush DMA writes before handling
MSI on Meteor Lake" (mainline from 7.4-rc1, backported to 7.3.4). It adds
`VMD_FEAT_INTERRUPT_QUIRK`, set for `8086:7d0b` and, in a companion commit, for
Arrow Lake's `ad0b` (erratum ARL004). With it set, `vmd_irq()` does the dummy
read the erratum prescribes: a config-space read of the initiating device
before demuxing to its handler. That read's completion cannot pass the
device's earlier posted writes, so the completion queue is coherent by the
time the NVMe handler looks. Only the affected device IDs pay for the round
trip.

An earlier attempt in September 2024 ([patch][p], [review][r]) used the same
flag name to gate a `udelay(4)` and was rejected: a delay makes the race less
likely without enforcing ordering, and reviewers asked for the register read
and narrow device gating. Until 7.3.4 this machine ran that rejected delay as a
local kernel patch; `git log -- modules/hosts/laptop/vmd-mtl016.patch` has it.

[fix]: https://git.kernel.org/torvalds/c/7307899e381c
[p]: https://lkml.iu.edu/2409.0/02004.html
[r]: https://lkml.iu.edu/hypermail/linux/kernel/2409.0/03089.html

## What to actually do

### If it comes back: turn VMD off in the Dell firmware

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
until the count under **Verifying the fix** stops rising on the fixed kernel.

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

**Replacing the SSD.** The drive is healthy and the bug is in the VMD
controller, on the CPU package. A new drive lands behind the same VMD.

## Verifying the fix

The fix logs nothing, so the symptom is the measure:

```bash
journalctl --no-pager _TRANSPORT=kernel | grep -c "timeout, completion polled"
```

`journalctl -k` implies `-b` and reports the current boot only. Compare against
the baseline in **Confirming it** — every boot affected. Once it stops
advancing across boots, the kernel parameters above can go.
