#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

# Enforce no TinyReactor global access in runtime Lua code.
pattern='_G\.Tiny'"Reactor"
if rg -n "$pattern" App Domain Infrastructure Libs --glob '*.lua' >/dev/null; then
  echo "Found forbidden global TinyReactor usage:"
  rg -n "$pattern" App Domain Infrastructure Libs --glob '*.lua'
  exit 1
fi

echo "OK: no TinyReactor global usage found."
