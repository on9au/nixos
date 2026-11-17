"""rgb-state save|off|restore -- turn the lights off and back to how they were.

Used by server-mode. The lights are whatever was last set on each device, not
a saved profile, so `save` snapshots every device's mode and colours. It goes
through the OpenRGB service's SDK: the openrgb CLI can't save a profile from
the current state (it fails on the mouse's Static mode).
"""

import json
import os
import socket
import struct
import sys
import time
from pathlib import Path

from openrgb import OpenRGBClient
from openrgb.utils import OpenRGBDisconnected, RGBColor

STATE = Path(os.environ["XDG_RUNTIME_DIR"]) / "rgb-state.json"


def connect():
    # openrgb-python stalls for its 10 s lock timeout when the server announces
    # a changed device list while it is still loading devices, as the server
    # does just after detection. A fresh connection gets through.
    for _ in range(4):
        try:
            return OpenRGBClient(name="rgb-state")
        except OpenRGBDisconnected:
            time.sleep(2)
    return OpenRGBClient(name="rgb-state")


def rgb(colors):
    return [[c.red, c.green, c.blue] for c in colors or []]


def save():
    client = connect()
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


def off():
    client = connect()
    for dev in client.devices:
        mode = next((m for m in dev.modes if m.name == "Off"), None)
        if mode:
            dev.set_mode(mode)
        else:
            dev.set_color(RGBColor(0, 0, 0))


def packet(sdk, kind, data=b""):
    sdk.sendall(b"ORGB" + struct.pack("<III", 0, kind, len(data)) + data)


def read_exactly(sdk, size):
    data = b""
    while len(data) < size:
        chunk = sdk.recv(size - len(data))
        if not chunk:
            raise ConnectionError("OpenRGB closed the connection")
        data += chunk
    return data


def rescan():
    # A device that was unplugged, like the keyboard and mouse on the monitors'
    # hub in server mode, is only found again by a rescan, and comes back
    # showing its own default lighting until set. The server takes no colour
    # changes until detection is done, and says so only to protocol 6 clients;
    # openrgb-python speaks 4 and has no rescan, so this is the raw SDK.
    with socket.create_connection(("127.0.0.1", 6742), timeout=60) as sdk:
        packet(sdk, 40, struct.pack("<I", 6))  # REQUEST_PROTOCOL_VERSION
        packet(sdk, 140)  # REQUEST_RESCAN_DEVICES
        while True:
            _, _, kind, size = struct.unpack("<4sIII", read_exactly(sdk, 16))
            read_exactly(sdk, size)
            if kind == 103:  # DETECTION_COMPLETE
                return


def restore():
    state = json.loads(STATE.read_text())
    rescan()
    client = connect()
    # By name, in order among devices of the same name: one that didn't come
    # back mustn't shift the others onto each other's colours.
    devices = {}
    for dev in client.devices:
        devices.setdefault(dev.name, []).append(dev)
    for saved in state:
        if not devices.get(saved["name"]):
            continue
        dev = devices[saved["name"]].pop(0)
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

ACTIONS[sys.argv[1]]()
