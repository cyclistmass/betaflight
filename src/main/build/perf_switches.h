/*
 * This file is part of Betaflight.
 *
 * Betaflight is free software. You can redistribute this software
 * and/or modify this software under the terms of the GNU General
 * Public License as published by the Free Software Foundation,
 * either version 3 of the License, or (at your option) any later
 * version.
 *
 * Betaflight is distributed in the hope that they will be
 * useful, but WITHOUT ANY WARRANTY; without even the implied
 * warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public
 * License along with this software.
 *
 * If not, see <http://www.gnu.org/licenses/>.
 */

#pragma once

// F722 bidir DShot600 performance switches (branch f722-bidir-switchable).
// Everything is off by default, so a plain build is master. Turn things on with
//   make CONFIG=<board> EXTRA_FLAGS="-D<switch> ..."
//
// Presets:
//   PERF_ALL      loop fixes and the spin fix
//   PERF_LOOP     loop fixes only: A2, B, D, E (C is left out: it only helps when
//                 thrust linear is off, so it hides the worst-case loop)
//   PERF_NOSPIN   spin fix only (lane 3 unless DSHOT_BB_NOSPIN is given)
//
// Single switches, usable alone or to add to a preset:
//   PERF_SCHED_TASK_AGE    A2  scheduler skips the task-age divide until a task is due
//   PERF_HOLD_TASK_SIGNAL  B   alt/pos hold signalled by the position task, not polled
//   PERF_MIXER             C   mixer: failsafe read once, thrust linear skipped at 0
//   PERF_BB_DECODE         D   faster bitbang telemetry decoder
//   PERF_BB_ITCM           E   bitbang DShot hot path in ITCM, timer DShot out
//   DSHOT_BB_NOSPIN=n      0 spin (master), 1 Opus, 2 GPT 5.6 Sol, 3 Fable
//   DSHOT_BB_NOSPIN_OPUS   same as DSHOT_BB_NOSPIN=1: busy check before the buffers are
//                          touched, output phase counted as busy, telemetryWait removed
//   DSHOT_BB_NOSPIN_SOL    same as DSHOT_BB_NOSPIN=2: frame-age guard in telemetryWait,
//                          stalled capture handed to reinit (reinitRequired)
//   DSHOT_BB_NOSPIN_FABLE  same as DSHOT_BB_NOSPIN=3: line busy if capture pending or
//                          output DMA still running, deferred frames counted in debug[4]
//   Give one of them: two at once is a build error.
//
// Taking one out of a preset: -DNO_PERF_SCHED_TASK_AGE, -DNO_PERF_HOLD_TASK_SIGNAL,
// -DNO_PERF_BB_DECODE, -DNO_PERF_BB_ITCM, or -DDSHOT_BB_NOSPIN=0 to keep the spin.
//
// Examples:
//   EXTRA_FLAGS="-DPERF_ALL"                          everything, Fable spin fix
//   EXTRA_FLAGS="-DPERF_ALL -DDSHOT_BB_NOSPIN_OPUS"   everything, Opus spin fix
//   EXTRA_FLAGS="-DDSHOT_BB_NOSPIN_SOL"               Sol spin fix only
//   EXTRA_FLAGS="-DPERF_LOOP -DNO_PERF_BB_ITCM"       loop fixes without the ITCM swap
//
// TEST ONLY: on F722, #15779 still forces DShot300 and PID <= 4 kHz with bidir on.
// Add -DTEST_UNGATE_PID_DENOM_CHECK to lift that for a bench test. Never release.

#ifdef PERF_ALL
#ifndef PERF_LOOP
#define PERF_LOOP
#endif
#ifndef PERF_NOSPIN
#define PERF_NOSPIN
#endif
#endif

#ifdef PERF_LOOP
#if !defined(PERF_SCHED_TASK_AGE) && !defined(NO_PERF_SCHED_TASK_AGE)
#define PERF_SCHED_TASK_AGE
#endif
#if !defined(PERF_HOLD_TASK_SIGNAL) && !defined(NO_PERF_HOLD_TASK_SIGNAL)
#define PERF_HOLD_TASK_SIGNAL
#endif
#if !defined(PERF_BB_DECODE) && !defined(NO_PERF_BB_DECODE)
#define PERF_BB_DECODE
#endif
#if !defined(PERF_BB_ITCM) && !defined(NO_PERF_BB_ITCM)
#define PERF_BB_ITCM
#endif
#endif

#if defined(DSHOT_BB_NOSPIN_OPUS) + defined(DSHOT_BB_NOSPIN_SOL) + defined(DSHOT_BB_NOSPIN_FABLE) > 1
#error "Give only one of DSHOT_BB_NOSPIN_OPUS, DSHOT_BB_NOSPIN_SOL, DSHOT_BB_NOSPIN_FABLE"
#endif
#if (defined(DSHOT_BB_NOSPIN_OPUS) || defined(DSHOT_BB_NOSPIN_SOL) || defined(DSHOT_BB_NOSPIN_FABLE)) && defined(DSHOT_BB_NOSPIN)
#error "Give either DSHOT_BB_NOSPIN=n or one DSHOT_BB_NOSPIN_<lane> switch, not both"
#endif
#if defined(DSHOT_BB_NOSPIN_OPUS)
#define DSHOT_BB_NOSPIN 1
#elif defined(DSHOT_BB_NOSPIN_SOL)
#define DSHOT_BB_NOSPIN 2
#elif defined(DSHOT_BB_NOSPIN_FABLE)
#define DSHOT_BB_NOSPIN 3
#endif

#if defined(PERF_NOSPIN) && !defined(DSHOT_BB_NOSPIN)
#define DSHOT_BB_NOSPIN 3  // Fable: also counts deferred frames in DSHOT_TELEMETRY_COUNTS debug[4]
#endif

#ifndef DSHOT_BB_NOSPIN
#define DSHOT_BB_NOSPIN 0
#endif

#if DSHOT_BB_NOSPIN < 0 || DSHOT_BB_NOSPIN > 3
#error "DSHOT_BB_NOSPIN must be 0 (spin, master), 1 (Opus), 2 (GPT 5.6 Sol) or 3 (Fable)"
#endif
