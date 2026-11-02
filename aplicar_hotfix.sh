#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
python3 - <<'PY'
from pathlib import Path
changes = {
    'lib/features/player/presentation/screens/now_playing_screen.dart': [
        ("tooltip: 'Guardar audio autorizado en el dispositivo',\n", ''),
    ],
    'lib/app/router.dart': [
        ("import 'package:lyra_music/features/library/presentation/screens/my_music_screen.dart';\n", ''),
    ],
    'lib/features/ytmusic/data/ytmusic_client.dart': [
        ('artist: cleanedArtist!,', 'artist: cleanedArtist,'),
    ],
}
for name, replacements in changes.items():
    path = Path(name)
    if not path.is_file():
        raise SystemExit(f'ERROR: No se encontró {name}. Extrae el ZIP en la raíz del proyecto.')
    text = path.read_text(encoding='utf-8')
    for old, new in replacements:
        if old not in text:
            print(f'Sin cambios (ya corregido o código distinto): {name} — {old.strip()}')
            continue
        if text.count(old) != 1:
            raise SystemExit(f'ERROR: Se encontró más de una coincidencia en {name}: {old.strip()}')
        text = text.replace(old, new)
        print(f'Corregido: {name} — {old.strip()}')
    path.write_text(text, encoding='utf-8')
print('Parche aplicado. Ahora ejecuta: dart format lib test && dart fix --apply --code=curly_braces_in_flow_control_structures && flutter analyze && flutter test')
PY
