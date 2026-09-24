# Operar TIA Portal por la interfaz gráfica (computer use)

> El contenido de inspección visual de TIA fue verificado el 2026-09-14 con el proyecto
> `npatel-sorting-plant` migrado a V20. Las instrucciones de API de control que aparecen más abajo
> describían el harness usado entonces; para Codex en Windows, sigue primero la sección actual.

## Computer Use nativo actual en Codex para Windows

Computer Use es una capacidad del host/sesión de Codex, no de los servidores TIA MCP. En este
workspace, la ruta comprobada en Codex es el plugin nativo `computer-use` mediante `node_repl` y
`@oai/sky`. `mcp__cua_repl` está limitado a navegador y el valor `apps: []` de esa superficie no
indica si hay control de ventanas Windows. Este acceso tampoco se hereda automáticamente por Claude
Code, OpenCode u otros agentes: cada host necesita tener su propia integración y permisos.

### Habilitar o recuperar el acceso

1. En Codex, abre **Plugins > Computer Use**. Instala/habilita el plugin y sus componentes de servidor
   y skill cuando se ofrezcan.
2. Revisa **Settings > Computer use** y el permiso de la aplicación de TIA. Una política de workspace
   puede desactivar Computer Use o limitar las aplicaciones permitidas; solo un administrador puede
   cambiar un requisito impuesto por la organización.
3. En Windows, deja TIA visible en el escritorio activo mientras el agente trabaja. El control de UI
   usa esa sesión activa.
4. En cada sesión, vuelve a enumerar las aplicaciones y ventanas. No reutilices IDs antiguos ni
   inventes IDs a partir del nombre de la aplicación.

Documentación oficial: [Computer Use en Codex](https://learn.chatgpt.com/docs/computer-use) y
[políticas de Computer Use para Enterprise](https://help.openai.com/en/articles/20001510-manage-browser-and-computer-use-in-your-enterprise-workspace).

### Secuencia de observación segura

1. Leer la skill `computer-use/SKILL.md` y sus guías `docs/guidance.md` y `docs/confirmations.md`.
2. Inicializar `@oai/sky` en `node_repl` y llamar a `sky.list_apps()` o `sky.list_windows()`.
3. Elegir una ventana devuelta por la API. Si hay cero o varias ventanas candidatas, resolverlo antes
   de actuar. Llamar a `sky.get_window_state()` y verificar visualmente título, proyecto, diálogo,
   foco y estado.
4. Hacer una sola acción basada en esa observación y volver a leer el estado. Las coordenadas,
   índices y screenshot IDs caducan al cambiar la ventana o la vista.
5. Para escribir texto, observar primero el foco. Si no se puede comprobar el foco, no escribir.
   `Computer Use` no debe usarse para comandos de terminal, PowerShell, Windows Run ni para sortear
   avisos de seguridad.

Inicialización del runtime de Codex:

```js
if (!globalThis.sky) {
  const { sky } = await import("@oai/sky");
  globalThis.sky = sky;
}
globalThis.apps = await sky.list_apps();
nodeRepl.write(JSON.stringify(apps.map(app => ({
  id: app.id,
  windows: app.windows.map(window => ({ id: window.id, app: window.app, title: window.title }))
})), null, 2));
```

### Prueba gráfica observada en este workspace — 2026-09-21

- **Verificado:** no había proceso TIA ni ventana TIA antes de iniciar esta prueba; Doctor confirmó
  que no había proyecto conectado y que el usuario pertenece al grupo Siemens Openness.
- **Verificado:** se abrió TIA Portal V20 y, desde el selector de proyectos, se eligió el `.ap20`
  descrito por el manifiesto del fixture:
  `90-tmp/e2e/20260921-iot2050-agent-probe-clean/fixture/IOT2050_S7_CompleteProject_V20/IOT2050_S7_CompleteProject_V20.ap20`.
- **Verificado:** el título de TIA mostró la ruta del clon y la vista de proyecto permitió expandir
  `PLC_1` y `Program blocks`.
- **No verificado:** edición de SCL/LAD/HMI desde la GUI, guardado/compilación iniciados desde GUI,
  runtime HMI, descarga a PLCSIM desde GUI y descarga a hardware.
- **Detalle operativo:** `launch_app` no devolvió una ventana en su primera respuesta; la nueva
  consulta `list_apps()` sí devolvió una ventana TIA llamada `Siemens`. Después de abrir el proyecto,
  el título ya contenía su path. Se debe refrescar el inventario tras un inicio lento, no repetir el
  lanzamiento a ciegas.

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

## Mecánica Windows del harness anterior — referencia histórica

Los nombres `screenshot`, `switch_display` y `open_application` de los apartados siguientes
pertenecen a la integración gráfica que se usó para la prueba del 2026-09-14. No son los nombres
del plugin nativo de Codex descrito arriba. En Codex, usa `sky.get_window_state`, `sky.list_apps`,
`sky.list_windows`, `sky.activate_window`, `sky.click` y `sky.press_key`, con observación nueva
después de cada acción. Conservamos las notas históricas de resolución/latencia como referencia,
pero no deben copiarse como código ejecutable en Codex.

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

⚠️ **`tia-inspect` no cubre casi nada de la rama HMI.** Su perfil read V20 registró 53 herramientas
en la captura del 2026-09-24 y estas son principalmente de PLC. Para HMI:
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

> ⚠️ Ejemplo LAD histórico solo para inspección: `Fault` es `VAR_OUTPUT`, aunque el siguiente
> network lo lee como contacto. El export confirma la fidelidad del texto, no valida ese patrón.
> En SCL nuevo, usa estado interno (`VAR`/`STAT`) y publica la salida al final. Consulta
> [R04](../20-recetas/R04-entender-un-bloque.md) y [la regla SCL](../30-lenguajes/scl.md).

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
