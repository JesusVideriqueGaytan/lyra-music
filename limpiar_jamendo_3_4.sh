#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
rm -f -- \
  lib/features/online/data/jamendo_service.dart \
  lib/features/online/presentation/online_controller.dart \
  test/online_track_test.dart \
  LEEME_LYRA_3_1.md \
  LEEME_LYRA_3_3_SIN_SPOTIFY.md
echo "Archivos obsoletos del proveedor retirados."
