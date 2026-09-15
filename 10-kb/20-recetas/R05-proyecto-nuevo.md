# R05 — Crear un proyecto nuevo desde cero

## Objetivo

Crear un proyecto V20 reproducible con un PLC y, opcionalmente, una HMI Unified sin inventar
MLFB, paths ni resolución de pantalla.

## Servidor y precondiciones

- `tia-create` en perfil `create` o `full`, con reconocimiento explícito.
- TIA Portal V20, licencia y grupo Openness verificados.
- Carpeta destino nueva o autorizada; no usar la carpeta de un proyecto de cliente.

## Secuencia segura

1. Ejecutar `Doctor` y `Connect`.
2. Resolver el hardware con `SearchHardwareCatalog`; no inventar `plcMlfb`.
3. Construir un `spec` con `projectName`, `directoryPath`, `plcName`, `plcFamily`, `plcMlfb` y,
   si procede, `hmiName`/`hmiFamily`.
4. Ejecutar `ScaffoldProject(spec, dryRun=true)` y revisar todos los pasos.
5. Solo con el resultado limpio y destino confirmado, ejecutar el mismo spec con `dryRun=false`.
6. Obtener `GetProjectTree`, usar las rutas reales, compilar PLC/HMI con 0 errores y 0 avisos,
   guardar y exportar a `src/`.

`ScaffoldProject` ya crea PLC, HMI Unified, UDTs, DBs, tablas de tags, fuentes SCL y pantallas
cuando están declarados en el spec. Para lógica con expresiones o `CASE`, usa ficheros `.scl`
externos; no intentes expresar esa lógica en el DSL reducido.

## Verificación

El informe debe contener el proyecto creado, el dispositivo, el árbol posterior, compilación 0/0,
guardado y exportación. Si falla un paso crítico, no se continúa con HMI ni se considera creado.
