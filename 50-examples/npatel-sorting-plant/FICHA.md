# Sorting Plant — gemelo digital

- **Autor:** [npatel221](https://github.com/npatel221/PLC_Projects) · **Licencia:** ver repo original
- **TIA:** V16 → migrar a V20 · **Lenguaje:** LAD · **HMI:** WinCC RT Advanced
- **Proyecto:** `tia/Sorting Plant Control.ap16`

## Qué hace

Puesta en marcha virtual (*virtual commissioning*) de una planta clasificadora. El programa de
PLC y el HMI se desarrollan y prueban contra un **modelo mecatrónico 3D**, sin hardware.

La cadena completa:

```
PLC virtual (PLCSIM Advanced) <--> HMI simulado
            |
            v
   Modelo mecatrónico en NX MCD (el gemelo digital)
```

## Qué enseña

Esto es lo más interesante que hay en toda la colección desde el punto de vista de método:

- **Software-in-the-loop (SIL)** aplicado a PLC
- **Desarrollo dirigido por pruebas sobre PLC** — hay muy poco publicado sobre esto
- Interfaz entre PLC virtual, HMI simulado y modelo 3D vía PLCSIM Advanced
- Operación a velocidad constante y variable, y secuencia de reset

## Qué puedes ejecutar de esto

| Requisito | ¿Lo tienes? |
|---|---|
| TIA Portal | ✅ V20 |
| **PLCSIM Advanced** | ✅ **Sí — V6.0**, en `C:\Program Files (x86)\Siemens\Automation\PLCSIMADV` |
| WinCC RT Advanced (para el HMI) | ⚠️ Solo V17 HF8 instalado; el proyecto es V20 |
| **NX con opción MCD** | ❌ **No** |

Así que **sí puedes hacer software-in-the-loop**: PLC virtual en PLCSIM Advanced + HMI simulado,
que es el 80% del valor del ejercicio. Lo único que falta es el modelo 3D de NX, es decir, la
parte visual del gemelo digital.

> El proyecto usa PLCSIM Advanced **V3.0** y tú tienes **V6.0**. Debería funcionar, pero puede
> pedir reconfigurar la instancia virtual. Anótalo cuando lo pruebes.

### Preflight V20/PLCSIM verificado el 2026-09-15

El proyecto se adjuntó a la instancia de TIA ya abierta, sin cerrarla ni reemplazarla. Openness
V20 confirmó el software path exacto `Sorting Plant Controller`, compiló con **0 errores y 0
advertencias**, y `CheckDownloadReadiness` devolvió `Ready=true`. Este último resultado solo
confirma que existe una configuración de descarga; todavía no demuestra que la ruta apunte a una
CPU virtual de PLCSIM. Las dos rutas detectadas apuntan a la interfaz inalámbrica Realtek y a
`1 X1`/`1 X2`, por lo que no se debe ejecutar `DownloadToPlc` hasta crear/seleccionar
explícitamente la instancia virtual y confirmar la ruta PLCSIM.

La inspección de topología posterior sí confirmó que el dispositivo exacto es
`S71500/ET200MP station_1`, con `X1=192.168.0.1` en `PN/IE_1` y `X2=192.168.1.1` sin subnet
conectada. La evidencia completa está en
[`sorting-target-discovery-latest.json`](../../70-runs/simulation/sorting-target-discovery-latest.json).
La instancia temporal creada por la API nativa de PLCSIM V6.0 usa `Softbus`, no tiene IP antes de
la descarga y ha pasado un ciclo PowerOn/PowerOff limpio; esto verifica el runtime, pero todavía
no prueba el enlace de descarga TIA ni el comportamiento del programa.

## Lo más valioso: la documentación SCE

`docs/SCE-150-002-gemelo-digital-MCD.pdf` (2,2 MB) es material formativo **oficial de Siemens**
sobre gemelos digitales con MCD. Viene también el `.docx` editable. Esto solo ya justifica tener
la carpeta.

## Contenido

| | |
|---|---|
| `tia/` | Proyecto desempaquetado |
| `original-v16/` | `.zap16` intacto — **no tocar** |
| `nx-mcd/NX_MCD.zip` | Ficheros `.prt` del modelo 3D de NX |
| `docs/SCE-150-002-*.pdf` / `.docx` | Documentación oficial de Siemens |
| `docs/TIAPortalScreenshots.pdf` | 12 MB de capturas |

---

## Contenido real ✅ *migrado e inventariado el 2026-09-14*

**7 bloques, 37 tags en 2 tablas, 0 tipos, 0 inconsistentes.** Compila **0 errores, 0 advertencias**.

**Hardware** ✅ *verificado abriendo el proyecto en TIA V20*:

| | |
|---|---|
| PLC | `Sorting Plant Controller` — **CPU 1516F-3 PN/DP** |
| HMI | **TP900 Comfort** (`HMI_RT_5`) |

🔴 **Es una F-CPU.** La `GetPlcSummary` de la API **no lo dice**: devuelve 7 bloques y ninguna
mención a seguridad. Solo se ve abriendo el proyecto. Aquí **no hay programa de seguridad
activado** —no aparece el nodo *Safety Administration*— pero es justo el caso que obliga a
comprobar el modelo de CPU antes de escribir en un proyecto ajeno.

**HMI — 4 pantallas, y sobrevivieron intactas a la migración:**

```
Screens/
├── 10_Startscreen    sinóptico: cintas, contadores, sensores, simulación
├── 20_Messages
├── 30_Diagnostics
└── 40_Settings
```

La pantalla principal renderiza perfecta en V20: cabecera *Sorting Plant*, secciones
*Short/Long Conveyor* con botones Constant/Variable y consignas de velocidad, *Piece Count* con
tres contadores, *Light Sensors* con pilotos, *Simulation* con botón Reset y *Limit Switches*.

💡 **Y usa numeración por decenas en las pantallas** (`10_`, `20_`, `30_`, `40_`) — exactamente
la convención que propone [`estructura-proyecto.md`](../../20-standards/estructura-proyecto.md).
Es el único de los siete que lo hace.

```
Program blocks
├── Main                  [OB1, LAD]
├── ResetSimulation       [FC1, LAD]
├── Control_HMI           [DB1]
├── SortingPlantControl   [FB1, LAD]  ← coordinador
├── CylinderControl       [FB2, LAD]  ← dispositivo
├── ConveyorControl       [FB3, LAD]  ← dispositivo
└── SortingPlantControl_DB [DB2]
PLC tags
├── Default tag table     22 tags + 55 constantes de sistema
└── Sorting Plant Tags    15 tags
```

🥇 **El mejor estructurado de los siete.** Un FB coordinador más un FB por tipo de dispositivo, y
un DB dedicado al HMI. Es el patrón que propone
[`estructura-proyecto.md`](../../20-standards/estructura-proyecto.md), aunque sin agrupar en
carpetas.

Las tags están **bien comentadas** y con una convención de prefijos por origen físico
(`cs` sensor, `os` simulación de salida, `pc` cilindro de empuje):

```
csLightSensorCube_Detected    %I0.0   "1: cube workpiece detected by the light sensor"
pcCylinderHeadExtend_SetActive %Q0.3  "1: extend push cylinder"
```

### Lo que se encontró analizándolo

Este proyecto se usó para probar las recetas [R02](../../10-kb/20-recetas/R02-donde-se-usa.md) y
[R04](../../10-kb/20-recetas/R04-entender-un-bloque.md). Dos hallazgos reales:

🔴 **`CylinderControl` declara `"Limit Switch Not Extended"` como entrada y no la usa en ningún
network.** Parámetro muerto.

🔴 **En `Main` (líneas 19-20) las salidas de `ResetSimulation` van cruzadas:**
`pcCylinderHeadRetract_SetActive` se conecta a la tag `"...Extend..."` y al revés. Puede ser
deliberado —simula el proceso inverso— o un error de cableado. No está claro desde el código.

⚠️ Usa la `Default tag table` con 22 tags, el antipatrón de siempre.

---

## Estado

- [x] Desempaquetado y verificado
- [x] **Migrado a V20** por Openness
- [x] **Compilado:** 0 errores, 0 advertencias
- [x] **Inventariado** — 7 bloques, 37 tags
- [x] **Exportado a `src/`** — 7 `.s7dcl`, 5 `.s7res`, 2 `.xml`
- [x] Usado como banco de pruebas de R02 y R04
- [x] **Verificado visualmente en TIA V20**: bloques, LAD y las 4 pantallas HMI intactos
- [x] Confirmado que el `.s7dcl` exportado es **fiel al LAD gráfico**
- [ ] Software-in-the-loop con PLCSIM Advanced V6.0 — **prerequisitos presentes, comportamiento aún no demostrado**
- [ ] Plan candidato de reset HMI preparado en `acceptance/sorting-plant-reset.json`; aún no ejecutado
- [ ] ~~Modelo 3D en NX MCD~~ — **descartado**, no hay NX con opción MCD
