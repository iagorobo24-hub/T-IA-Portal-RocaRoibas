# ADR-017 — La simulación de HMI Unified exige el runtime de la misma versión que TIA

> Estado: **aceptado** · Fecha: **2026-10-22** · Ámbito: TIA Portal V20, WinCC Unified

## Contexto

Para probar una HMI Unified sin instalar nada se usó la simulación de TIA Portal
(`Start simulation` sobre el dispositivo HMI). El proyecto `DEMO-Cinta01` es de **TIA Portal V20**.

En esta máquina, el único runtime de WinCC Unified instalado es de la **V19**:

| Qué | Versión | Dónde |
|---|---|---|
| TIA Portal | **V20** | `C:\Program Files\Siemens\Automation\Portal V20` |
| `SIMATIC WinCC Unified PC V19` | **V19** | `C:\Program Files\Siemens\Automation\WinCCUnified` |
| `SIMATIC WinCC Unified Station Configurator V19.0 Upd3` | V19 | idem |
| `GfxRTS.exe` | `500.30.8901.3` | `…\WinCCUnified\bin` |

El proyecto HMI compilado genera un runtime de formato **20.0.0.0**:
`IM\HMI\I\AdditionalFiles\0_Chrom_20.0.0.0_Rdf_20.0.0.0`.

El resultado medido, con el PLC ya simulado y en línea:

```
10/22/2026 9:56:55 AM   ✗  Start downloading to device.
                               ✗  HM_RT_1
10/22/2026 9:57:21 AM      ✗  Online connection to HM_RT_1 failed.
10/22/2026 9:57:21 AM    ⚠  Action cancelled before download.
```

26 segundos de espera y cancelación. **No llega a lanzarse ningún proceso de runtime**: los únicos
`Siemens.Runtime.HmiUnified.*` del equipo (`Client.exe`, `ControlCenter.exe`) pertenecen al
*Unified Station Configurator* y llevan arrancados desde las 07:10:27, antes de toda la sesión.

## Decisión

**Se da por hecho que la simulación de una HMI Unified usa el WinCC Unified Runtime instalado y que
ese runtime tiene que ser de la misma versión mayor que el TIA Portal del proyecto.**

Consecuencias aceptadas:

1. **Con runtime V19, la simulación de una HMI de un proyecto V20 no funciona**, y el síntoma
   (timeout de 26 s con `Online connection to HM_RT_1 failed`) **no dice nada de la versión**.
   Es el síntoma más caro de este repo: se puede perder una hora creyendo que el problema es el PLC.
2. **Para verificar una HMI V20 hay que instalar `SIMATIC WinCC Unified PC V20`.** No lo instala el
   agente: lo descarga el usuario desde el Support Center de Siemens.
3. **La ausencia de licencia no es un bloqueo.** El runtime sin licencia funciona en modo no
   licenciado (aviso cada 10 minutos) y la simulación se activa **1 hora** sin licencia. No hace
   falta comprar nada para verificar.
4. **El lado PLC es independiente y sí se puede resolver** con lo instalado: S7-PLCSIM V20 viene con
   TIA V20 y con la propiedad *Support simulation during block compilation* activada. Ver
   [R31](../10-kb/20-recetas/R31-simulacion-plcsim-unified.md).

## Alternativas descartadas

- **Probar la HMI con TIA V19** (también instalado): obligaría a tener el proyecto en V19 y
  duplicaría el trabajo; no responde a la pregunta, que es sobre el proyecto V20.
- **Bajar el proyecto a V19 con TIA**: TIA V20 no permite convertir hacia abajo; y perdería la
  trazabilidad de PA-1.
- **Desplegar el HMI con el Unified Station Configurator V19**: es la misma versión del runtime,
  con el mismo problema.

## Cómo se comprueba esta ADR

```powershell
# La versión del runtime instalado
Get-ChildItem 'C:\Program Files\Siemens\Automation\WinCCUnified' -Recurse -Filter 'GfxRTS.exe' |
  ForEach-Object { $_.VersionInfo.ProductVersion }        # 500.30.8901.3  -> V19

# El formato de runtime que pide el proyecto
Get-ChildItem '<proyecto>\tia\<proyecto>\IM\HMI' -Recurse -Directory |
  Where-Object Name -match 'Rdf' | Select-Object -ExpandProperty Name   # ..._Rdf_20.0.0.0
```

Evidencia completa: [`50-examples/demo-cinta01/simulacion-unified-2026-10-22.json`](../../50-examples/demo-cinta01/simulacion-unified-2026-10-22.json).
