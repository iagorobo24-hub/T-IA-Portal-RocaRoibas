# R17 — Aceptación conductual en PLCSIM Advanced

## Objetivo

Demostrar que un programa descargado en una CPU virtual responde a una secuencia de entradas,
salidas o tags simbólicas. Compilar y descargar no son evidencia conductual.

## Precondiciones

- TIA Portal V20 y el proyecto exacto están verificados.
- PLCSIM Advanced y `Siemens PLCSIM Virtual Ethernet Adapter` están operativos.
- El preflight tiene `plcToolchainReady`, `plcsimVirtualAdapterReady` y
  `tiaInstanceSafeForApply` a `true`.
- El destino se ha identificado como virtual y se ejecuta con `-AcknowledgeVirtualTarget`.
- El plan usa tags o direcciones leídas del proyecto; no se inventan offsets.
- Si el PLC es F-CPU, no se editan ni modifican bloques de safety.

## Proceso

Usa `Invoke-TiaSimulationAcceptance.ps1` con `-StartVirtualPlc` y `-IoPlanPath`. El runner:

1. arranca la instancia nativa persistente y exige `status: ready`;
2. abre el proyecto, descubre el árbol, compila y comprueba `CheckDownloadReadiness`;
3. verifica que la ruta de descarga contiene `PLCSIM`;
4. descarga conservando valores actuales;
5. ejecuta cada step del plan por stdin y exige `status: ok`;
6. registra respuestas, errores y limpieza de la instancia virtual.

## Formato del plan

```json
{
  "schemaVersion": 1,
  "name": "sorting-plant-minimum",
  "steps": [
    {
      "command": "write-bool-tag Control_HMI.fromHMI.resetSimulation 1",
      "expect": { "status": "ok", "op": "write-bool-tag" }
    },
    {
      "command": "read-bool-tag Control_HMI.toHMI.resetStatus",
      "expect": { "status": "ok", "op": "read-bool-tag" }
    }
  ]
}
```

Comandos disponibles:

- áreas: `read-bit`, `write-bit`, `read-byte`, `write-byte`, `read-area-size`;
- tags: `read-bool-tag`, `write-bool-tag`, `read-uint8-tag`, `write-uint8-tag`,
  `read-float-tag`, `write-float-tag`.

El ejemplo anterior solo demuestra comunicación. Para marcar comportamiento verificado, cada
caso debe declarar expectativas funcionales observables, por ejemplo que una salida se activa,
que un contador aumenta o que una condición de fallo genera el estado previsto. Si un step falla,
el informe no se considera evidencia válida.

## Evidencia

Conserva el informe `acceptance-latest.json` y crea un informe de aceptación con:

- versión de TIA y PLCSIM;
- nombre y tipo de CPU virtual;
- hash o ruta del plan ejecutado;
- respuestas de todos los steps;
- estado de limpieza `stopped`;
- resultado funcional por caso.

No escribas `status: verified` basándote solo en `CompileSoftware`, `DownloadToPlc` o
`GetOnlineState`.

## Si falla

- `select-interface`: activa el adaptador Siemens; no cambies a una NIC física.
- `CheckDownloadReadiness=false`: corrige la configuración del proyecto o la ruta, no reintentes
  la descarga.
- `NotReachable`/`Incompatible`: registra IP, firmware y ruta antes de cambiar nada.
- `read/write tag` falla: vuelve a leer los nombres simbólicos del proyecto y revisa la tabla de
  tags descargada; no sustituyas el símbolo por un offset supuesto.
- Si la limpieza no devuelve `stopped`, considera la aceptación incompleta y revisa instancias
  PLCSIM antes de repetir.
