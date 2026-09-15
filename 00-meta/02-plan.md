# Plan: de cero a "trabajo en TIA Portal con cualquier IA"

> La ejecución detallada y sus tareas verificables están en
> `docs/superpowers/plans/2026-09-15-tia-claude-system.md`. Este documento conserva el
> objetivo de aceptación original; el plan detallado añade los pasos de implementación que faltan.

## El objetivo verificado

No "que funcione". Esto:

> **Prueba de aceptación E2E (PA-1).**
> En un harness cualquiera (Claude Code, Codex, OpenCode, Antigravity), desde sesión fría,
> escribo una sola frase:
>
> *"Crea el proyecto `DEMO-Cinta01` con un S7-1500, control de marcha/paro de un motor con
> enclavamiento y seta de emergencia, una HMI Unified con pantalla de operación, compílalo sin
> errores y déjalo según mis estándares."*
>
> Y obtengo, **sin intervención manual**:
>
> 1. `40-projects/DEMO-Cinta01/tia/DEMO-Cinta01.ap20` que abre en TIA V20
> 2. Compilación con **0 errores** (evidencia: informe del compilador guardado en `ops/`)
> 3. Nomenclatura y estructura conformes a `20-standards/naming.md` — verificable con
>    `30-tools/scripts/check-standards.ps1`, que sale con código 0
> 4. `40-projects/DEMO-Cinta01/src/` con el export textual, y `git diff` legible
> 5. `README.md` del proyecto generado desde la plantilla, relleno
>
> Y una segunda frase sobre un proyecto **existente**:
>
> *"¿Dónde se usa la tag `Motor_Marcha` y qué bloques la escriben?"*
>
> devuelve la respuesta correcta con referencias cruzadas reales.

Todo lo demás en este plan existe para llegar a PA-1.

---

## Hitos

Cada hito tiene un **criterio de aceptación comprobable**. Un hito no está hecho hasta que su
criterio pasa.

---

### M0 — Desbloquear el entorno `[~1 h, mayormente tuyo]`

Nada funciona hasta esto. Los cinco bloqueos están documentados en `00-analisis-repos.md`.

| Paso | Acción | Quién |
|---|---|---|
| M0.1 | Añadir tu usuario al grupo `Siemens TIA Openness` (comando elevado) + **cerrar sesión y volver a entrar** | Tú (UAC) |
| M0.2 | Decidir e instalar el toolchain de compilación, o renunciar a compilar (ver Q1) | Tú |
| M0.3 | Descargar el bundle V20 de bulaofen (ZIP de release, 11,8 MB) | Yo, con tu OK |
| M0.4 | Definir `TiaPortalLocation` = `C:\Program Files\Siemens\Automation\Portal V20` | Yo |
| M0.5 | Escribir `30-tools/scripts/doctor.ps1` | Yo |

Comando de M0.1, en PowerShell **como administrador**:

```powershell
net localgroup "Siemens TIA Openness" "%USERNAME%" /add
```

> El grupo existe pero está **vacío**. Es el bloqueo nº1 más común de Openness y no da un
> error claro: da fallos de conexión opacos. Y **no surte efecto hasta cerrar sesión**.

**✅ Criterio de aceptación M0:** `doctor.ps1` imprime todo en verde:
grupo Openness OK, TIA V20 detectado, `Siemens.Engineering.dll` accesible, runtime del MCP
presente, y una llamada `Connect` real abre TIA Portal y devuelve estado conectado.

---

### M1 — Un MCP hablando con TIA `[~2 h]`

Instalar `tia-create` (bulaofen V20, perfil `lite`) y verificarlo contra un proyecto de juguete.

**✅ Criterio de aceptación M1:** desde Claude Code, la frase *"conéctate a TIA y dime qué
proyectos hay abiertos"* devuelve respuesta real, y `ScaffoldProject` con
`templates/project-blueprints/scaffold_spec_start_stop.json` genera un proyecto que compila
con 0 errores. **Esto ya prueba la mitad de PA-1.**

---

### M2 — El segundo MCP y la portabilidad entre harnesses `[~3 h]`

Instalar `tia-inspect` (heilingbrunner) — depende de Q1 — y escribir `sync-configs.ps1`.

**✅ Criterio de aceptación M2:** `servers.json` → `sync-configs.ps1` → los dos MCPs aparecen
y responden en **al menos dos harnesses distintos** (Claude Code + el que elijas en Q2).
`ExportPlcAsSourceTree` sobre el proyecto de M1 produce `.s7dcl` que abre en un editor de texto.

---

### M3 — La base de conocimiento `[~8-12 h, el grueso del trabajo]`

Escribir `10-kb/`. Esto es lo que convierte "una IA con herramientas" en "una IA que sabe de
automatización". Fuentes: los 91 snippets de Siemens, la doc oficial de Openness, las
limitaciones documentadas por los tres autores de MCP, y los 5 ejemplos.

Orden de escritura, por retorno decreciente:

1. **`50-errores/`** primero. Contraintuitivo, pero es donde un agente pierde más tiempo.
   Catálogo síntoma → causa → arreglo. Empieza por los que ya conocemos: bloque inconsistente
   al exportar, colisión de número de bloque al importar, path inventado, grupo Openness,
   bloque know-how protegido, F-blocks.
2. **`20-recetas/`**. Runbooks accionables. Cada receta: objetivo, precondiciones, secuencia
   exacta de llamadas, verificación, qué hacer si falla.
3. **`10-openness/`**. El *path concept* es lo primero: Openness navega por paths de objetos
   de ingeniería, no por nombres. Aquí van también los límites duros (no hay "crear bloque"
   genérico, no hay copy/move nativo, Openness no es thread-safe).
4. **`30-lenguajes/`**, **`90-referencia/`**, **`40-hmi/`**, **`00-fundamentos/`**.

**✅ Criterio de aceptación M3:** un agente **sin tus herramientas MCP**, solo leyendo
`10-kb/`, responde correctamente a 10 preguntas de control preparadas de antemano (banco de
preguntas en `00-meta/eval/kb-quiz.md`). Es una evaluación, no una sensación.

---

### M4 — Tus estándares `[~2-4 h, requiere entrevistarte]`

Escribir `20-standards/`. Esto sale de las respuestas del TDD (Q10-Q16) y, sobre todo, de
mirar proyectos tuyos reales.

**✅ Criterio de aceptación M4:** `check-standards.ps1` valida un proyecto existente tuyo y
señala correctamente las desviaciones. Y el agente, al generar un bloque nuevo, lo nombra y
estructura igual que lo harías tú — verificado a ojo sobre 3 bloques generados.

---

### M5 — Ejemplos catalogados `[~3 h]`

Migrar los ejemplos V16 → V20 **sobre copia**, e indexarlos en `50-examples/README.md` con
una ficha por proyecto: qué enseña, qué patrón usa, qué reutilizar y qué no.

**✅ Criterio de aceptación M5:** los 4 proyectos de npatel abren en TIA V20, y el índice
responde a *"¿dónde miro un ejemplo de comunicación OPC-UA?"* sin abrir TIA.

---

### M6 — PA-1 `[~2 h]`

Ejecutar la prueba de aceptación completa. Arreglar lo que salga. Documentar el resultado.

**✅ Criterio de aceptación M6:** PA-1 pasa entera, en dos harnesses, dos veces seguidas desde
sesión fría.

---

## Ruta crítica

```
M0 ──> M1 ──┬──> M2 ──┐
            │         ├──> M6 (PA-1)
            └──> M3 ──┤
                 M4 ──┤
                 M5 ──┘
```

M3 (conocimiento) y M4 (estándares) son el trabajo de verdad y **no dependen de M2**: se pueden
escribir en paralelo mientras se resuelve el toolchain. M0 bloquea absolutamente todo.

---

## Riesgos, con mitigación

| Riesgo | Prob. | Impacto | Mitigación |
|---|---|---|---|
| Openness V20 se comporta distinto a V21 en tools de bulaofen | Media | Alto | Probar en M1 con proyecto de juguete antes de invertir en M3/M4 |
| Compilar heilingbrunner requiere instalar SDK que no puedes/quieres instalar | Media | Medio | Plan B: extensión de VS Code (trae el .exe ya compilado). Plan C: solo bulaofen |
| La IA genera código que compila pero es incorrecto en planta | **Alta** | **Crítico** | Regla dura en `AGENTS.md`: **nada se descarga a un PLC físico sin revisión humana.** Validación en PLCSIM antes que en hardware. Ver Q17 |
| Superficie de 100+ herramientas confunde al modelo | Media | Medio | Perfil `lite` + recetas en `10-kb/20-recetas/` que fijan la secuencia correcta |
| Migración V16→V20 rompe los ejemplos | Baja | Bajo | Siempre sobre copia; los originales quedan intactos en `_ref/` |
| Proyectos de cliente acaban en un repo público por error | Baja | **Crítico** | `.gitignore` por defecto restrictivo; decisión explícita en Q9 |

---

## Lo que NO vamos a hacer

Para que el alcance quede claro:

- ❌ **Escribir un servidor MCP desde cero.** Existen tres, dos son buenos. Reinventarlo son
  meses y no aporta nada.
- ❌ **Descargar a PLC físico de forma autónoma.** El agente prepara y valida; la descarga a
  hardware real la autorizas tú, explícitamente, cada vez.
- ❌ **Traducir los 63 KB de la SKILL.md china de bulaofen.** Extraemos lo que sirve a nuestras
  recetas y el resto se deja como referencia.
- ❌ **Soportar V19 y V20 a la vez desde el principio.** Se fija una versión (Q3) y punto;
  multi-versión se añade después si hace falta.
