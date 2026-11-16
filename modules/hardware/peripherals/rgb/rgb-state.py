"""rgb-state save|off|restore -- turn the lights off and back to how they were.

Used by server-mode. The lights are whatever was last set on each device, not
a saved profile, so `save` snapshots every device's mode and colours. It goes
through the OpenRGB service's SDK: the openrgb CLI can't save a profile from
the current state (it fails on the mouse's Static mode).
"""

import json
import os
import sys
from pathlib import Path

from openrgb import OpenRGBClient
from openrgb.utils import RGBColor

STATE = Path(os.environ["XDG_RUNTIME_DIR"]) / "rgb-state.json"


def rgb(colors):
    return [[c.red, c.green, c.blue] for c in colors or []]


def save(client):
    state = []
    for dev in client.devices:
        mode = dev.modes[dev.active_mode]
        state.append({
            "name": dev.name,
            "mode": mode.name,
            "brightness": mode.brightness,
            "speed": mode.speed,
            "mode_colors": rgb(mode.colors),
            "colors": rgb(dev.colors),
        })
    STATE.write_text(json.dumps(state))


def off(client):
    for dev in client.devices:
        mode = next((m for m in dev.modes if m.name == "Off"), None)
        if mode:
            dev.set_mode(mode)
        else:
            dev.set_color(RGBColor(0, 0, 0))


def restore(client):
    state = json.loads(STATE.read_text())
    # Devices come back in the order the service found them; the name check
    # skips any that moved rather than giving one another's colours.
    for dev, saved in zip(client.devices, state):
        if dev.name != saved["name"]:
            continue
        mode = next(m for m in dev.modes if m.name == saved["mode"])
        if saved["mode_colors"]:
            mode.colors = [RGBColor(*c) for c in saved["mode_colors"]]
        if saved["brightness"] is not None:
            mode.brightness = saved["brightness"]
        if saved["speed"] is not None:
            mode.speed = saved["speed"]
        dev.set_mode(mode)
        if saved["colors"]:
            dev.set_colors([RGBColor(*c) for c in saved["colors"]])
    STATE.unlink()


ACTIONS = {"save": save, "off": off, "restore": restore}

if len(sys.argv) != 2 or sys.argv[1] not in ACTIONS:
    sys.exit("usage: rgb-state save|off|restore")

ACTIONS[sys.argv[1]](OpenRGBClient(name="rgb-state"))
