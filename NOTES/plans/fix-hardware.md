# Mac hardware gaps on the Mac mini M2 (audit 14)

Sleep and keyboard wake belong to `gap-wake`. The test kernel is built by `gap-kernel-next`. Full status: `HARDWARE-GAPS.md`.

## What the user should get, in order

| # | Gap | Felt by | Path | Status |
|---|-----|---------|------|--------|
| 1 | Fan | safety first | None needed: firmware controls it | Closed by measurement, below |
| 2 | Boot, 46 s to login | every boot | Measure the firmware stage first | u-boot's 2 s gone; the split needs one filmed boot |
| 3 | HDMI audio | anyone with monitor speakers | Known, no reverse engineering | Kernel patches held; opt-in boot next |
| 4 | USB-C drive or data | anyone with a USB-C device | Known driver, unknown cause | Needs the kernel log and a plug test |
| 5 | USB-C display | second-monitor users | Patches exist, never booted | Variant device tree in the test kernel |
| 6 | Thunderbolt | docks, fast drives | Reverse engineering, not done by anyone | Do not start; see below |

## Fan

Not stuck. A 25-minute all-core soak reached 99 °C on the die at full clock, with no throttling. `fan1_target` sat at 1700 rpm until about 940 s, then moved between 1700 and 1965 rpm by itself as the die passed 97 °C, and the fan followed. No write to the SMC was involved.

This matches Asahi (firmware controls the fans; issue 472, closed) and a macOS test of the M2 Pro mini (1700 rpm past 90 °C, first ramp after about 5 minutes with cores in the high 90s, about 2200 rpm after 30 minutes).

Protection also exists independently of the fan: cpu-thermal throttles at 105 °C and powers off at 110 °C, polled every 2 s. So Bande writes no fan policy. The `fan_control` parameter stays off: overriding firmware could only remove its protection, and it would be our guess at Apple's curve.

Closed by the owner on this evidence. CPU and GPU load together was not measured and will not be. `gpu-thermal` read a constant 4.607 °C for about two minutes during the soak; left as it is.

## Boot

46 s = firmware 29-45 s + loader 3.2 s + kernel 4.1 s + 9.3 s of userspace.

- Firmware is iBoot, then unboot stages 1 and 2, then u-boot. Nothing records the split. Candidates from reading the code: both unboot stages reconfigure an external display (DCP start, up to 2 s waiting for HPD, a modeset); u-boot runs `usb start` for its keyboard. `bootdelay` was 2 s and is now 0, still interruptible by a held key.
- Measure before changing more. One filmed cold boot separates iBoot and unboot from u-boot. `usb start` stays until then: removing it would also remove the keyboard from the boot menu, which is how a fallback kernel is chosen.
- Loader: 3.2 s is this machine's menu timeout, kept while test kernels are in use.
- Userspace: fsck of the ESP, zram setup and networkd-persistent-storage all end together after 2.07 s. That points to one shared stall, unexplained without the journal. Order behind `network.target` costs under 1 s and is systemd's own; `NetworkManager-wait-online` and docker do not hold the greeter.

## HDMI audio

Design in `notes/backlog/hdmi-audio.md`, option B: a lost link is an xrun and prepare recovers, as on every other Linux HDMI path. Stages:

1. Kernel (`held/hdmi-audio`, default still off): xrun on link loss, prepare re-reads the sink, balanced runtime PM, rate sieve fix, period cap, suspend, ELD control, card names.
2. Owner boot with `appledrm.hdmi_audio=1`, with `notes/hdmi-audio-check.sh`.
3. If it passes: UCM file and WirePlumber rule so the sink is named HDMI and stays non-default, a soak, then default on.

Dropped from the plan: chmap from the ELD (the DCP's elements stay authoritative) and the connector name in the long name (the connector does not exist yet when the card is made; the DCP's name identifies it).

## USB-C

The running kernel carries the test6 work. Its thermal zones are proof, and version `+bande7` is the port commit. So "fixed in test6" was wrong as a next step: port1 still shows a partner with no PD and no UDC on the kernel that has those fixes. The next step is the kernel log and a plug test, not another kernel.

DP alt mode: `held/dp-altmode` builds `t8112-j473-dpalt.dtb` and leaves the default device tree alone. Asahi's `fairydust` still marks it developer-only and uses an always-on power domain for the same port; we do not. Asahi's DCP robustness fixes of 2026-11-03 (`dcp_start` check, unbind guards, piodma at probe) are worth taking if the first boot shows a bind failure on the second DCP.

## Thunderbolt

Stop here. Asahi's driver gives USB3 tunnels and host-to-host networking only; PCIe and DisplayPort tunnels and suspend with a device attached "require additional work and reverse engineering that is not done yet". Most docks and fast drives need PCIe. Porting phase 1 is 5-7 days for little of what a user expects from the word Thunderbolt, and upstream's interface is still changing. Revisit when Asahi's series lands or PCIe tunnels appear. Plan: `notes/backlog/usb4-thunderbolt.md`.
