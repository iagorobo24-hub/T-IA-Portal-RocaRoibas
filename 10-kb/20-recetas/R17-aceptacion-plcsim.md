# R17 — Aceptación conductual en PLCSIM Advanced

## Objetivo y alcance

Demostrar que un programa descarga a una instancia PLCSIM virtual y responde a un plan
especificado de entradas y observaciones. Compilar, descargar o ver `Online` no prueba por sí solo
el comportamiento del PLC.

Esta receta cubre solo la ruta PLC. Runtime HMI tiene su propio preflight por modelo. No se usa una
NIC física como sustituto si la instancia virtual no está disponible. Si el PLC es una F-CPU, no se
editan F-blocks ni tags de Safety.

## Herramientas y precondiciones

- TIA Portal V20 y el proyecto desechable exacto están verificados.
- El preflight de `Write-TiaSimulationReadiness.ps1` tiene los gates PLC
  `plcToolchainReady`, `plcsimVirtualAdapterReady` y `tiaInstanceSafeForApply` como JSON booleanos
  `true`. Los bloqueos agregados de Runtime HMI o de comportamiento PLC pendiente se registran,
  pero no son gates PLC.
- La raíz de la fixture tiene `.tia-agent-fixture.json` con la ruta exacta del `.ap20` y backup.
- Se obtuvo `DevicePath` y `SoftwarePath` de `GetProjectTree` y `GetSoftwareTree` en esa sesión.
- Se leyó la IP configurada con `GetDeviceIpAddress` para el `DevicePath` exacto. En `tia-create
  lite`, buscar primero con `FindTools` y ejecutar con `CallTool`; el runner full llama la herramienta
  directamente. La IP de `GetDeviceIpAddress`, la de PLCSIM `status: ready` y la dirección objetivo
  del runner deben coincidir.
- PLCSIM Advanced crea y mantiene una instancia virtual desechable. Su identidad confirma la
  interfaz `Siemens PLCSIM Virtual Ethernet Adapter`; estar `Up` en Windows no prueba que la CPU
  esté registrada, enlazada o sea accesible.
- Se reconoce explícitamente `-AcknowledgeVirtualTarget`. El runner exige que se gestione la
  instancia con `-StartVirtualPlc`; no acepta un target externo sin identidad leída por el runner.
- El plan existe, es JSON válido con `schemaVersion=1`, tiene pasos conocidos por el adaptador y
  cada operación de lectura comprueba un valor funcional además de `status`/`op`. El plan se
  valida antes de iniciar PLCSIM o llamar a `DownloadToPlc`.
- Toda observación simbólica del plan debe apuntar a un tag de salida confirmado por la tabla de
  tags/logic exportada del proyecto. El runner compara el valor que devuelve PLCSIM; no deduce por
  sí solo la dirección funcional de un tag.

## Secuencia

Ejecuta la secuencia MCP con `Invoke-McpToolSequence.ps1`, que adquiere el lease compartido:

1. Ejecuta `Doctor` en `tia-inspect` read. Si falla, para.
2. Con el proyecto desechable identificado, conecta y lo abre sin cerrar proyectos ajenos.
3. Lee `GetProjectTree` y `GetSoftwareTree`; copia sus rutas exactas al comando.
4. Lee la IP de `GetDeviceIpAddress` para el dispositivo del proyecto.
5. Valida el plan de E/S; el runner lo hace antes de iniciar una instancia.
6. El runner inicia PLCSIM y exige `status: ready`, IP exacta e identidad de interfaz esperada.
7. Exige `CompileSoftware` con `Success`, 0 errores y 0 avisos; comprueba que
   `CheckDownloadReadiness` devuelve `Ready=true` e `IsConsistent=true`; exige exactamente una ruta
   cuyo nombre completo coincida con el adaptador virtual. Si la ruta incluye IP, también debe
   coincidir.
8. Descarga solo al destino virtual confirmado, pasando el nombre completo de la ruta seleccionada
   y la IP configurada del dispositivo.
9. Ejecuta el plan y compara todas las expectativas. Solo después registra `status=VERIFIED`.
10. Detiene y desregistra la instancia; la limpieza debe confirmar `status: stopped`.

Ejemplo de invocación con valores que deben leerse del proyecto y del preflight:

```powershell
.\30-tools\scripts\Invoke-TiaSimulationAcceptance.ps1 `
  -ProjectFile '<fixture .ap20 exacto>' `
  -ProjectName '<nombre leído del proyecto>' `
  -DevicePath '<ruta leída de GetProjectTree>' `
  -SoftwarePath '<ruta leída de GetSoftwareTree>' `
  -TargetIpAddress '<IP leída con GetDeviceIpAddress>' `
  -IoPlanPath '<plan revisado>' `
  -StartVirtualPlc -AcknowledgeVirtualTarget -Run
```

## Forma del plan

Usa tags y direcciones leídas del proyecto. Define los valores esperados según la especificación
funcional y los interlocks del proceso; el ejemplo es una plantilla, no una receta de señales:

```json
{
  "schemaVersion": 1,
  "name": "<nombre-del-caso>",
  "steps": [
    {
      "command": "write-bool-tag <tag-de-entrada-leido> 1",
      "expect": { "status": "ok", "op": "write-bool-tag" }
    },
    {
      "command": "read-bool-tag <tag-de-salida-leido>",
      "expect": { "status": "ok", "op": "read-bool-tag", "value": true },
      "delayMs": 250
    }
  ]
}
```

El step de lectura tiene que comprobar el resultado funcional de una salida o tag simbólico de
salida. Leer el tamaño de un área o hacer eco de la entrada no demuestra respuesta del programa. Un
plan que solo espera `status` y `op` demuestra transporte, no comportamiento, y se bloquea antes de
descargar. Los comandos permitidos incluyen lectura y escritura de bits/bytes,
tags bool/uint8/float y tamaño de área, según `30-tools/plcsim/README.md`.

## Evidencia y condiciones de parada

Conserva `acceptance-latest.json`, el plan y su SHA-256, versión de TIA/PLCSIM, nombre y tipo de
CPU virtual, IP de proyecto, instancia, interfaz, ruta seleccionada, respuestas de todos los pasos
y el resultado de limpieza. Distingue claramente:

- compilación offline;
- conexión y disponibilidad del target;
- descarga a PLCSIM;
- comportamiento observado mediante expectativas;
- validación de Runtime HMI;
- puesta en servicio física.

No marques comportamiento como verificado por `CompileSoftware`, `DownloadToPlc` o
`GetOnlineState` solamente. Si falta una ruta única, una IP coincidente o identidad virtual, para
antes de descargar. Si `CheckDownloadReadiness=false`, registra el mensaje exacto y corrige la
configuración; no repitas sin cambio. `NotReachable`/`Incompatible` requiere registrar IP, firmware
y ruta antes de modificar nada. Si un tag no aparece, vuelve a leer los tags del proyecto, no
sustituyas el símbolo por un offset supuesto. Si la limpieza no confirma `stopped`, la aceptación
queda incompleta.
