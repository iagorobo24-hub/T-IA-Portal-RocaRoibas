# Traffic Light Control

- **Autor:** [npatel221](https://github.com/npatel221/PLC_Projects) · **Licencia:** ver repo original
- **TIA:** V16 → migrar a V20 · **HMI:** WinCC RT Advanced · **Sim:** PLCSIM
- **Proyecto:** `tia/TrafficLight.ap16`

## Qué hace

Control de un semáforo.

> ⚠️ El `README.md` original del autor **está vacío**: no documentó nada por escrito. Todo lo
> que dejó está en el PDF de capturas (7,6 MB), y el detalle real habrá que sacarlo abriendo el
> proyecto.

## Qué enseña

Sobre el de la luz de sótano, añade lo que de verdad diferencia un PLC de un circuito lógico:

- **Temporización** — temporizadores IEC (`TON`, `TOF`)
- **Secuencia** — estados que se suceden en orden y vuelven al principio
- **Máquina de estados** — el patrón más reutilizable de toda la automatización

## Para qué lo quieres

Es el segundo paso natural después del sótano, y el mejor sitio para comparar dos formas de
hacer lo mismo: la secuencia original en LAD, y cómo quedaría reescrita como `CASE` en SCL
siguiendo [`20-standards/estilo-scl.md`](../../20-standards/estilo-scl.md).

Ese ejercicio — *"reescribe esta secuencia LAD como máquina de estados SCL"* — es un caso de
prueba excelente para el agente.

## Contenido real ✅ *migrado e inventariado el 2026-09-14*

**7 bloques, 31 tags en 2 tablas, 0 tipos, 0 inconsistentes.** HMI: `HMI_RT_3`.

```
Program blocks
├── Main              [OB1]
├── Startup           [OB100]
├── Intersection      [FB]  + Intersection_DB
├── LightOperation    [FB/FC]
├── faultOutput
└── performReset
PLC tags
├── Default tag table
└── TrafficLightTags
```

Estructura claramente mejor que la del sótano: un FB `Intersection` por cruce, `LightOperation`
para la lógica de cada semáforo, y bloques separados para fallo y reset. **Es el patrón
coordinador + dispositivo**, que es lo que propone
[`estructura-proyecto.md`](../../20-standards/estructura-proyecto.md).

## ⚠️ La advertencia de compilación — resuelta ✅

Es el único de los siete que avisa de algo. El mensaje exacto:

> **`Inputs or outputs are used that do not exist in the configured hardware.`**
> *(categoría: General warnings, sobre `PLC_1`)*

**Causa, verificada:** el programa necesita **12 salidas** y el hardware solo tiene **4**.

| Lo que usa el programa | Lo que hay configurado |
|---|---|
| `%Q0.0`–`%Q0.5` → norte y sur (6 luces) | **S7-1200** con solo la E/S integrada de la CPU: |
| `%Q1.0`–`%Q1.5` → este y oeste (6 luces) | `DI 6/DQ 4` → **4 salidas**, `%Q0.0`–`%Q0.3` |
| `%I0.0`, `%I0.1` → start y reset | `AI 2` |
| `%M2.0`–`%M2.2` → marcas internas | **Sin módulos de ampliación** |

Así que `%Q0.4`, `%Q0.5` y todo `%Q1.x` — **8 de las 12 luces** — no tienen borne físico.

🔒 **No es un daño de la migración. Es así desde el origen y es deliberado.** El autor lista
**PLCSIM** entre sus herramientas: en simulación las salidas no necesitan existir en hardware.
Es un proyecto didáctico, no uno de planta.

**Para quitar la advertencia** habría que añadir un módulo de salidas digitales (por ejemplo una
signal board o un SM de 8 DQ) a la configuración hardware. No hace falta si solo vas a simular.

💡 **Y es un buen caso de estudio:** enseña que *compila* no significa *desplegable*. Un programa
puede compilar con 0 errores y no poder controlar nada porque la mitad de sus salidas no existen.

⚠️ Usa la `Default tag table` además de `TrafficLightTags` — el antipatrón de
[`estructura-proyecto.md`](../../20-standards/estructura-proyecto.md).

⚠️ Nomenclatura inconsistente: `Main`, `Intersection`, `LightOperation` en PascalCase junto a
`faultOutput` y `performReset` en camelCase.

## Contenido de la carpeta

| | |
|---|---|
| `TrafficLight_V20/` | **El migrado.** Este es el que abres |
| `TrafficLight/` | V16 original, intacto |
| `src/` | Export textual: 7 `.s7dcl`, 6 `.s7res`, 2 `.xml` |
| `original-v16/` | `.zap16` intacto — **no tocar** |
| `docs/TIAPortalScreenshots.pdf` | 7,6 MB de capturas, la única documentación que hay |

## Estado

- [x] Desempaquetado y verificado
- [x] **Migrado a V20** por Openness (73 s)
- [x] **Compilado:** 0 errores, **1 advertencia** ⚠️
- [x] **Advertencia diagnosticada:** faltan 8 salidas en el hardware — de origen, no de la migración
- [x] **Inventariado** — 7 bloques, 31 tags (17 en `TrafficLightTags` + 14 en la tabla por defecto)
- [x] **Exportado a `src/`** para git
- [x] Hardware confirmado: **S7-1200** (E/S integrada `DI 6/DQ 4` + `AI 2`) y **TP1200 Comfort**
