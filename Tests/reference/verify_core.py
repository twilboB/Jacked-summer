"""
Faithful line-for-line Python mirror of the Swift deterministic core
(Forecast.swift + Stats streak/day math), with executable test vectors.

Days are represented as integers (a day index), which stands in for
`Date.startOfDay`; dayCount(a,b) = b - a, addingDays = a + n. This is exactly
what the Swift helpers compute, so any algorithmic bug here is a bug in Swift.
"""
import math

KCAL_PER_KG = 7700.0

# ---- Forecast (mirror of Forecast.compute) --------------------------------
EMA_ALPHA = 0.3
TAU = 21.0
HIT_THRESHOLD = 0.15
FLAT_WEEKLY = 0.05
SLOW_DAYS_LIMIT = 900.0
RATE_FLOOR_PER_DAY = 0.0007
MAX_PROJECTION_DAYS = 3650.0

def _sign(x):
    return 1 if x > 0 else (-1 if x < 0 else 0)

def forecast(weights, goal, calorie_days_last21, tdee, today=0):
    """weights: list of (day:int, kg:float). Returns dict."""
    res = {"state": None, "trendWeightNow": 0.0, "weeklyRate": 0.0, "toGoal": 0.0,
           "centralDate": None, "soonerDate": None, "laterDate": None, "weeksAway": None,
           "deficitImpliedWeeklyRate": None, "deficit": None, "calorieAvg": None,
           "seB": None, "b": None}

    # 1
    if len(weights) < 2:
        res["state"] = "noData"
        res["trendWeightNow"] = weights[-1][1] if weights else 0.0
        return res

    s = sorted(weights, key=lambda p: p[0])
    first = s[0][0]

    # 2
    ts = [float(p[0] - first) for p in s]
    span = ts[-1]
    if not (span > 0):
        res["state"] = "noData"
        res["trendWeightNow"] = s[-1][1]
        return res

    # 3 EMA
    ema = s[0][1]
    for p in s[1:]:
        ema = EMA_ALPHA * p[1] + (1 - EMA_ALPHA) * ema
    trend_now = ema

    # 4 WLS
    ws = [math.exp(-(span - t) / TAU) for t in ts]
    ys = [p[1] for p in s]
    n = len(s)
    Sw = Swx = Swy = Swxx = Swxy = 0.0
    for i in range(n):
        w, x, y = ws[i], ts[i], ys[i]
        Sw += w; Swx += w * x; Swy += w * y; Swxx += w * x * x; Swxy += w * x * y
    denom = Sw * Swxx - Swx * Swx
    b = (Sw * Swxy - Swx * Swy) / denom if denom != 0 else 0.0
    a = (Swy - b * Swx) / Sw if Sw != 0 else trend_now

    # 5 seB
    wrss = 0.0
    for i in range(n):
        r = ys[i] - (a + b * ts[i])
        wrss += ws[i] * r * r
    sigma2 = wrss / (n - 2) if n > 2 else wrss
    varB = sigma2 * Sw / denom if denom != 0 else 0.0
    seB = math.sqrt(max(0.0, varB))

    weekly_rate = b * 7
    to_goal = trend_now - goal

    # 8 calorie cross-check
    if len(calorie_days_last21) >= 4:
        avg = sum(k for _, k in calorie_days_last21) / len(calorie_days_last21)
        res["calorieAvg"] = round(avg)
        d = tdee - avg
        res["deficit"] = round(d)
        res["deficitImpliedWeeklyRate"] = d * 7 / KCAL_PER_KG

    res["trendWeightNow"] = trend_now
    res["weeklyRate"] = weekly_rate
    res["toGoal"] = to_goal
    res["seB"] = seB
    res["b"] = b

    abs_slope = abs(b)
    flat = abs(weekly_rate) < FLAT_WEEKLY

    if abs(to_goal) < HIT_THRESHOLD:
        res["state"] = "hit"
        return res

    if flat or _sign(-b) != _sign(to_goal):
        res["state"] = "stalled"
        return res

    central_days = abs(to_goal) / abs_slope
    rate_hi = abs_slope + seB
    rate_lo = max(RATE_FLOOR_PER_DAY, abs_slope - seB)

    sooner_days = min(MAX_PROJECTION_DAYS, abs(to_goal) / rate_hi)
    later_days = min(MAX_PROJECTION_DAYS, abs(to_goal) / rate_lo)
    capped_central = min(MAX_PROJECTION_DAYS, central_days)

    res["centralDate"] = today + round(capped_central)
    res["soonerDate"] = today + round(sooner_days)
    res["laterDate"] = today + round(later_days)
    res["weeksAway"] = round(capped_central / 7)
    res["state"] = "slow" if central_days > SLOW_DAYS_LIMIT else "ok"
    return res

# ---- Streaks (mirror of Stats) --------------------------------------------
def current_streak(logged_days, today=0):
    if today in logged_days:
        cursor = today
    else:
        y = today - 1
        if y not in logged_days:
            return 0
        cursor = y
    count = 0
    while cursor in logged_days:
        count += 1
        cursor -= 1
    return count

def longest_streak(logged_days):
    if not logged_days:
        return 0
    s = sorted(logged_days)
    best = run = 1
    for i in range(1, len(s)):
        if s[i-1] + 1 == s[i]:
            run += 1
        else:
            run = 1
        best = max(best, run)
    return best

def last_seven(logged_days, today=0):
    return [ (today - off) in logged_days for off in range(6, -1, -1) ]

# =========================== TESTS ==========================================
FAILS = []
def check(name, got, expected, tol=None):
    ok = (abs(got - expected) <= tol) if tol is not None else (got == expected)
    print(f"[{'PASS' if ok else 'FAIL'}] {name}: got={got!r} expected={expected!r}" + (f" (tol {tol})" if tol else ""))
    if not ok:
        FAILS.append(name)

print("=== FORECAST ===")

# noData: <2 entries
check("noData_empty", forecast([], 82, [], 2800)["state"], "noData")
check("noData_one", forecast([(0,100.0)], 82, [], 2800)["state"], "noData")
# span 0: two entries same day
check("noData_sameDay", forecast([(5,100.0),(5,99.0)], 82, [], 2800)["state"], "noData")

# Perfect linear decline: w = 100 - 0.1*t, daily for 28 days. Goal 82 (below).
lin = [(t, 100.0 - 0.1*t) for t in range(0, 29)]
r = forecast(lin, 82.0, [], 2800, today=100)
check("linear_slope_b_perday", r["b"], -0.1, tol=1e-9)
check("linear_weeklyRate", r["weeklyRate"], -0.7, tol=1e-9)
check("linear_seB_zero", r["seB"], 0.0, tol=1e-9)
# trendNow via EMA of a linear series lags slightly above the last raw value (97.2)
print(f"      linear trendNow(EMA)={r['trendWeightNow']:.4f} (last raw=97.2, should be slightly >97.2)")
check("linear_state_ok", r["state"], "ok")
# central days = |trend-82| / 0.1  ; trend ~97.28 -> ~152.8 days -> weeksAway ~22
print(f"      linear toGoal={r['toGoal']:.4f} centralDate(day)={r['centralDate']} weeksAway={r['weeksAway']} window=({r['soonerDate']},{r['laterDate']})")
check("linear_window_symmetric_zero_seB", (r["soonerDate"], r["laterDate"]), (r["centralDate"], r["centralDate"]))

# Flat: constant weight -> stalled (flat)
flat = [(t, 90.0) for t in range(0, 15)]
rf = forecast(flat, 82.0, [], 2800, today=50)
check("flat_state_stalled", rf["state"], "stalled")
check("flat_weeklyRate_zero", rf["weeklyRate"], 0.0, tol=1e-9)

# Wrong direction: gaining (goal below current) -> stalled
up = [(t, 90.0 + 0.05*t) for t in range(0, 15)]
ru = forecast(up, 82.0, [], 2800, today=50)
check("wrongdir_state_stalled", ru["state"], "stalled")

# hit: trend within 0.15 of goal
hit = [(t, 82.05) for t in range(0,10)]  # flat AND at goal -> hit checked before stalled
# make it slightly moving so not flat but within threshold
hit2 = [(t, 82.10 - 0.001*t) for t in range(0,10)]
rh = forecast(hit2, 82.0, [], 2800, today=30)
check("hit_state", rh["state"], "hit")

# slow: slope non-flat (>0.05 kg/wk) but toGoal so large that centralDays > 900.
# slope -0.06/day (=-0.42 kg/wk, not flat); trend ~120 -> toGoal ~60 -> ~1000 days.
slow = [(t, 150.0 - 0.06*t) for t in range(0, 40)]
rs = forecast(slow, 82.0, [], 2800, today=200)
print(f"      slow b={rs['b']:.5f} weekly={rs['weeklyRate']:.3f} toGoal={rs['toGoal']:.3f} centralDaysApprox={abs(rs['toGoal']/rs['b']):.0f} state={rs['state']}")
check("slow_state", rs["state"], "slow")

# Boundary insight (NOT a bug): a very shallow slope below the flat threshold is
# classified 'stalled', never 'slow', because stalled is checked first.
shallow = [(t, 90.0 - 0.005*t) for t in range(0, 40)]
rsh = forecast(shallow, 82.0, [], 2800, today=200)
check("shallow_is_stalled_not_slow", rsh["state"], "stalled")

# calorie cross-check: >=4 days
cals4 = [(0,2300),(1,2400),(2,2200),(3,2500)]
rc = forecast(lin, 82.0, cals4, 2800, today=100)
check("cal_avg", rc["calorieAvg"], round((2300+2400+2200+2500)/4))
check("cal_deficit", rc["deficit"], round(2800 - (2300+2400+2200+2500)/4))
check("cal_impliedWeekly", rc["deficitImpliedWeeklyRate"], (2800 - 2350)*7/7700, tol=1e-9)
# <4 days -> None
rc3 = forecast(lin, 82.0, [(0,2300),(1,2400),(2,2200)], 2800, today=100)
check("cal_under4_none", rc3["deficitImpliedWeeklyRate"], None)

# window ordering with noise: sooner <= central <= later
noisy = [(0,100.0),(3,99.6),(6,99.9),(9,99.0),(12,98.8),(15,98.9),(18,98.2),(21,98.0)]
rn = forecast(noisy, 82.0, [], 2800, today=100)
print(f"      noisy b={rn['b']:.4f} seB={rn['seB']:.4f} state={rn['state']} sooner={rn['soonerDate']} central={rn['centralDate']} later={rn['laterDate']}")
if rn["state"] in ("ok","slow"):
    check("noisy_window_order", rn["soonerDate"] <= rn["centralDate"] <= rn["laterDate"], True)

print("\n=== STREAKS ===")
# current streak: today logged, 3 in a row
check("cur_today3", current_streak({10,9,8}, today=10), 3)
# today NOT logged but yesterday is -> counts from yesterday
check("cur_yesterday", current_streak({9,8,7}, today=10), 3)
# neither today nor yesterday -> 0
check("cur_zero", current_streak({7,6}, today=10), 0)
# gap breaks it
check("cur_gap", current_streak({10,9,7,6}, today=10), 2)
# empty
check("cur_empty", current_streak(set(), today=10), 0)

# longest streak
check("long_basic", longest_streak({1,2,3,10,11}), 3)
check("long_single", longest_streak({5}), 1)
check("long_empty", longest_streak(set()), 0)
check("long_all", longest_streak({1,2,3,4,5}), 5)
check("long_two_runs", longest_streak({1,2, 4,5,6,7, 9}), 4)

# last seven
check("last7_shape", last_seven({10,8,4}, today=10), [True,False,False,False,True,False,True])
check("last7_count", sum(last_seven({10,9,8,7,6,5,4}, today=10)), 7)

print("\n=== RESULT ===")
print("ALL PASS" if not FAILS else f"FAILURES: {FAILS}")
