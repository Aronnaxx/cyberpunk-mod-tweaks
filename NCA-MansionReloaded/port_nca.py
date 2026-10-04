"""Port a Night City Allies location module from the original Edgerunners Mansion (5437)
to V's Edgerunners Mansion Reloaded (26023) by applying the fitted rigid transform.

usage: python port_nca.py <in.reds> <out.reds>
"""
import json, math, os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
T = json.load(open(os.path.join(HERE, "transform.json")))
TH, (TX, TY, TZ) = T["theta"], T["t"]
C, S = math.cos(TH), math.sin(TH)
# yaw quaternion for the rotation about Z
QW, QZ = math.cos(TH / 2), math.sin(TH / 2)

NUM = r"(-?\d+(?:\.\d+)?(?:[eE][-+]?\d+)?)"
VEC = re.compile(rf"new Vector4\(\s*{NUM}\s*,\s*{NUM}\s*,\s*{NUM}\s*,\s*{NUM}\s*\)")
QUAT = re.compile(rf"new Quaternion\(\s*{NUM}\s*,\s*{NUM}\s*,\s*{NUM}\s*,\s*{NUM}\s*\)")

def xf_point(x, y, z):
    return C * x - S * y + TX, S * x + C * y + TY, z + TZ

def xf_quat(i, j, k, r):
    # q' = qyaw * q   (qyaw = (0, 0, QZ, QW))
    return (QW * i - QZ * j, QW * j + QZ * i, QW * k + QZ * r, QW * r - QZ * k)

def f(v): return f"{v:.7f}"

def port(src):
    stats = {"vec": 0, "quat": 0}
    def vrep(m):
        x, y, z, w = map(float, m.groups()); stats["vec"] += 1
        X, Y, Z = xf_point(x, y, z)
        return f"new Vector4({f(X)}, {f(Y)}, {f(Z)}, {f(w)})"
    def qrep(m):
        i, j, k, r = map(float, m.groups()); stats["quat"] += 1
        return "new Quaternion({}, {}, {}, {})".format(*map(f, xf_quat(i, j, k, r)))
    out = VEC.sub(vrep, src)
    out = QUAT.sub(qrep, out)
    # area-trigger radii are distances: unchanged by a rigid transform
    return out, stats

if __name__ == "__main__":
    src = open(sys.argv[1], encoding="utf-8").read()
    out, stats = port(src)
    open(sys.argv[2], "w", encoding="utf-8", newline="\n").write(out)
    print(stats)
