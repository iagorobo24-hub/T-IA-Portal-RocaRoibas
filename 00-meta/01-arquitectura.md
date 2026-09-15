# Arquitectura propuesta de `C:\Users\jose.mellid\TIA-Claude`

> Propuesta en ejecución. El estado comprobado de la instalación se mantiene en
> `decisiones/ADR-009-estado-real-2026-09.md`.

## Principio rector

**Una sola fuente de verdad en Markdown plano; adaptadores finos por harness.**

Claude Code, Codex, OpenCode y Antigravity leen cosas distintas (`CLAUDE.md`, `AGENTS.md`,
`.mcp.json`, `opencode.json`, `mcp_config.json`...). Si el conocimiento vive dentro del formato
de uno de ellos, quedas atado a ese harness. Por eso:

- El **conocimiento** vive en `10-kb/` y `20-standards/` como Markdown normal.
- El **contrato del agente** vive en `AGENTS.md` (el formato más portable).
- `CLAUDE.md` es un fichero de 3 líneas que dice "lee AGENTS.md".
- Las configuraciones de MCP se **generan** desde un manifiesto único con un script.

Corolario: si mañana aparece un harness nuevo, escribes un adaptador de 20 líneas y sigues.

---

## Estructura de carpetas

```
C:\Users\jose.mellid\TIA-Claude\
│
├── README.md                 ← qué es esto, estado actual, por dónde empezar
├── AGENTS.md                 ← ★ contrato del agente (fuente de verdad)
├── CLAUDE.md                 ← 3 líneas: "lee AGENTS.md"
├── .mcp.json                 ← generado, no editar a mano
├── .gitignore
│
├── 00-meta/                  ← documentación DEL repo sobre sí mismo
│   ├── 00-analisis-repos.md
│   ├── 01-arquitectura.md    ← este fichero
│   ├── 02-plan.md            ← hitos con criterio de aceptación
│   ├── 03-tdd.md             ← decisiones abiertas
│   └── decisiones/           ← ADR-001.md, ADR-002.md... (una decisión, un fichero)
│
├── 10-kb/                    ← ★ EL CEREBRO: cómo funciona TIA Portal
│   ├── README.md             ← índice navegable; es lo que el agente lee primero
│   ├── 00-fundamentos/       ← TIA, versiones, licencias, PLCSIM, ciclo de vida de proyecto
│   ├── 10-openness/          ← modelo de objetos, path concept, sesiones, límites duros
│   ├── 20-recetas/           ← ★ runbooks: "cómo hacer X", paso a paso, con tool calls
│   ├── 30-lenguajes/         ← SCL, LAD, FBD, STL, GRAPH: sintaxis + patrones + antipatrones
│   ├── 40-hmi/               ← WinCC Unified y Comfort
│   ├── 50-errores/           ← catálogo: síntoma → causa → arreglo
│   └── 90-referencia/        ← tablas rápidas: tipos, familias CPU, áreas de memoria
│
├── 20-standards/             ← ★ CÓMO TRABAJO YO
│   ├── README.md
│   ├── naming.md             ← nomenclatura de bloques, tags, DBs, UDTs, redes
│   ├── estructura-proyecto.md← cómo debe quedar un proyecto terminado
│   ├── estilo-scl.md
│   ├── estilo-lad.md
│   ├── documentacion.md      ← qué documentos entrega un proyecto y con qué formato
│   └── definition-of-done.md ← checklist de entrega
│
├── 30-tools/                 ← herramientas
│   ├── README.md
│   ├── mcp/
│   │   ├── servers.json      ← ★ manifiesto único de servidores MCP
│   │   ├── tia-create/       ← runtime bulaofen (V20)
│   │   └── tia-inspect/      ← build heilingbrunner
│   ├── scripts/
│   │   ├── doctor.ps1        ← diagnóstico del entorno completo
│   │   ├── sync-configs.ps1  ← servers.json → .mcp.json + opencode.json + ...
│   │   ├── new-project.ps1   ← copia 40-projects/_template y lo rellena
│   │   ├── export-src.ps1    ← proyecto TIA → 40-projects/<x>/src/ para git
│   │   └── backup.ps1
│   └── bin/                  ← ejecutables resueltos      [gitignored]
│
├── 40-projects/              ← ★ TRABAJO REAL, un directorio por proyecto
│   ├── _template/            ← esqueleto a copiar
│   └── <cliente>-<maquina>/
│       ├── README.md         ← qué máquina es, qué hace, estado
│       ├── tia/              ← .ap20 + carpeta del proyecto    [¿git? → TDD]
│       ├── src/              ← ★ export textual .s7dcl/.s7res/.scl → ESTO va a git
│       ├── specs/            ← JSON/YAML de ScaffoldProject y PlcBuildAndImport
│       ├── docs/             ← lista de E/S, esquemas, manual
│       └── ops/              ← logs de compilación, informes            [gitignored]
│
├── 50-examples/              ← ★ ejemplos digeridos y catalogados
│   ├── README.md             ← índice: qué enseña cada uno, en qué versión, estado
│   ├── npatel-basement-light/
│   ├── npatel-traffic-light/
│   ├── npatel-sorting-plant/
│   ├── npatel-iot/           ← el más valioso: OPC-UA, MQTT, Node-RED, cloud
│   ├── orsin-wincc-games/    ← exploración de límites de WinCC, NO estándar
│   └── siemens-snippets/     ← 91 snippets de la API, indexados por área
│
├── 60-library/               ← ★ lo que consolidas como reutilizable
│   ├── blocks/               ← FB/FC/UDT probados (.s7dcl + .xml + ficha)
│   ├── hmi/                  ← faceplates, plantillas de pantalla
│   └── specs/                ← blueprints de proyecto reutilizables
│
├── 70-runs/                  ← artefactos de ejecución, exports crudos   [gitignored]
├── 90-tmp/                   ← basura, se borra entera sin pensar        [gitignored]
└── _ref/                     ← clones tal cual de los 7 repos, solo lectura [gitignored]
```

### Por qué prefijos numéricos

Ordenan solos en el explorador y en `ls`, y el número comunica el flujo: *conocimiento (10) →
estándares (20) → herramientas (30) → trabajo (40) → ejemplos (50) → librería (60)*. El hueco
entre números deja sitio para insertar sin renumerar. ⬜ *Si prefieres nombres planos, se cambia
en 5 minutos — está en el TDD.*

### Por qué `src/` separado de `tia/`

Un `.ap20` es binario: git lo guarda entero en cada commit y no puedes ver qué cambió. El export
textual (`.s7dcl` + `.s7res`) que produce heilingbrunner en V20+ **sí** diffea. La regla es:

> `tia/` es el artefacto de trabajo. `src/` es la verdad revisable.
> Después de cada cambio significativo: exportar a `src/`, commit.

---

## Arquitectura de ejecución

```
┌──────────────────────────────────────────────────────────────┐
│  Harness (Claude Code / Codex / OpenCode / Antigravity)      │
│                                                              │
│  lee → AGENTS.md ──┬──→ 10-kb/     (cómo funciona TIA)       │
│                    └──→ 20-standards/ (cómo trabajo yo)      │
└────────────┬─────────────────────────────────────────────────┘
             │ MCP (stdio)
    ┌────────┴────────────────────────┐
    │                                 │
┌───▼──────────────┐         ┌────────▼──────────────┐
│  tia-inspect     │         │  tia-create           │
│  (heilingbrunner)│         │  (bulaofen, lite)     │
│                  │         │                       │
│  LEER + entender │         │  CREAR proyectos      │
│  59 read tools   │         │  hardware / red / HMI │
│  git-friendly    │         │  ~43 tools (lite)     │
│  export .s7dcl   │         │  ScaffoldProject      │
│                  │         │                       │
│  ⚠ --allow-write │         │  ⚠ dryRun primero     │
│    solo bajo     │         │                       │
│    demanda       │         │                       │
└───┬──────────────┘         └────────┬──────────────┘
    │                                 │
    └──────────┬──────────────────────┘
               │ Openness API (.NET Framework 4.8)
    ┌──────────▼─────────────────────────────────┐
    │  TIA Portal V20  (C:\...\Portal V20)       │
    │  + PLCSIM V19 para validación en runtime   │
    └────────────────────────────────────────────┘
```

### Dos servidores, no uno

Por tres razones concretas:

1. **Ninguno cubre todo.** heilingbrunner no crea proyectos ni toca hardware; bulaofen no
   tiene `WhereUsed` ni export textual maduro.
2. **Límite de herramientas.** 224 + 99 = 323 herramientas revientan cualquier cliente y
   degradan la elección del modelo. Con bulaofen en `lite` (43) + heilingbrunner en lectura
   (59) quedan ~102, manejable.
3. **Perímetro de seguridad distinto.** `tia-inspect` puede estar siempre activo sin riesgo.
   `tia-create` escribe; se activa deliberadamente.

⬜ *Decisión abierta: ¿siempre los dos, o perfiles conmutables? → TDD Q7.*

---

## El "producto final": qué es exactamente lo que consolidamos

No es un programa. Es un **workspace versionado** que se puede clonar en cualquier máquina con
TIA Portal y deja a cualquier IA operativa en minutos. Sus entregables concretos:

| Entregable | Qué es | Dónde |
|---|---|---|
| **Contrato del agente** | Reglas de operación, qué hacer y qué no, orden de arranque | `AGENTS.md` |
| **Base de conocimiento** | Cómo funciona TIA + recetas accionables | `10-kb/` |
| **Estándares** | Tu forma de nombrar, estructurar y documentar | `20-standards/` |
| **Toolchain** | MCPs instalados + scripts + `doctor.ps1` | `30-tools/` |
| **Adaptadores** | Generador de config para cada harness | `30-tools/scripts/sync-configs.ps1` |
| **Librería** | Bloques y plantillas propios, probados | `60-library/` |
| **Plantilla de proyecto** | Esqueleto reproducible | `40-projects/_template/` |

⬜ *Decisión abierta: ¿empaquetarlo además como plugin de Claude Code (`.claude-plugin/`) para
instalarlo con un comando? → TDD Q8.*

---

## Estrategia de Git

⬜ *Decisión abierta (TDD Q9), pero la recomendación es:*

- **Un repo** para el workspace (`TIA-Claude`), con `40-projects/*/tia/` ignorado y
  `40-projects/*/src/` versionado.
- `_ref/`, `70-runs/`, `90-tmp/`, `30-tools/bin/` ignorados.
- Los proyectos de cliente que no deban salir de aquí: `40-projects/.gitignore` local por
  proyecto, o repo separado.
- `.gitattributes` marcando `*.ap2*`, `*.zap*`, `*.s7res` como binarios para que git no
  intente mergearlos.
