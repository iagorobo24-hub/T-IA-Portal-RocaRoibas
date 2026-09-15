# Basement Light Control

- **Autor:** [npatel221](https://github.com/npatel221/PLC_Projects) · **Licencia:** ver repo original
- **Origen:** TIA V16 · **Migrado a V20** ✅ · **HMI:** WinCC RT Advanced · **Sim:** PLCSIM
- **Proyecto migrado:** `BasementLightControl_V20/BasementLightControl_V20.ap20`

## Qué hace

Control de la luz de un sótano con **dos conmutadores de tres vías**, uno arriba y otro abajo.
Cualquiera de los dos enciende o apaga la luz, independientemente de lo que haya hecho el otro.
El clásico conmutado de escalera.

La lógica es un **XOR**: la luz se enciende cuando los conmutadores están en posiciones
**distintas**.

| Conmutador superior | Conmutador inferior | Luz |
|:---:|:---:|:---:|
| OFF | OFF | OFF |
| OFF | ON | **ON** |
| ON | OFF | **ON** |
| ON | ON | OFF |

> ⚠️ **Errata del autor:** su tabla de verdad repite la fila `OFF | ON` y omite `ON | OFF`.
> La de arriba es la correcta.

---

## Contenido real ✅ *inventariado por Openness el 2026-09-14*

**Hardware:** estación **S7-1200**, `PLC_1`, con AI 2, DI 6/DQ 4, interfaz PROFINET,
6 HSC, 4 salidas de impulsos y servidor OPC UA.

**Programa:** 4 bloques, **0 inconsistentes**, **0 know-how protegidos**.

```
PLC_1 [PLC Software]
├── Program blocks
│   ├── Main              [OB1, LAD]
│   ├── HMI_Inteface      [DB1, DB]     ← sic, el typo es del autor
│   ├── lightControl      [FB1, LAD]
│   └── lightControl_DB   [DB2, DB]
└── PLC data types        (vacío)
```

| Métrica | Valor |
|---|---|
| Bloques | 4 — 1 OB, 1 FB, 1 DB global, 1 DB de instancia |
| Lenguajes | LAD ×2, DB ×2 |
| Tipos de datos PLC | 0 |
| Tablas de tags | 1 |
| Tags | **0** ⚠️ |
| Tablas de observación | 0 |

⚠️ **`tagCount: 0` con 1 tabla de tags.** O el programa direcciona absoluto (`%I0.0`, `%Q0.0`)
sin símbolos, o el contador solo mira la tabla por defecto. Merece mirarlo: si es lo primero, es
un buen ejemplo de **lo que NO hay que hacer** según
[`20-standards/naming.md`](../../20-standards/naming.md).

### Lecturas de este inventario

- **Arquitectura correcta pese a lo pequeño**: la lógica vive en un FB reutilizable
  (`lightControl`) con su DB de instancia, no suelta en OB1. Eso está bien hecho.
- **`HMI_Inteface`** es un DB global de interfaz con el HMI — el patrón habitual de agrupar en un
  DB todo lo que el panel lee y escribe. Coincide con lo que propone
  [`estructura-proyecto.md`](../../20-standards/estructura-proyecto.md) como `70_HMI/`.
- **Sin agrupar**: los 4 bloques cuelgan de la raíz de `Program blocks`. En un proyecto de 4
  bloques da igual; a partir de 20 es un problema.
- **Nomenclatura mixta**: `Main`, `lightControl`, `HMI_Inteface` — camelCase, PascalCase y un
  typo. Exactamente el tipo de cosa que `20-standards/naming.md` existe para evitar.

---

## Para qué lo quieres

🐤 **Es el canario.** Pequeño, sin comunicaciones, sin dependencias raras. Fue el primero que se
migró y el primero sobre el que se probó la cadena MCP completa — y funcionó.

Buen candidato para el ejercicio *"reescribe esto siguiendo mis estándares"*: renombrar, agrupar,
crear las tags simbólicas que faltan, y comparar.

## Contenido de la carpeta

| | |
|---|---|
| `BasementLightControl/` | Proyecto **V16** original desempaquetado — intacto |
| `BasementLightControl_V20/` | Proyecto **migrado**, con el que se trabaja |
| `original-v16/` | `.zap16` intacto — **no tocar** |
| `docs/TIAPortalScreenshots.pdf` | 3,4 MB de capturas de la programación PLC y HMI |

## Estado

- [x] Desempaquetado y verificado
- [x] **Migrado a V20 por Openness** — 75 s, `OpenWithUpgrade`
- [x] **Inventariado con `tia-inspect`** — 4 bloques, 0 inconsistentes
- [x] **Compilado tras la migración: 0 errores, 0 advertencias** ✅
- [x] Guardado (`SaveProject`)
- [ ] Aclarado el misterio de las 0 tags
- [ ] Exportado a texto para git ([R03](../../10-kb/20-recetas/R03-exportar-a-git.md))

## Cómo abrirlo

TIA Portal V20 → `Proyecto → Abrir`:

```
50-examples\npatel-basement-light\BasementLightControl_V20\BasementLightControl_V20.ap20
```

Abre directo, sin pedir migración: ya está en V20.

| Carpeta | Qué es |
|---|---|
| `BasementLightControl_V20\` | **El migrado.** Es el que se abre |
| `BasementLightControl\` | El V16 original, intacto |
| `BasementLightControl_V20.backup\` | Backup que crea TIA durante el upgrade |
| `original-v16\` | El `.zap16` comprimido, red de seguridad |
