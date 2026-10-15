import sys
# Edit an A2-patched scheduler.c: report overhead in 0.1 us; for "base", restore the original
# time-driven branch so the only difference between the builds is A2's division skip.
path, mode = sys.argv[1], sys.argv[2]
t = open(path, encoding="utf-8").read()

old_dbg = ("DEBUG_SET(DEBUG_SCHEDULER, 2, clockCyclesToMicros(cmpTimeCycles(getCycleCounter(), "
           "schedulerStartCycles)) - taskExecutionTimeUs);")
new_dbg = ("DEBUG_SET(DEBUG_SCHEDULER, 2, clockCyclesTo10thMicros(cmpTimeCycles(getCycleCounter(), "
           "schedulerStartCycles)) - taskExecutionTimeUs * 10);  // TEST ONLY: 0.1 us")
assert t.count(old_dbg) == 1, "debug line"
t = t.replace(old_dbg, new_dbg)

if mode == "base":
    start = t.index("                    const timeDelta_t taskAgeUs = cmpTimeUs(")
    end_marker = "                    } else {\n                        task->taskAgePeriods = 0;\n                    }\n"
    end = t.index(end_marker, start) + len(end_marker)
    orig = ("                    task->taskAgePeriods = (cmpTimeUs(currentTimeUs, task->lastExecutedAtUs) / task->attribute->desiredPeriodUs);\n"
            "                    if (task->taskAgePeriods > 0) {\n"
            "                        task->dynamicPriority = 1 + task->attribute->staticPriority * task->taskAgePeriods;\n"
            "                    }\n")
    t = t[:start] + orig + t[end:]
elif mode != "A2":
    sys.exit("mode must be A2 or base")

open(path, "w", encoding="utf-8").write(t)
print("edited", mode)
