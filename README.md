# TIA-Claude

Workspace para operar **Siemens TIA Portal** desde cualquier agente de IA (Claude Code, Codex,
OpenCode, Antigravity, Cursor...) con conocimiento real del dominio y con mis estándares de
ingeniería.

## Estado

| Fase | Estado |
|---|---|
| Análisis de los 7 repos de referencia | ✅ |
| Arquitectura propuesta | ✅ pendiente de aprobar |
| Plan con hitos verificables | ✅ |
| TDD — decisiones | ✅ **7 cerradas** (ADR-001…007) |
| **M0 — entorno** | ✅ **COMPLETO** — grupo Openness OK, SDK instalado, servidor compilado |
| **M1 — `tia-inspect` operativo** | ✅ **conecta con TIA Portal V20**, 59 herramientas |
| **Fase 0 — estado reproducible** | 🟢 informe de entorno generado; configuración de perfiles pendiente |
| M4 — estándares | 🟢 nomenclatura **cerrada**; falta aplicarla a un proyecto real |
| **M5 — ejemplos** | ✅ **los 7 migrados a V20, inventariados y exportados a texto** |
| M3 — base de conocimiento | 🟢 **R01-R12** escritas y validadas: paths, límites, sesiones, errores, lógica |
| **`60-library/`** | ✅ **5 bloques SCL compilando con 0 errores y 0 advertencias en TIA V20** |
| M1b — `tia-create` (bulaofen V20) | ⬜ |
| Pruebas en PLCSIM | ⬜ **compilar no es funcionar** |

## ✅ Funciona

Cadena completa verificada el 2026-09-14: **Claude → MCP → Openness → TIA Portal V20**.

```
User in 'Siemens TIA Openness' user group: True
V19 / V20: Engineering OK · Portal OK
Connect: 27,7 s en frío · 0,3 s en caliente
59 herramientas de lectura registradas
```

### Uso desde consola, sin cliente MCP

```powershell
# Diagnóstico
30-tools\scripts\Invoke-TiaMcp.ps1 -Calls @(@{name='Doctor'})

# Abrir un proyecto e inventariarlo
30-tools\scripts\Invoke-TiaMcp.ps1 -Calls @(
    @{ name='Connect' },
    @{ name='OpenProject'; args=@{ path='...\Proyecto.ap20' } },
    @{ name='GetProjectTree' }
)

# Cerrar las instancias de TIA al terminar (Disconnect NO las cierra)
30-tools\scripts\Stop-TiaPortal.ps1
```

### Desde Claude Code

`.mcp.json` registra `tia-inspect` **en solo lectura**. Reinicia la sesión para que cargue.
Para escritura hay que relanzar el servidor con `--allow-write` ([ADR-006](00-meta/decisiones/ADR-006-limites-seguridad.md)).

## Empieza por aquí

1. **[`AGENTS.md`](AGENTS.md)** — el contrato del agente. Es la fuente de verdad
2. **[`20-standards/`](20-standards/)** — propuesta de estándares, **necesita tu revisión**
   (15 min: las 5 dudas del final de `naming.md` + el árbol de `estructura-proyecto.md`)
3. **[`60-library/blocks/`](60-library/blocks/)** — 5 bloques SCL listos y probados
4. **[`50-examples/`](50-examples/)** — los 7 proyectos TIA, con ficha de qué enseña cada uno
5. [`10-kb/`](10-kb/) — la base de conocimiento
5. [`00-meta/00-analisis-repos.md`](00-meta/00-analisis-repos.md) — qué aporta cada repo
6. [`00-meta/01-arquitectura.md`](00-meta/01-arquitectura.md) — cómo queda organizada la carpeta
7. [`00-meta/02-plan.md`](00-meta/02-plan.md) — hitos M0→M6 y la prueba de aceptación
8. [`00-meta/03-tdd.md`](00-meta/03-tdd.md) — el TDD original, con lo que queda abierto

## Decisiones cerradas

| ADR | Decisión |
|---|---|
| [001](00-meta/decisiones/ADR-001-toolchain.md) | Compilar desde fuente con .NET SDK 10 (no extraer binario de VS Code) |
| [002](00-meta/decisiones/ADR-002-version-tia.md) | **V20 operativa**; V19 preparada pero no soportada — y cuesta más de lo previsto |
| [003](00-meta/decisiones/ADR-003-lenguajes.md) | SCL para lógica, LAD para planta. **El agente nunca escribe LAD a mano** |
| [004](00-meta/decisiones/ADR-004-prioridades.md) | Orden de las recetas: entender → estructura → lógica → HMI |
| [005](00-meta/decisiones/ADR-005-git.md) | Workspace **público**, proyectos de cliente en repos privados aparte |
| [006](00-meta/decisiones/ADR-006-limites-seguridad.md) | PLCSIM libre; **hardware físico solo con confirmación explícita en el momento** |
| [007](00-meta/decisiones/ADR-007-estandares.md) | Estándares propuestos desde cero sobre SCE + PLCopen + ISA-5.1 |
| [008](00-meta/decisiones/ADR-008-nomenclatura-cerrada.md) | Las 5 dudas de nomenclatura, cerradas con la evidencia de los 7 ejemplos |

## Entorno detectado

| | |
|---|---|
| TIA Portal | **V19** y **V20**, ambos con Openness OK |
| Idioma de la interfaz | V20 **solo inglés**; V19 inglés + español ⚠️ *afecta a los paths de Openness* |
| STEP 7 | Professional + **Safety** en V19 y V20 |
| WinCC | **Comfort/Advanced ES** + **Unified ES** + Basic, en V19 y V20 |
| Simulación | **PLCSIM Advanced V6.0** ✅ + PLCSIM V19 + PLCSIM V5.4 |
| WinCC RT | Runtime Advanced V17 + Unified PC V19 |
| .NET Framework | 4.8.1 ✅ |
| .NET SDK | **10.0.401** ✅ (instalado hoy) |
| Dev Pack .NET Framework | **4.8.1** ✅ (instalado hoy) |
| Grupo `Siemens TIA Openness` | ❌ **vacío** |
| Grupo `Siemens TIA Engineer` | ✅ eres miembro |

## Repos de referencia

Clonados en `_ref/` (solo lectura; no se versionan, se recrean con `git clone`):

| Repo | Rol |
|---|---|
| `heilingbrunner/tiaportal-mcp` | ✅ **Motor de lectura/análisis** — compilado en `30-tools/mcp/tia-inspect/` |
| `bulaofen0036-coder/TIA_Portal_Openness_MCP` | Motor de **creación** — 224 tools, `ScaffoldProject`, HMI, V20/V21 |
| `Czarnak/tia-portal-mcp` | Descartado hoy: **solo V21** |
| `siemens/tia-portal-openness-code-snippets` | 91 snippets oficiales — materia prima del conocimiento |
| `Dego-Dantas/tia-integration-ai` | Índice que llevó a los dos primeros |
| `npatel221/PLC_Projects` | 4 proyectos terminados (V16) — referencia de "cómo debe quedar" |
| `RobertOrsin/TIAPortalGames` | Límites de WinCC + VBScript (V16) — exploración, no estándar |
