# Lyra — Fase 2.7 (primer incremento visual y comunidad)

## Cambios reales

- La biblioteca ahora organiza por Canciones, Álbumes, Artistas y Carpetas, con búsqueda y filtros existentes y selección de un grupo para reproducir canciones.
- Se incorporó una cabecera de colección, un listado de canciones con mejor jerarquía visual y una vista en cuadrícula de grupos.
- El reproductor tiene distribución en dos columnas en escritorio y desplazamiento vertical seguro en móvil.
- El mini reproductor ya **no se superpone** a las pantallas; se sitúa dentro del layout general, con control Anterior adicional.
- Compatibilidad de portadas externas adyacentes: `cover.jpg`, `folder.jpg`, `front.jpg`, `cover.png`, `folder.png`, reutilizadas en biblioteca y reproductor. Aún no se extraen portadas embebidas en ID3/APIC.
- La navegación de escritorio incluye Extensiones. En móvil aparece una navegación inferior adaptable.
- Hay una sección Extensiones y un catálogo local vacío cuya sintaxis se comprueba, con una guía de revisión de propuestas de la comunidad.
- Se conserva la integración MPRIS/audio_service de la revisión 2.6.1.

## Estado y límites

- Este entorno no tiene Flutter/Dart; **los cambios no se han compilado ni ejecutado aquí**. Deberás validar `flutter analyze`, `flutter test` y `flutter run -d linux`.
- El escáner aún infiere artista/título del nombre de archivo. Es frecuente que casi todo aparezca en “Álbum desconocido”. Una próxima revisión implementará lectura de metadatos y portadas embebidas.
- Las secciones de Extensiones muestran **solo información de catálogo**. No se instala ni ejecuta código de terceros.
- El repositorio público y la protección de ramas deben configurarse en GitHub por los mantenedores; el ZIP no crea un servidor ni publica nada.

## Instalar sin perder tus cambios

**Recomendación:** conserva el estado anterior en una rama y aplica este ZIP como una actualización controlada. No sobrescribas los archivos de datos que tengas en `~/.local/share` ni elimines los archivos de tu biblioteca. El código no borra carpetas ni colecciones.

```bash
cd ~/Lyra-GitHub
git status
git switch -c fase-2-7-ui
# Extrae los archivos del ZIP dentro del proyecto,
# respetando su carpeta raíz `lyra-music-main/`.
flutter clean
flutter pub get
dart format lib test
flutter analyze
flutter test
flutter run -d linux
```

Si ya tienes cambios sin confirmar, guárdalos primero con un commit o `git stash`. **No uses `git reset --hard`**.

## Validación de plugins

```bash
python tools/validate_extension_catalog.py
```

Consulta `docs/EXTENSIONES_COMUNITARIAS.md` para diseño y moderación.
