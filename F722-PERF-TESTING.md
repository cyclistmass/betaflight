# Testing the F722 bidir DShot600 switches

This branch puts each F722 performance patch and three fixes for the DShot spin behind build switches.

**The spin:** with bidir DShot, each motor pin sends a frame (28 us) and then listens for the ESC's RPM reply
(62 us). If the next motor update comes while the pin still listens, the CPU waits in a busy loop until the
reply window closes. At 8 kHz (125 us per loop) that can cost up to 62 us. A spin fix skips that one motor
update instead, and the ESC keeps its last throttle for one more loop. Details: `F722-PERF-FINDINGS.md`.

With no switches the build is master. All switches and presets are listed in
`src/main/build/perf_switches.h`.

**Safety: none of these builds has been flown. Bench test only, props off.**

## What to build

Add `-DTEST_UNGATE_PID_DENOM_CHECK` to every build below. It lifts the #15779 downgrade so that
DShot600 and an 8 kHz PID loop stay on with bidir. It is TEST ONLY. Never release it.

| Build | EXTRA_FLAGS (plus the TEST flag) | What it shows |
|---|---|---|
| Base | (none) | Master, unchanged. The CPU still waits on a busy motor pin. The reference |
| Loop fixes | `-DPERF_LOOP` | Patches that make the PID loop faster. The CPU still waits on a busy motor pin |
| All, Opus fix | `-DPERF_ALL -DDSHOT_BB_NOSPIN_OPUS` | Faster loop, plus the Opus fix: skip the motor update instead of waiting |
| All, Sol fix | `-DPERF_ALL -DDSHOT_BB_NOSPIN_SOL` | Faster loop, plus the Sol fix: skip the motor update instead of waiting |
| All, Fable fix | `-DPERF_ALL -DDSHOT_BB_NOSPIN_FABLE` | Faster loop, plus the Fable fix: skip the motor update instead of waiting |

Example: `make CONFIG=GEPRCF722_BT_HD_V3 EXTRA_FLAGS="-DTEST_UNGATE_PID_DENOM_CHECK -DPERF_ALL -DDSHOT_BB_NOSPIN_FABLE"`

Add `-DDSHOT_BB_PROBE` to any build to measure the spin (see below). The probe is TEST ONLY.

## What board

Use an F722 with a gyro that runs at 8 kHz, for example ICM-42688P, ICM-20602 or MPU6000.
A BMI270 board runs the gyro at 3.2 kHz. Its loop is too long for the spin to occur, so it can only
show that nothing breaks.

ESCs are not necessary to measure the spin. The receive window is timer paced, so the pins stay busy
for the full window with or without an ESC. Connect bidir ESCs to check that RPM telemetry still
decodes correctly.

## Settings

```
set motor_pwm_protocol = DSHOT600
set dshot_bidir = ON
set pid_process_denom = 1
save
```

After the reboot, do `get motor_pwm_protocol` and `get pid_process_denom` to make sure the values
stayed. Without the TEST flag, F722 changes them back.

## What to measure

**With the probe** (`-DDSHOT_BB_PROBE`, `set debug_mode = NONE`), the firmware publishes these
values once a second:

| Field | Value |
|---|---|
| debug[0] | Longest spin in one second [us]. 0 with a spin fix |
| debug[1] | Motor updates that spun. With a spin fix: updates that were deferred |
| debug[2], debug[3] | Shortest and longest gap between motor frames [us] |
| debug[4] | Longest delay from the gyro interrupt to the gyro task [us] |
| debug[5] | Gyro cycles that the scheduler skipped |
| debug[6] | Frames started while the previous frame was still being sent |
| debug[7] | Total spin [0.1 % of the second] |

Read them with the Configurator sensor tab, a blackbox log, or `MSP_DEBUG`.

**Without the probe:** `set debug_mode = DSHOT_TELEMETRY_COUNTS`. debug[2] counts reception
timeouts. With the Fable fix, debug[4] counts deferred frames. Also record `status` (CPU load, cycle
time) and `tasks`.

## What a pass looks like

- Every build boots, keeps DShot600, bidir and `pid_process_denom = 1`, and shows normal tasks.
- Base: debug[0] and debug[7] above 0 when loops run late, so the spin occurs on this board.
- With a spin fix: debug[0] and debug[7] stay at 0, debug[5] does not increase against base, and
  debug[1] counts the deferred frames.
- debug[6] stays at 0 with the Opus and Fable fixes.
- With ESCs: RPM telemetry error rate (`dshot_telemetry_info`) is not worse than base.

## What was checked already

- Every combination builds for SPEEDYBEEF7V3 and GEPRCF722_BT_HD_V3.
- With the revision pinned, the switch builds give the same machine code as the benched patch
  branch and as each fix's own tree. All switches off gives the same code as master.
- Unit tests pass with the switches off, and in `.perf` variants with them on.
- SimITL: A2, C and D give byte-identical flight traces against master in a scripted flight and in
  a rough flight (gusts, punch-outs, flips), at thrust linear 0 and 25. Deliberate breaks change the
  trace, so the comparison can see a change.
- Board, SpeedyBee F7 V3 (BMI270, 3.2 kHz, no ESC): the loop fixes cut the PID loop by 12 %
  (5 rounds). All five builds in the table were flashed with the TEST flag. Each one booted,
  kept DShot600, bidir and `pid_process_denom = 1`, and ran at 316 us cycle time and 19-21 % CPU.
  With `DSHOT_TELEMETRY_COUNTS` over 300 samples, there were 0 reception timeouts in each build.
  The Fable fix deferred 3 frames. This board cannot show the spin, so this is only a check that
  nothing breaks.

The spin fixes have not been tested on an 8 kHz board. That is the test we ask for.
