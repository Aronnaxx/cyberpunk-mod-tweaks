# Switch off Vehicle Selector Frontend traffic entries listed in a JSON file (sets their district mask to 0).
# Refuses to run while the game is open (VSF rewrites the file). Backs up user_settings.json first.
# Usage: vsf_disable.py <list.json>
import json, sys, shutil, subprocess, time

VSF = r"C:\Program Files (x86)\Steam\steamapps\common\Cyberpunk 2077\r6\storages\VehicleSelectorFrontend\user_settings.json"

if "Cyberpunk2077.exe" in subprocess.run(["tasklist", "/FI", "IMAGENAME eq Cyberpunk2077.exe"],
                                         capture_output=True, text=True).stdout:
    sys.exit("Cyberpunk is running - close it first.")

names = json.load(open(sys.argv[1]))
backup = VSF.replace(".json", ".backup-%s.json" % time.strftime("%Y%m%d-%H%M%S"))
shutil.copy2(VSF, backup)

data = json.load(open(VSF))
mv = data["moddedVehicles"]
changed = [n for n in names if mv.get(n)]
for n in changed:
    mv[n] = 0
json.dump(data, open(VSF, "w"), indent=2)
print("backup:", backup)
print("switched off:", len(changed), "of", len(names), "listed; still on:", sum(1 for v in mv.values() if v))
