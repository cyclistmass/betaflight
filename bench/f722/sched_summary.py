import csv, glob, os, re, statistics, sys
# Per run: mean and median of debug[2] (scheduler overhead per pass, 0.1 us), plus settings check.
d = sys.argv[1]
res = {}
for f in sorted(glob.glob(os.path.join(d, "*.csv"))):
    tag = os.path.basename(f)[:-4]
    vals = [int(r[2]) for r in csv.reader(open(f)) if len(r) > 2]
    txt = open(f[:-4] + ".txt", encoding="utf-8", errors="ignore").read() if os.path.exists(f[:-4] + ".txt") else ""
    ok = all(s in txt for s in ("DSHOT600", "dshot_bidir = ON", "pid_process_denom = 1", "debug_mode = SCHEDULER"))
    v, r = tag.rsplit("-r", 1)
    if not vals:
        print(f"{tag:16} no samples"); continue
    res.setdefault(v, {})[r] = (statistics.mean(vals) / 10, statistics.median(vals) / 10, len(vals), ok)
    print(f"{tag:16} n={len(vals):5} mean={statistics.mean(vals)/10:7.2f} us  median={statistics.median(vals)/10:6.1f} us  "
          f"p10={sorted(vals)[len(vals)//10]/10:6.1f}  p90={sorted(vals)[len(vals)*9//10]/10:6.1f}  settings_ok={ok}")
if "sched-base" in res and "sched-A2" in res:
    print()
    for r in sorted(set(res["sched-base"]) & set(res["sched-A2"])):
        b, a = res["sched-base"][r][0], res["sched-A2"][r][0]
        bm, am = res["sched-base"][r][1], res["sched-A2"][r][1]
        print(f"round {r}: mean base {b:.2f} A2 {a:.2f} us ({(a-b)/b*100:+.1f}%), median base {bm:.1f} A2 {am:.1f}")
    mb = statistics.mean(x[0] for x in res["sched-base"].values())
    ma = statistics.mean(x[0] for x in res["sched-A2"].values())
    print(f"all rounds: base {mb:.2f} us, A2 {ma:.2f} us, change {(ma-mb)/mb*100:+.1f}%")
