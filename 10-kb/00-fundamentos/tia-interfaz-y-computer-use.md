# Operar TIA Portal por la interfaz gráfica (computer use)

> ✅ **Todo verificado en esta máquina el 2026-09-14** inspeccionando
> `npatel-sorting-plant` migrado a V20. No es teoría.

## Cuándo usar esto y cuándo no

🔒 **Openness primero, siempre.** Es rápido, determinista y no depende de dónde esté una ventana.
La interfaz gráfica es para lo que Openness **no puede** hacer.

| Necesidad | Herramienta |
|---|---|
| Inventariar, leer, exportar, compilar, guardar | **Openness** (`tia-inspect`) |
| Ver una pantalla **HMI** renderizada | **GUI** — Openness no dibuja |
| Leer el **log de migración** | **GUI** — `OpenProject` no lo devuelve |
| Ver el **LAD gráfico** | Cualquiera de los dos: el `.s7dcl` es fiel (ver abajo) |
| Saber el **modelo exacto de CPU y de panel** | **GUI**, o `GetDeviceInfo` |
| Diagnosticar una advertencia de compilación | **GUI** — el detalle está en la ventana de Info |

---

## Mecánica en Windows — los tres tropiezos

### 1. TIA puede estar en otro monitor

`screenshot` captura **un** monitor y dice cuál. Si TIA no aparece:

```
switch_display → "display 88589795"   ← el nombre sale en la nota del screenshot
```

### 2. El shell del escritorio bloquea los clics

Si el escritorio o la barra de tareas están al frente, cualquier clic falla con
*"The desktop shell is frontmost"*. **No pidas permiso para el Explorador**: trae TIA al frente.

```
open_application("TIA Portal V20")
```

🔒 **Hazlo antes del primer clic de cada tanda.** Es el fallo más común y no es evidente.

### 3. Coordenadas y escala

El marco de coordenadas es **siempre** el de resolución completa (aquí 1456×819), aunque pidas
la captura a escala 0,5. Si lees coordenadas sobre una imagen escalada tienes que multiplicar, y
te equivocas. **Pide `screenshot` sin `scale` cuando vayas a hacer clic**; usa escala reducida
solo para mirar.

---

## Tiempos medidos

| Acción | Tiempo |
|---|---|
| Abrir un proyecto **ya migrado** desde la GUI | ~60 s |
| Pasar de vista Portal a vista Proyecto | ~20 s |
| Abrir un bloque LAD en el editor | ~15 s |
| Abrir una pantalla HMI | ~20 s |
| Expandir un nodo del árbol | 2-4 s |

Dale margen: TIA no da feedback mientras carga y parece colgado cuando no lo está.

---

## El árbol de proyecto en V20

Los nombres de nodo que salen aquí son **los mismos que devuelve Openness** (con la interfaz en
inglés). Sirve de mapa para traducir entre las dos vistas.

### Bajo un PLC

```
Device configuration · Online & diagnostics · Software units
Program blocks · Technology objects · External source files
PLC tags · PLC data types · Watch and force tables
Online backups · Traces · OPC UA communication · Device proxy data
Program info · PLC supervisions & alarms · PLC alarm text lists · Local modules
```

### Bajo un HMI Comfort

```
Device configuration · Online & diagnostics · Runtime settings
Screens · Screen management · HMI tags · Connections · HMI alarms
Recipes · Historical data · Scripts · Scheduled tasks · Cycles
Reports · Text and graphic lists · User administration
```

⚠️ **`tia-inspect` no cubre casi nada de la rama HMI.** Sus 59 herramientas son de PLC. Para HMI:
o la GUI, o `tia-create` (bulaofen), que sí tiene herramientas de WinCC Unified — pero **no de
Comfort/Advanced**.

### A nivel de proyecto

```
Devices & networks · Ungrouped devices · Security settings
Cross-device functions · Common data · Documentation settings
Languages & resources · Version control interface · Online access · Card Reader/USB memory
```

> `Version control interface` existe en V20, pero el flujo completo de mapeo a carpeta de texto
> es de V21. Ver [`10-openness/limites.md`](../10-openness/limites.md).

---

## Lo que la GUI enseña y la API no

Comparando lo que devolvió `GetPlcSummary` con lo que se ve en pantalla, en el mismo proyecto:

| Dato | ¿Lo da la API? |
|---|---|
| Nº de bloques, tipos, tags | ✅ `GetPlcSummary` |
| Nombres y números de bloque | ✅ `GetSoftwareTree` |
| **Modelo exacto de CPU** (`CPU 1516F-3 PN/DP`) | ❌ en el resumen — hay que ir a `GetDeviceInfo` |
| **Que la CPU es F (Safety)** | ❌ no aparece en ningún resumen |
| **Modelo de panel** (`TP900 Comfort`) | ❌ |
| **Pantallas HMI y su contenido** | ❌ nada |
| **Aspecto renderizado de una pantalla** | ❌ imposible por API |

🔴 **El caso de la F-CPU es el que más importa.** `GetPlcSummary` devolvió 7 bloques y ni una
mención a seguridad. Solo abriendo el proyecto se ve que es una **1516F**. Aquí no había programa
de seguridad activado —no aparece el nodo *Safety Administration*— pero **la API no te lo iba a
decir**.

> **Regla que sale de aquí:** antes de escribir en un PLC que no conoces, comprueba el modelo de
> CPU. Si lleva **F**, para y pregunta. `AGENTS.md` §3.3 ya prohíbe editar safety, pero hay que
> saber que estás en un proyecto de safety para aplicarlo.

---

## El `.s7dcl` es fiel al LAD gráfico ✅

Comprobado abriendo `CylinderControl [FB2]` en el editor y comparándolo con su export.

**En el editor:**

```
#"Extend Command" ──┤ ├── #"Retract Command" ──┤ ├──────────( )── #Fault
#Fault ────────────┤ ├───────────────────────────────────(RET)── FALSE
```

**En el `.s7dcl`:**

```
NETWORK
    RUNG wire#powerrail
        Contact( #"Extend Command" )
        Contact( #"Retract Command" )
        Coil( #Fault )
    END_RUNG
    RUNG wire#powerrail
        Contact( #Fault )
        ReturnCoil( FALSE )
    END_RUNG
END_NETWORK
```

Misma información, incluidos los títulos de network — que vienen del `.s7res` (y con el typo
`"inerlock"` del autor intacto en los dos sitios).

🔒 **Conclusión práctica: para *leer* lógica LAD no hace falta abrir TIA.** Basta con
`GetBlockSource`. La GUI se reserva para lo visual y para lo que la API no expone.

---

## Qué comprobar al verificar una migración

Orden que funcionó, de más barato a más caro:

1. **¿Qué CPU y qué panel son?** El nodo del árbol lo dice entre corchetes:
   `Sorting Plant Controller [CPU 1516F-3 PN/DP]`, `HMI_1 [TP1200 Comfort]`.
   Aquí es donde aparece la **F** de una CPU de seguridad.
2. **¿Coinciden los bloques con lo que dijo la API?** Expandir `Program blocks` y contar.
   En los dos proyectos revisados, coincidencia exacta.
3. **Abrir un bloque.** Si el LAD se dibuja y los comentarios de network están, la lógica migró.
4. **Abrir una pantalla HMI.** Es lo que más riesgo tenía y lo único que no se puede comprobar
   por API.
5. **Mirar `Scripts`** si es un HMI Comfort/Advanced. Ahí vive el VBScript.

### WinCC Comfort: dónde está cada cosa

| Nodo | Contiene |
|---|---|
| `Screens` | Las pantallas. Se abren con doble clic y se renderizan completas |
| `Scripts → VB scripts` | El VBScript, en carpetas. Con resaltado de sintaxis |
| `HMI tags` | Las tags del panel |
| `Connections` | El enlace con el PLC |
| `Text and graphic lists` | Listas gráficas — la base de los sprites en WinCC |

💡 **`SmartTags("nombre")` es la API de VBScript para leer y escribir tags de HMI.** Y admite
construir el nombre por concatenación: `SmartTags("pos_x_" & i)`. Así se simulan arrays sobre
tags planas, que es la única forma de tener estructuras dinámicas en WinCC Comfort.

---

## Reglas de seguridad al usar la GUI

🔒 **Una instancia con ventana es de la persona que está delante.** Puede tener cambios sin
guardar. Nunca la cierres, nunca la mates. `Stop-TiaPortal.ps1` solo cierra las headless por eso.

🔒 **No mezcles GUI y Openness sobre el mismo proyecto.** Un proyecto abierto en la GUI **no se
puede abrir** desde una instancia headless: está bloqueado. Se ve como un `OpenProject` que
falla en 2 s. Ver [`50-errores`](../50-errores/README.md).

🔒 **Mirar es gratis; tocar no.** Navegar el árbol, abrir bloques y pantallas no modifica nada.
En cuanto haya que editar, vuelven a aplicar las reglas de `AGENTS.md` §3.2: backup, cambio
mínimo, compilar, guardar.

⚠️ **Los procesos elevados no se pueden controlar.** Windows bloquea la entrada desde procesos de
integridad menor. Si sale un UAC o un instalador como administrador, hay que pedirle a la persona
que lo haga a mano.
