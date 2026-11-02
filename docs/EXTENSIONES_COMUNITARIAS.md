# Lyra — propuesta de extensiones comunitarias (fase 2.7)

## Estado real en esta versión

- **Existe** sección Extensiones en escritorio y Android.
- **Existe** lectura de `assets/extensions/catalog.json`, un catálogo JSON **incluido con el código de la aplicación**.
- **Existe** validación estricta de metadatos de cada entrada y una prueba de esquema.
- **NO existe** una tienda remota, cuentas de desarrollador, descarga e instalación desde la app ni ejecución dinámica de código externo.
- **NO se han aprobado plugins**: el catálogo comienza vacío de forma deliberada.

## ¿Necesitamos servidor?

**No al principio.** Un repositorio público de GitHub y un catálogo versionado (por ejemplo, publicado estáticamente mediante GitHub Pages o entregado dentro de los lanzamientos) puede servir como backend de *distribución de metadatos* y proceso de moderación:

1. Colaborador propone manifiesto y código fuente en un Pull Request.
2. CI valida sintaxis, esquema y enlaces permitidos, además de ejecutar análisis y pruebas.
3. Mantenedores revisan código, permisos, seguridad, licencia, compatibilidad y dependencias.
4. Tras aprobación, la nueva entrada se incorpora al catálogo. El catálogo se distribuye en una nueva versión de Lyra.
5. Si posteriormente se habilita instalación remota, verificar siempre un hash criptográfico y firma de artefacto, compatibilidad y permisos. Evitar carga de código nativo no confiable.

Configurar en GitHub **protección de `main`**, revisiones obligatorias, CODEOWNERS reales, checks CI y revisión de últimos cambios. Los archivos de este ZIP NO activan por sí solos esas políticas en la cuenta de GitHub.

### Cuándo sí usar un servidor propio

Solo cuando se necesiten registro/inicio de sesión de desarrolladores, envío de archivos desde la app, cola administrativa y trazabilidad de aprobaciones, estadísticas, comentarios y actualizaciones sin publicar nueva versión. Con tráfico inicial bajo, alternativas gestionadas (GitHub, almacenamiento estático, funciones serverless) son suficientes.

## Restricción de seguridad

**Un manifiesto JSON aprobado no hace seguro un ejecutable.** Flutter en release/AOT y los sistemas móviles no proporcionan un cargador universal de paquetes Dart independientes. Los isolates no son una frontera de seguridad para ejecutar código de personas desconocidas. Diseñar una **API de extensiones declarativa** (temas, metadatos o reglas seguras) como primera etapa, y evaluar procesos aislados/capacidades limitadas en escritorio para extensiones ejecutables. Android/iOS requerirán mecanismos nativos compatibles con las políticas aplicables.

No permitir a un plugin acceso arbitrario a archivos, tokens de servicios, procesos, audio ni red. Los permisos se concederían explícitamente y podrían revocarse. Revisar la compatibilidad de licencias con GPLv3 de Lyra.

## Ejemplo de manifest de propuesta

Ver `community/extensions/EJEMPLO_MANIFEST.json` (solo documentación, **no aprobado**). Los campos permitidos inicialmente son `id`, `name`, `summary`, `author`, `version`, `category`.

Categorías: `appearance`, `metadata`, `integration`, `tools`. No se permite definir código ejecutable, comandos, scripts, URLs de descarga o permisos dentro de este catálogo de fase 2.7.

## Próximos hitos

- Fase 2.7: catálogo de solo lectura y propuesta por PR.
- Fase 2.8+: gestor de extensiones declarativas con revisión adicional, firma de actualizaciones y permisos.
- Futuro: protocolo de extensiones ejecutables aisladas donde el sistema lo permita, tras auditoría de seguridad.
