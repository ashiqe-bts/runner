#!/bin/sh
set -eu
project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
expected_revision=d3b14c876900e553bc736ca19295fc09e3853e8e
if [ ! -d "$project_dir/.toolchain/flutter" ]; then
  mkdir -p "$project_dir/.toolchain"
  if [ -x "$HOME/development/flutter-skyway-3.47.2/bin/flutter" ]; then
    ln -s "$HOME/development/flutter-skyway-3.47.2" "$project_dir/.toolchain/flutter"
  else
    git clone --depth 1 --branch 3.47.2 https://github.com/flutter/flutter.git "$project_dir/.toolchain/flutter"
  fi
fi
actual_revision=$(git -C "$project_dir/.toolchain/flutter" rev-parse HEAD)
if [ "$actual_revision" != "$expected_revision" ]; then
  echo "Unexpected Flutter revision $actual_revision. Expected 3.47.2 ($expected_revision)." >&2
  exit 1
fi
exec "$project_dir/.toolchain/flutter/bin/flutter" --version
