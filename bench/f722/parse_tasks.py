import re, sys, glob, os
# Per variant: CPU% (status), total load, and per-run time for GYRO/FILTER/PID from cumulative total / run count.
rows = []
for f in sorted(glob.glob(os.path.join(sys.argv[1], "*.txt")), key=os.path.getmtime):
    t = open(f, encoding="utf-8", errors="ignore").read()
    blocks = t.split("# tasks")[1:]
    if not blocks:
        continue
    res = {}
    for b in blocks[-1:]:  # second tasks read: fresh window after the first read reset the stats
        for name in ("GYRO", "FILTER", "PID"):
            m = re.search(r"\(\s*%s\)\s+(\d+)\s+(\d+)\s+(\d+)\s+[\d.]+%%\s+[\d.]+%%\s+(\d+)\s+(\d+)\s+(\d+)" % name, b)
            if m:
                total, runs = int(m.group(4)), int(m.group(6))
                res[name] = total / runs * 1000  # cumulative ms / runs -> us per run
        m = re.search(r"Total\s+([\d.]+)%", b)
        res["Total"] = float(m.group(1)) if m else None
    cpu = re.findall(r"CPU:(\d+)%", t)
    proto = re.search(r"motor_pwm_protocol = (\w+)", t)
    rows.append((os.path.basename(f)[:-4], proto.group(1) if proto else "?", res, cpu))
base = None
print(f"{'variant':16} {'proto':9} {'gyro':>6} {'filter':>7} {'pid':>7} {'sum us':>7} {'vs base':>8} {'total%':>7}")
for v, p, r, cpu in rows:
    s = sum(r.get(k, 0) for k in ("GYRO", "FILTER", "PID"))
    if v == "ungated-base":
        base = s
    d = f"{(s - base) / base * 100:+.1f}%" if base else ""
    print(f"{v:16} {p:9} {r.get('GYRO',0):6.2f} {r.get('FILTER',0):7.2f} {r.get('PID',0):7.2f} {s:7.2f} {d:>8} {r.get('Total')!s:>7}")
