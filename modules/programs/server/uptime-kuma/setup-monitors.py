"""Create the homelab's Uptime Kuma monitors.

Idempotent: monitors are matched by name, so re-running edits rather than
duplicates. Credentials come from the sops-rendered admin env file so they never
appear in a command line or shell history.

Run with:  sudo ./setup-monitors.sh
"""
import os
from uptime_kuma_api import UptimeKumaApi, MonitorType

MONITORS = [
    # Public entry points, checked the way a user hits them -- through Caddy and
    # Cloudflare, so a cert or proxy failure shows up too.
    dict(type=MonitorType.HTTP, name="forgejo (git)", url="https://git.opena0.net"),
    dict(type=MonitorType.HTTP, name="kanidm (idm)", url="https://idm.opena0.net"),
    dict(type=MonitorType.HTTP, name="cinny (chat)", url="https://chat.opena0.net"),

    # Keyword rather than status code: tuwunel can return 200 while being
    # useless, and this is the endpoint every Matrix client calls first.
    dict(type=MonitorType.KEYWORD, name="tuwunel (matrix API)",
         url="https://matrix.opena0.net/_matrix/client/versions", keyword="versions"),

    # Delegation lives on a Cloudflare Worker, not on jia -- it can break on its
    # own and would silently orphan every Matrix client.
    dict(type=MonitorType.KEYWORD, name="matrix delegation (.well-known)",
         url="https://opena0.net/.well-known/matrix/client", keyword="matrix.opena0.net"),

    # Game traffic never goes through Caddy. terraria is not on the proxy
    # network, so it is checked via the host's published port instead -- which
    # is the path players actually take. Not the LAN IP: that has renumbered before.
    dict(type=MonitorType.PORT, name="terraria (tshock)",
         hostname="host.docker.internal", port=7777),

    # Beszel: the hub through Caddy, and the agent as a raw port. The agent runs
    # on the host, not in a container, so from in here it is reachable via
    # host.docker.internal -- the same path the hub itself uses to scrape it.
    dict(type=MonitorType.HTTP, name="beszel (metrics)", url="https://metrics.opena0.net"),
    dict(type=MonitorType.PORT, name="beszel agent (host)",
         hostname="host.docker.internal", port=45876),
]

# The bridges expose no public surface, so they are checked on the appservice
# port by container name. /_matrix/mau/ready is stricter than /live: it also
# fails when the process is up but not talking to the homeserver. Worth having
# -- these crash-looped silently on their first deploy and nothing noticed.
for _name, _port in [
    ("telegram", 29317), ("whatsapp", 29318), ("discord", 29334),
    ("gmessages", 29336), ("messenger", 29321), ("instagram", 29322),
]:
    MONITORS.append(dict(
        type=MonitorType.HTTP,
        name=f"bridge: {_name}",
        url=f"http://mautrix-{_name}:{_port}/_matrix/mau/ready",
    ))

DEFAULTS = dict(interval=60, retryInterval=60, maxretries=2)

# uptime-kuma-api is older than this hub: the hub's schema has NOT NULL on
# monitor.conditions, but the library neither sends that column nor accepts it
# as a kwarg, so add_monitor dies with a raw SQLITE_CONSTRAINT error. Inject a
# default at the point where the payload is built. Editing existing monitors is
# unaffected, which is why only new ones failed.
_build = UptimeKumaApi._build_monitor_data
def _build_with_conditions(self, **kwargs):
    data = _build(self, **kwargs)
    data.setdefault("conditions", [])
    return data
UptimeKumaApi._build_monitor_data = _build_with_conditions

api = UptimeKumaApi("http://uptime-kuma:3001")
api.login(os.environ["KUMA_USERNAME"], os.environ["KUMA_PASSWORD"])

existing = {m["name"]: m["id"] for m in api.get_monitors()}
for spec in MONITORS:
    args = {**DEFAULTS, **spec}
    name = args["name"]
    if name in existing:
        api.edit_monitor(existing[name], **args)
        print(f"updated  {name}")
    else:
        api.add_monitor(**args)
        print(f"created  {name}")

print("\n--- current monitors ---")
for m in api.get_monitors():
    print(f"{m['id']:>3}  {m['name']:<32} {m['type']:<8} active={m['active']}")
api.disconnect()
