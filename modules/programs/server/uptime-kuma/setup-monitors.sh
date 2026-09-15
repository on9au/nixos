#!/bin/sh
# Runs setup-monitors.py in a throwaway container on the proxy network, which is
# how it reaches uptime-kuma by container name without publishing a port. Needs
# root, for the docker socket and the sops-rendered login.
set -eu
cd "$(dirname "$0")"
exec docker run --rm --network proxy \
  --env-file /run/secrets/rendered/uptime-kuma-admin.env \
  -v "$PWD/setup-monitors.py":/setup.py:ro \
  python:3.12-alpine \
  sh -c 'pip install --quiet uptime-kuma-api && python /setup.py'
