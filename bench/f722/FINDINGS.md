# F722 bidir DShot600 bench: findings

Goal: get 8 kHz PID with bidirectional DShot600 back on STM32F722. #15779 now forces DShot300 and a PID rate of 4 kHz or less when bidir is on. The patches on branch `f722-bidir-perf` cut the loop cost. This folder has the bench scripts and the raw data.

**Small sample.** One board, one target, USB power, no ESC. The single-patch results are one run each. Master, release and all patches together are 3 interleaved rounds. Treat these numbers as a first signal, not as proof.

## Setup

| Item | Value |
|---|---|
| Board | SpeedyBee F7 V3 (SPEEDYBEEF7V3), STM32F722, BMI270 gyro at 3.2 kHz |
| Settings | `motor_pwm_protocol = DSHOT600`, `dshot_bidir = ON`, `pid_process_denom = 1` |
| Master | 4b7fa8e40, with the #15779 downgrade switched off for test (see the last commit on this branch) |
| Release | 2026.6.2 (e0b7bb01b), unmodified |
| Flash | DFU, mass erase before each build |
| Metric | GYRO + FILTER + PID task time per run, from `tasks` (total time / run count). Only the relative change is useful. |

## Loop time, 3 rounds

| Build | vs master: r1 / r2 / r3 | Mean | `tasks` Total |
|---|---|---|---|
| Master | 0 | 0 | 20.4% |
| Release 2026.6.2 | -2.1 / -1.4 / -2.1% | -1.9% | 19.9% |
| Master + A-E | -7.2 / -5.2 / -6.7% | -6.4% | 19.0% |
| Master, DEBUG_SET compiled out | -4.1 / -4.1 / -5.0% | -4.4% | 19.4% |

Master changed by 0.6% between rounds. Against the release, master + A-E is 4.6% faster.

## Each patch, one run each

| Patch | Change | Loop time | ITCM | Flash |
|---|---|---|---|---|
| A | Scheduler: skip the task-age division until a task is due | +0.1% (see note) | +8 B | +8 B |
| B | Position task signals alt-hold and pos-hold; no polling | -0.4% | 0 | 0 |
| C | Mixer: read failsafe once; skip thrust linearization at 0 | -0.3% | 0 | -16 B |
| D | Faster bitbang telemetry decoder | -1.9% | 0 | +76 B |
| E | Bitbang DShot hot path into ITCM, timer DShot out | -5.3% | +24 B | +24 B |

A, B and C are inside the noise. A saves scheduler time, and this metric does not count scheduler time. `fcsched.ps1` measures A on its own (not run yet). The single-patch gains do not add up exactly, because D and E speed up the same decoder.

The bench measurements used the first version of A. The branch has A2, which keeps the old task priority when the task age is a full period or more negative. On the host, A2 matches the old code in 1.3e9 cases with 0 mismatches.

## Behaviour checks in SimITL

C, D and A2 give bit-identical outputs to master in SimITL. The test flies a scripted flight with RC loss, failsafe landing and a simulated ESC with bidir telemetry. B was not tested in SimITL, because the SimITL fork is too old. E changes only where code is placed in memory. The decoder also matches the old one on a 2,209-frame corpus and on 20 M fuzzed buffers.

## Limits

- No ESC: the decoder had no telemetry frames, so D shows only its scan cost.
- Gyro at 3.2 kHz, not 8 kHz. The relative gains are what carry over.
- One board. Other F722 boards put the motors on 1 to 3 GPIO ports, and that changes the decoder load.

## Scripts (Windows PowerShell, board on COM3)

- `fccli.ps1`: send CLI commands. The first command must be `""`.
- `fcrun.ps1 -Variants a,b -Tag -r1`: flash each `bins\SPEEDYBEEF7V3-<name>.bin`, set the bench settings, save `status` and `tasks`.
- `parse_tasks.py <dir>`: loop time per run.
- `fcsched.ps1`, `mspdebug.ps1`, `sched_summary.py`: scheduler overhead from `debug[2]` over MSP. `sched_edit.py` makes the two test builds.
- dfu-util: set `DFU_UTIL` or put `dfu-util` on PATH.

Raw output is in `results/single`, `results/repeat` and `results/final`.

— Cyclistmass
