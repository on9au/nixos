#!/bin/sh
# Runs setup-monitors.py in a throwaway container on the proxy network, which is
# how it reaches uptime-kuma by container name without publishing a port. Needs
# root, for the docker socket and the sops-rendered login. uptime-kuma-api
# hasn't changed since 2023; with python-socketio 5.17 / python-engineio 4.14
# the login call never gets an answer, hence the pins.
set -eu
cd "$(dirname "$0")"
exec docker run --rm --network proxy \
  --env-file /run/secrets/rendered/uptime-kuma-admin.env \
  -v "$PWD/setup-monitors.py":/setup.py:ro \
  python:3.12-alpine \
  sh -c 'pip install --quiet uptime-kuma-api "python-socketio<5.17" "python-engineio<4.14" && python /setup.py'
