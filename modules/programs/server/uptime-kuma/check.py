import os
from uptime_kuma_api import UptimeKumaApi
api = UptimeKumaApi("http://uptime-kuma:3001")
api.login(os.environ["KUMA_USERNAME"], os.environ["KUMA_PASSWORD"])
names = {m["id"]: m["name"] for m in api.get_monitors()}
hb = api.get_heartbeats()
for mid, name in sorted(names.items()):
    beats = hb.get(mid) or []
    if not beats:
        print(f"{name:<32} (no beat yet)"); continue
    b = beats[-1]
    state = {0: "DOWN", 1: "UP", 2: "PENDING", 3: "MAINTENANCE"}.get(b.get("status"), b.get("status"))
    print(f"{name:<32} {state:<8} {str(b.get('ping') or '-'):>5}ms  {str(b.get('msg',''))[:44]}")
api.disconnect()
