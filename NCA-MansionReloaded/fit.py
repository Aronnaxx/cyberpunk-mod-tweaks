import math, json
# (original 5437 workspot pos, Mansion Reloaded workspot pos)
PAIRS = {
    "bed":      ((-1337.7676, 1210.6230, 119.4551), (-2446.28, 103.50, 40.66)),
    "shower":   ((-1351.9000, 1212.1400, 120.2960), (-2445.19, 118.14, 40.63)),
    "wardrobe": ((-1342.2339, 1211.3936, 120.4111), (-2445.48, 108.34, 41.72)),
    "mirror":   ((-1350.9360, 1209.0520, 119.7690), (-2445.51, 110.61, 40.67)),
    "coffee":   ((-1334.2350, 1188.7240, 115.9510), (-2468.50,  99.83, 36.44)),
    "drink":    ((-1337.7020, 1192.5820, 115.8380), (-2465.46, 117.50, 36.66)),
    "guitar":   ((-1351.3369, 1210.4340, 115.7346), (-2453.65, 107.26, 36.33)),
    "couch_tv": ((-1341.7306, 1202.3192, 115.3507), (-2455.43, 107.08, 36.48)),
}

def fit(keys):
    A = [PAIRS[k][0] for k in keys]; B = [PAIRS[k][1] for k in keys]
    n = len(keys)
    ca = [sum(p[i] for p in A) / n for i in range(3)]; cb = [sum(p[i] for p in B) / n for i in range(3)]
    sxx = sxy = 0.0
    for a, b in zip(A, B):
        ax, ay = a[0] - ca[0], a[1] - ca[1]; bx, by = b[0] - cb[0], b[1] - cb[1]
        sxx += ax * bx + ay * by; sxy += ax * by - ay * bx
    th = math.atan2(sxy, sxx)
    c, s = math.cos(th), math.sin(th)
    tx = cb[0] - (c * ca[0] - s * ca[1]); ty = cb[1] - (s * ca[0] + c * ca[1]); tz = cb[2] - ca[2]
    return th, (tx, ty, tz)

def apply(T, p):
    th, (tx, ty, tz) = T; c, s = math.cos(th), math.sin(th)
    return (c * p[0] - s * p[1] + tx, s * p[0] + c * p[1] + ty, p[2] + tz)

keys = list(PAIRS)
T = fit(keys)
for it in range(3):  # drop outliers > 2 m and refit
    res = {k: math.dist(apply(T, PAIRS[k][0])[:2], PAIRS[k][1][:2]) for k in PAIRS}
    keep = [k for k in keys if res[k] < 2.0]
    if len(keep) >= 3 and keep != keys: keys = keep; T = fit(keys)
res = {k: (math.dist(apply(T, PAIRS[k][0])[:2], PAIRS[k][1][:2]), apply(T, PAIRS[k][0])[2] - PAIRS[k][1][2]) for k in PAIRS}
print(f"rotation {math.degrees(T[0]):.2f} deg, translation {tuple(round(v, 3) for v in T[1])}, fitted on {keys}")
for k, (dxy, dz) in sorted(res.items(), key=lambda kv: kv[1][0]):
    print(f"  {k:9} horiz err {dxy:5.2f} m   z err {dz:+.2f} m")
json.dump({"theta": T[0], "t": T[1], "fitKeys": keys}, open(__file__.replace("fit.py", "transform.json"), "w"))
