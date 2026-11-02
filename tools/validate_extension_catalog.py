#!/usr/bin/env python3
"""Validación estática de catálogo; NO evalúa ni ejecuta código de extensiones."""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CATALOG = ROOT / 'assets/extensions/catalog.json'
KEYS = {'id', 'name', 'summary', 'author', 'version', 'category'}
CATEGORIES = {'appearance', 'metadata', 'integration', 'tools'}


def validate(data):
    if set(data.keys()) != {'schemaVersion', 'updatedAt', 'extensions'}:
        raise ValueError('Campos de catálogo no reconocidos')
    if data['schemaVersion'] != 1 or not isinstance(data['extensions'], list):
        raise ValueError('Esquema incompatible')
    seen = set()
    for entry in data['extensions']:
        if not isinstance(entry, dict) or set(entry.keys()) != KEYS:
            raise ValueError('Campos de extensión no reconocidos')
        for name, max_length in [('id', 64), ('name', 80), ('summary', 280),
                                 ('author', 80), ('version', 32), ('category', 32)]:
            val = entry[name]
            if not isinstance(val, str) or not val.strip() or len(val) > max_length:
                raise ValueError('Campo inválido: ' + name)
        if not re.fullmatch(r'[a-z0-9][a-z0-9._-]{2,63}', entry['id']):
            raise ValueError('ID inválido')
        if not re.fullmatch(r'\d+\.\d+\.\d+', entry['version']):
            raise ValueError('Versión inválida')
        if entry['category'] not in CATEGORIES or entry['id'] in seen:
            raise ValueError('Categoría inválida o ID repetido')
        seen.add(entry['id'])


if __name__ == '__main__':
    try:
        validate(json.loads(CATALOG.read_text(encoding='utf-8')))
    except (ValueError, TypeError, KeyError, json.JSONDecodeError) as exc:
        print('Catálogo inválido:', exc, file=sys.stderr)
        sys.exit(1)
    print('Catálogo correcto (metadatos únicamente, sin ejecución de código).')
