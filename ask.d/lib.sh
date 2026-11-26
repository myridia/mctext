#!/bin/sh

ROOT=$(cd "$(dirname "$0")/.." && pwd)

enter() {
  cd "$ROOT" || exit 1
}
