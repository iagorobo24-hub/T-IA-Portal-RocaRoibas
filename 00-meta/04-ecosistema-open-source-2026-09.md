# Centro de mando TIA Portal + agente IA — valoración del ecosistema y Top 5

**Roca Roibás · 22 de septiembre de 2026**
Investigación sobre proyectos open source de TIA Portal y vías de control desde un agente local (Claude Code, Codex, OpenCode, Antigravity).

---

## 0. Cómo leer este documento y qué fiabilidad tiene

Todo lo que sigue se ha verificado abriendo las páginas reales de GitHub, PyPI, npm, NuGet, Maven Central y la documentación de Siemens. Tres avisos de honestidad antes de empezar:

- **Las estrellas son orden de magnitud, no cifra exacta.** La API de GitHub estaba bloqueada; los números salen del HTML renderizado y varían entre lecturas (un mismo repo dio 171, 229 y 255 en tres páginas distintas).
- **Las fechas de último commit casi nunca son verificables** por HTML. Donde doy una fecha firme, procede de un registro con fecha absoluta (PyPI, npm, NuGet, Maven). Donde no la doy, es porque no la pude confirmar, no porque no exista.
- **No he inventado ningún repositorio, cifra ni fecha.** Cuando algo que busqué no existe, lo digo explícitamente (sección 5).

Este documento parte de lo que **ya tienes montado**: `AGENTS.md`, el reparto `tia-inspect` / `tia-create`, los perfiles `read`/`write`/`create`/`full`, el harness PowerShell (`Sync-HarnessConfigs.ps1`, `Invoke-McpToolSequence.ps1`, `Invoke-TiaSclProposalApply.ps1`) y el estado V20 / PLCSIM Advanced V6.0.0.1. No propongo tirar nada de eso.

---

## 1. Resumen ejecutivo

> **Antes de nada, lee §1.5.** Este equipo no tiene TIA V19/V20/V21 y los binarios del workspace están compilados contra V20, así que hoy aquí no arranca nada. Lo que sigue describe el destino; §1.5 describe el punto de partida real.

Tu arquitectura actual es correcta y está por delante de casi todo el ecosistema open source. Los dos MCP que usas (`tia-inspect` = heilingbrunner, `tia-create` = bulaofen) son, efectivamente, dos de los mejores que existen. Lo que te falta no es más herramienta de ingeniería: son **tres capas que hoy no tienes y que ningún proyecto único te va a dar**.

1. **Una vía de escritura que funcione.** Según tu propio `AGENTS.md` —observado en el otro equipo el 21-09-2026, no aquí— el perfil `write` en V20 está bloqueado: `tools/list` no registra `ImportSources` ni `ImportFromDocuments`, así que `Invoke-TiaSclProposalApply.ps1 -Apply` para en `BLOCKED`. Existe un proyecto que resuelve exactamente eso con un modelo de seguridad mejor que el tuyo.
2. **Una capa de verificación.** Hoy el agente puede compilar con 0 errores, pero no puede demostrar que el bloque *hace lo que debe*. Eso lo cubre PLCSIM Advanced automatizado, que ya tienes instalado y sin explotar.
3. **Una capa de reglas propia.** Para auditar programas de clientes necesitas un corpus de reglas deterministas. **Nadie ha codificado el Styleguide de Siemens como reglas automatizadas.** Es el mayor hueco del ecosistema y, para vosotros, el mayor diferenciador comercial.

Y hay **un hallazgo que reordena las prioridades**: desde TIA V20 Update 4 / V21, Siemens exporta LAD y FBD como **texto legible** (SIMATIC Source Documents), no como XML posicional. Si tu parque está ahí, el problema de "leer LAD sin GUI" desaparece. Si está en V16–V19, ese problema es trabajo a medida porque **no existe ningún parser open source de `FlgNet`**.

---

## 1.5 ⚠️ Estado real de ESTE equipo — nada de `AGENTS.md` aplica aquí

**Todo el bloque "Estado del entorno" de `AGENTS.md` describe otra máquina.** Lo confirma el propio `.mcp.json`, que apunta a `C:\Users\jose.mellid\TIA-Claude\...`, y el `TiaMcpServer.startup.log`, cuyas entradas de hoy (10:35, 11:05) tienen `BaseDir: C:\Users\jose.mellid\...`. Ese log viajó con la copia; no es evidencia de nada ejecutado aquí.

### Lo que sí he verificado en este equipo (`equipotecnico`)

Método: listado de directorios. **No he podido ejecutar comandos en esta máquina** —esta sesión no tiene shell sobre tu equipo, solo listar, leer y escribir ficheros— así que esto es inferencia por estructura de carpetas, no un `Doctor`. Es sólido para saber qué está instalado, insuficiente para saber en qué estado.

| | Encontrado |
|---|---|
| `C:\Program Files\Siemens\Automation` | **Portal V15_1, V16, V17, V18** · `PLCSIM_V18`, `S7-PLCSIM V15_1`, `S7-PLCSIM V17` · Multiuser Server V15_1/V16/V17 · Project Server · WinCCUnified · TIAADMIN / TIAAdminV3 · AWB_V2 |
| `C:\Program Files (x86)\Siemens\Automation` | **PLCSIMADV** (PLCSIM Advanced, versión no determinable por el nombre de carpeta) · Portal V15_1/V16/V17/V18 · WinCC RT Advanced · S7-PCT |
| Binarios del workspace | `tia-inspect/bin/v20/TiaMcpServer.exe` y `tia-create/bin/v20/TiaMcpServer.exe` — **ambos compilados contra Openness V20** |
| Fixture de test | `TestProject1.zap20` — **V20** |
| Configuración | `.mcp.json` y `servers.local.json` apuntan a rutas de `jose.mellid` |

### La conclusión incómoda

**No hay V19, ni V20, ni V21 en este equipo.** Hay V15.1, V16, V17 y V18.

Por el version lock de Openness (§2.2), los binarios que tienes no van a arrancar aquí: buscan un `Siemens.Engineering.dll` de V20 que no existe en esta máquina. No es un problema de rutas, es que no está el sustrato.

Y tampoco se arregla recompilando sin más. Tu propio `build.ps1` lo dice literalmente:

> `[ValidateSet(20, 21)]` — y en la documentación del parámetro: *"V19 AÚN NO está soportado: la API de documentos SIMATIC SD (.s7dcl/.s7res) no existe antes de Openness V20 y habría que compilar fuera toda esa funcionalidad. Ver ADR-002."*

El mapa de paquetes NuGet de Openness del script solo cubre 19, 20 y 21. Para V18 haría falta el `18.0.x`, más recortar todo lo que dependa de APIs posteriores. Es decir: **si V19 ya estaba descartado por esfuerzo, V18 lo está más.**

### Las tres salidas, y la que recomiendo

**A · Instalar TIA V20 (o V21) en este equipo.** Lo que ya está construido funciona tal cual, solo cambiando rutas y regenerando la configuración. Es la ruta rápida y la única que conserva SIMATIC Source Documents. Coste: licencia, disco y tiempo de instalación. Conviene comprobar antes si la licencia flotante os permite una instalación más.

**B · Portar `tia-inspect` a V18.** Añadir `18` al `ValidateSet`, resolver el paquete Openness `18.0.x`, y compilar fuera toda la funcionalidad de SIMATIC SD más lo que aparezca por el camino. Es trabajo real sobre terreno que tú mismo ya declaraste no soportado, y al terminar **habrías perdido justo lo que hace legible el LAD**. Solo tiene sentido si el parque de clientes es mayoritariamente ≤ V18 y la decisión es estratégica, no de conveniencia.

**C · Este equipo como máquina de auditoría legacy y de capa de reglas.** Aquí está la parte interesante: **la tarea T3 —revisión contra el Styleguide y el Top 20 Secure PLC— es nivel N0 y no necesita TIA Portal en absoluto.** Trabaja sobre los `.scl` ya exportados. Igual que buena parte de T2 y T4. Este equipo puede empezar a producir valor mañana en la tarea más rentable y más segura del catálogo, mientras la decisión A/B se resuelve por otro lado.

**Recomendación: C ahora, A en paralelo.** Empezar por C no bloquea nada, no depende de ninguna licencia, y construye justo la pieza que ningún proyecto del ecosistema te da. Y si al final instaláis V20 aquí, C sigue valiendo entero.

**Un apunte que juega a vuestro favor:** tener V15.1, V16, V17 y V18 en una misma máquina es exactamente lo que hace falta para auditar el parque legacy de clientes, que es donde está el volumen. No es un equipo mal configurado; es un equipo configurado para otra cosa. La pregunta no es "cómo lo arreglo" sino "qué papel le doy dentro del centro de mando".

### Trabajo de reconfiguración pendiente en este equipo, sea cual sea la salida

1. Regenerar `.mcp.json` y `servers.local.json` con rutas de este usuario (`C:\Users\Dpto. Técnico\Documents\TIA-Claude\...`), no las de `jose.mellid`.
2. Verificar la pertenencia al grupo Windows **`Siemens TIA Openness`** de *este* usuario. El `True` del log es del otro equipo. Se añade como administrador y **hay que cerrar sesión y volver a entrar** para que surta efecto.
3. Comprobar la versión real de PLCSIM Advanced instalada, y contra qué versión de TIA está emparejada.
4. Comprobar el nivel de update de cada TIA instalado.
5. Sustituir o duplicar el fixture `TestProject1.zap20` por uno de la versión que se acabe usando aquí.
6. Borrar o archivar el `TiaMcpServer.startup.log` heredado: hoy es evidencia falsa de un entorno sano.
7. Reescribir la sección 9 de `AGENTS.md` para que el estado del entorno sea **por máquina**, no global. Un contrato que afirma "PLCSIM Advanced V6.0.0.1 verificado" en un equipo donde no se ha verificado nada es peor que no tener contrato: induce al agente a dar por bueno lo que no lo está.

> El punto 7 es el que más me preocupa a medio plazo. Si el workspace va a vivir en varios equipos, el estado verificado tiene que ser un artefacto generado por `Doctor` en cada máquina —algo como `70-runs/doctor/<hostname>.json`— y `AGENTS.md` debe apuntar a él, no afirmarlo.

---

## 2. Los cinco hechos que reescriben el plan

### 2.1 Siemens ya distribuye una capa Python oficial

**TIA Scripting Python**, entry ID **109742322** en Siemens Industry Online Support: *"Tool for easier use of the TIA Portal Openness interface"*. Es un wheel de Python soportado por Siemens, no un montaje artesanal con `pythonnet`.

Esto invalida a todos los wrappers comunitarios de Python. `Repsay/tia-openness-api-client` (MIT, ~50★) es el más completo, pero su propio autor admite en el README: *"I cannot test the code myself due to the unavailability of TIA Portal"*. Los de `Maroder1` están anclados a V15.1/V16. Ninguno es una dependencia defendible ante un cliente.

Consecuencia: **si añades una ruta Python al centro de mando, va por TIA Scripting.** El resto sirve como mapa del modelo de objetos, no como código en producción.

### 2.2 El version lock de Openness es la restricción que define tu caso de uso

De la documentación oficial: *"With TIA Portal Openness V17.0, you can only access projects and libraries with Version V17.0"* y *"No compatibility can be guaranteed between the different versions of TIA Portal Openness"*.

Para tu objetivo real —auditar programas de **distintos clientes**— esto significa que necesitas **un binario y una instalación de TIA por cada versión del parque**. Un cliente en V16, otro en V18, otro en V21 son tres entornos, no uno con un flag. Las herramientas que anuncian "V15–V21" cargan la DLL correcta en runtime; no abstraen el modelo de objetos.

Esto es lo primero que hay que decidir a nivel de infraestructura, antes que ninguna elección de software.

### 2.3 SIMATIC Source Documents (V20 Upd.4 / V21) cambia el juego para la auditoría

Hasta V19, los bloques gráficos (LAD/FBD) solo salían como XML `FlgNet`: un grafo de `<Part>` y `<Wire>` que hay que recorrer para reconstruir la semántica. Un `git diff` de eso es reordenación de nodos XML, ilegible.

Desde **V20 Update 4 / V21**, el workspace del Version Control Interface escribe **SIMATIC Source Documents**: LAD, FBD y SCL como texto, un fichero por bloque. Un `git diff` muestra el cambio funcional, no la reordenación.

**Acción inmediata: comprobar el nivel de update de vuestro V20.** Si estáis por debajo de Update 4, actualizarlo es probablemente la mejora individual más rentable de todo este plan, y es gratis.

### 2.4 Ninguna herramienta open source hace backup antes de escribir

Lo verifiqué específicamente porque es una de tus reglas duras. El mejor modelo de seguridad del ecosistema (`Czarnak/tia-portal-mcp`) tiene tokens preview→apply de un solo uso y audit log, pero **no backup**. Ninguno lo tiene.

Tu regla de `AGENTS.md` está por encima del estado del arte. La implementación tiene que ser vuestra, vía hook `PreToolUse` — y Claude Code soporta `shell: "powershell"` nativamente para eso.

### 2.5 Abrir el repositorio de un cliente con `claude -p` ejecuta el código del cliente

De la documentación de Claude Code, textualmente: sin `--bare`, una sesión `-p` ejecuta los hooks del `.claude/settings.json` del proyecto y conecta los servidores de su `.mcp.json` **incluso en una carpeta en la que nunca has confiado**, sin diálogo de confianza ni aprobación por servidor.

Para auditorías desatendidas de carpetas de cliente esto es un agujero de seguridad de primer orden. La invocación correcta es:

```bash
claude --bare -p "<prompt de auditoría>" \
  --mcp-config ./audit-mcp.json --strict-mcp-config \
  --settings ./audit-settings.json \
  --permission-mode dontAsk --permission-prompts none \
  --output-format json
```

`--bare` no lee credenciales del keychain, así que hay que exportar `ANTHROPIC_API_KEY`. Y el evento `system/init` trae `mcp_server_errors`: si el array no está vacío, hay que fallar el pipeline.

---

## 3. El Top 5

Criterio de selección: no son cinco alternativas entre las que elegir, son **cinco piezas complementarias** que cubren la superficie completa. Cada una ocupa una capa distinta y ninguna sustituye a otra. Se valoran por licencia utilizable comercialmente, madurez real, encaje con tu contrato de `AGENTS.md`, y hueco que tapan.

---

### #1 — `heilingbrunner/tiaportal-mcp` · Motor de lectura e ingeniería

| | |
|---|---|
| URL | https://github.com/heilingbrunner/tiaportal-mcp |
| Licencia | **MIT** |
| Lenguaje | C# / .NET |
| Estrellas | ~97 · ~39 forks |
| Versiones TIA | V21 por defecto; anteriores con `--tia-major-version` |
| Estado en tu stack | **Ya lo usas como `tia-inspect`** |

**Qué aporta.** 56 herramientas de solo lectura siempre disponibles, más 39 de escritura que exigen arrancar con `--allow-write`. Esa separación es exactamente el modelo de perfiles `read`/`write` que ya tienes en `Sync-HarnessConfigs.ps1`, lo cual confirma que elegiste bien.

La herramienta que más valor te da para auditoría es **`GetCrossReferences`**. Con ella se reconstruye el grafo de dependencias de un programa entero: qué bloque llama a qué, qué tag usa quién, y —por diferencia— qué bloques no referencia nadie. Es la base del detector de código muerto sin depender de una herramienta comercial.

Es además doble naturaleza: servidor MCP autónomo y extensión de VS Code, lo que abre la puerta a que un ingeniero trabaje en la misma base sin agente.

**Reserva honesta.** El transporte es solo `stdio`; el stream transport está en el SDK pero no cableado. Para un centro de mando con varias sesiones concurrentes eso limita, aunque tu lease `Local\TIA-Claude-McpSession` ya serializa por otra vía.

**Veredicto: se queda como núcleo de lectura.** No hay razón para cambiarlo.

---

### #2 — `Czarnak/tia-portal-mcp` · Motor de escritura segura

| | |
|---|---|
| URL | https://github.com/Czarnak/tia-portal-mcp |
| Licencia | **MIT** |
| Lenguaje | C# — host .NET 8 + worker .NET Framework 4.8 |
| Estrellas | ~25 · ~10 forks · 376 commits |
| Versiones TIA | **V21** |
| Instalación | `dotnet tool install -g TiaMcpServer` → `tia-mcp doctor` → `tia-mcp install claude-code` |

**Qué aporta, y por qué es el #2.** Resuelve el problema que hoy te tiene bloqueado, y lo resuelve con el mejor modelo de seguridad que existe en el ecosistema:

- **Flujo `preview_write_batch` → `apply_write_batch` con tokens de un solo uso**, ligados al nombre de la herramienta, al target, al input exacto **y al estado actual del proyecto**, con caducidad de 10 minutos. Si el proyecto cambia entre el preview y el apply, el token deja de valer. Eso es más fuerte que un `dryRun` convencional.
- **Audit log** en `%LOCALAPPDATA%\TiaMcpServer\audit`.
- **Read-only por defecto**; `--access-mode read-write` es deliberado.
- 4 herramientas de lectura + 14 de escritura, incluidas `browse_project_tree`, `compile_check`, `execute_read_batch` (hasta 50 lecturas en una llamada, con contenido de bloque, tag tables y cross-references).

**La arquitectura es lo más valioso.** Las DLL de Openness están sobre .NET Framework 4.6.1 y un proceso .NET 8 no puede cargarlas. Czarnak lo resuelve con **dos procesos**: servidor MCP moderno en .NET 8 hablando por IPC con un worker .NET Framework 4.8 que es el único que toca `Siemens.Engineering.dll`. Si en algún momento construís algo propio en .NET, este es el patrón a copiar, no a reinventar.

**Reservas honestas, y son importantes:**
- **Es V21.** Tu entorno declara V20. O convives con ambos binarios, o esto entra cuando migres.
- **No hace backup.** Tendrás que envolverlo con tu hook `PreToolUse`.
- **Sin rollback:** un batch para en el primer fallo y marca los siguientes como *skipped*, pero lo ya aplicado se queda aplicado.
- **Sin soporte PLCSIM y sin descarga a PLC.** Lo declara explícitamente. Para tu contrato eso es una virtud, no un defecto.

**Veredicto: es la pieza que desbloquea el perfil `write`.** Adóptalo cuando toquéis V21, y mientras tanto **cópiale el modelo de tokens preview→apply a tu propio harness**, que hoy tiene preview local pero no el ligado criptográfico al estado del proyecto.

---

### #3 — TIA Scripting Python (oficial Siemens, entry 109742322) · Motor de scripting y batch

| | |
|---|---|
| URL | https://support.industry.siemens.com/cs/document/109742322/ |
| Licencia | Siemens — incluida con TIA Portal, **sin licencia adicional** |
| Lenguaje | Python (wheel) |
| Soporte | **Oficial de Siemens** |
| Versiones TIA | V15.1+ según la versión del wheel (V1.4.3 documentada) |

**Qué aporta.** Es la única vía Python **soportada por el fabricante**. Para un centro de mando esto importa por tres razones concretas:

1. **Ciclo de iteración.** Cada cambio en una herramienta C# es compilar, desplegar binario y reiniciar el MCP. En Python, el agente escribe un script y lo ejecuta. Para tareas de auditoría en lote —recorrer 40 bloques y extraer métricas— la diferencia es de un orden de magnitud en tiempo de desarrollo.
2. **Defendible ante un cliente.** "Usamos la capa de scripting oficial de Siemens" es una frase que se puede decir en una reunión. "Usamos un wrapper de GitHub que su autor no ha podido probar" no lo es.
3. **Es la ruta que ya toma el precedente más cercano a vosotros.** El plugin `Czarnak/totally-integrated-claude` la usa como ruta primaria de Python.

**Complemento recomendado en la misma capa: `Codyte/Tia-Portal-CLI`** (https://github.com/Codyte/Tia-Portal-CLI, MIT, .NET 4.8 x64, **V19–V21**, 436 commits, ~2★). Poca adopción, pero su diseño es exactamente el patrón correcto para un agente: **JSON de entrada y salida, y `dry-run` por defecto** (hay que pasar `--apply` explícitamente para mutar). Además es de los pocos que cubren V19, V20 y V21, lo que ayuda con el problema del version lock. Trátalo como referencia de diseño y como plan B, no como dependencia crítica: 2 estrellas es 2 estrellas.

**Reserva honesta.** No es open source y no está en GitHub: es una descarga de Siemens con su propio ciclo de versiones. Eso es bueno para el soporte y malo para la reproducibilidad de un entorno: hay que versionar el wheel en `30-tools/` y documentar de dónde salió.

**Veredicto: es la capa de scripting del centro de mando.** Complementa a los MCP, no los sustituye — los MCP son la interfaz conversacional del agente, Python es donde se ejecuta el trabajo en lote.

---

### #4 — `Lorenz-Software/PLCSIM.UnitTest` · Motor de verificación

| | |
|---|---|
| URL | https://github.com/Lorenz-Software/PLCSIM.UnitTest |
| Licencia | **MIT** |
| Lenguaje | C# |
| Estrellas | ~12 · ~1 fork |
| Compatibilidad | **PLCSIM Advanced v5.0 / v6.0** · **TIA Openness V16 / V17 / V18** |
| Estado | Release Candidate |

**Por qué está en el Top 5 pese a tener 12 estrellas.** Porque tapa el hueco más grave de tu contrato actual.

Tu checklist de "antes de darte por satisfecho" termina en "compila con 0 errores". Compilar con 0 errores no dice nada sobre si el bloque funciona. Un `CASE` con la transición invertida compila perfectamente. Para que el agente trabaje **de manera autónoma** —que es literalmente lo que pides— hace falta que pueda responder "he probado esto y pasa" en vez de "esto debería funcionar".

Este proyecto es el único open source que combina las tres cosas que necesitas: **Openness** (manipular el proyecto) + **PLCSIM Advanced** (ejecutarlo) + **runner CLI validado en CI** (GitLab). Su arquitectura de plugins permite además compilar el runner sin tener TIA ni PLCSIM instalados, lo que facilita el pipeline.

Y encaja con material que **ya tienes**: PLCSIM Advanced V6.0.0.1 instalado, la regla "PLCSIM sí, libre" de `CLAUDE.md`, y `Write-TiaSimulationReadiness.ps1` ya escrito.

**Reservas honestas:**
- Declara Openness V16/V17/V18. Para V20/V21 hay que verificar o extender el plugin. Es trabajo, pero es trabajo sobre una arquitectura pensada para eso.
- Es Release Candidate.
- PLCSIM Advanced **es licencia de pago aparte**. Las referencias V7.0/V8.0 se venden como "válida para 2 de un máximo de 16 instancias". Ya la tenéis, pero si escaláis a auditorías en paralelo, el coste escala con vosotros.
- Siemens reconoce que PLCSIM Advanced **no reproduce fielmente el timing determinista ni la simulación completa de módulos de I/O**. Un programa dependiente de tiempos de ciclo exactos se comporta distinto. Eso hay que decirlo en cada informe.

**Veredicto: es la pieza que convierte "el agente propone" en "el agente demuestra".** Sin ella, la autonomía que buscas no es defendible.

---

### #5 — La capa de reglas propia · `core-engineering/siemens-plc-tools` + corpus normativo Siemens

| | |
|---|---|
| URL | https://github.com/core-engineering/siemens-plc-tools |
| Licencia | no declarada — **verificar antes de integrar** |
| Lenguaje | Python |
| Estrellas | ~5 · v0.4.0 · ~202 commits · CI/CD activo |
| Versiones TIA | **V21 / S7-1500** |

**Por qué el #5 no es un repositorio sino una capa.** Porque aquí está el hueco real del ecosistema, y por tanto vuestra oportunidad.

Lo que busqué y **no existe**:
- No hay linter de SCL de Siemens.
- No hay Language Server (LSP) para SCL. `vscode-st` lo tiene en roadmap desde hace años, sin implementar.
- **Nadie ha codificado el Programming Styleguide de Siemens como reglas automatizadas.**

`iec-checker` (https://github.com/jubnzv/iec-checker, OCaml, LGPL-3.0, ~107★) es el único analizador estático serio de IEC 61131-3 —26 checks de PLCOpen, código inalcanzable, variables no usadas, salida JSON para CI— pero acepta ST del dialecto `matiec` y **PLCopen XML**, y **TIA Portal no emite PLCopen XML**. Haría falta una capa de traducción SCL→ST. Es el candidato con mejor relación esfuerzo/valor si algún día queréis checks deterministas de flujo.

`core-engineering/siemens-plc-tools` es lo más cercano que existe a lo que queréis: parser SCL, **generación de documentación (MkDocs, Draw.io, PDF)**, **transpilador SCL→Python para tests unitarios con pytest**, tests de integración vía OPC UA/Modbus, validación de listas de E/S, **linting y diff semántico**. Madurez media, 5 estrellas, licencia sin declarar. **No lo tomes como dependencia: tómalo como referencia arquitectónica**, porque es el único que ya combina parser + documentación + diff semántico + tests en un solo diseño.

**El corpus normativo es la parte que aporta valor comercial, y es puro trabajo vuestro:**

| Documento | Entry ID | Qué aporta |
|---|---|---|
| **Programming Styleguide for S7-1200/1500** | **109478084** (v1.1, 06/2015) | Reglas mecanizables: identificadores en inglés sin caracteres especiales, **máx. 24 caracteres**, camelCase, prefijos `inst`/`stat`/`temp`/`type`, constantes en `MAYÚSCULAS_CON_GUION`, arrays en plural, **solo comentarios `//`**, cabecera de bloque obligatoria, **`CASE` siempre con rama `ELSE`**, códigos de error siempre evaluados |
| **Programming Guideline for S7-1200/1500** | **81318674** (v1.6, 12/2018) | Criterios de arquitectura y rendimiento |
| **Programming Guideline Safety** | **109750255** | Reglas específicas de F-blocks |
| **Top 20 Secure PLC Coding Practices v1.0** | ISA, 15-jun-2021 | Checklist vendor-neutral: modularizar, trackear modos de operación, dejar la lógica operativa en el PLC y no en el HMI, flags de integridad, checksums, validar timers/counters, validar entrada de HMI **en el PLC**, bounds checking en indirecciones, plausibilidad física y cruzada, estado seguro en arranque, monitorizar tiempo de ciclo y uso de memoria |

Esas reglas son **directamente automatizables**, nadie las ha automatizado, y son exactamente lo que un cliente industrial español reconoce como "norma Siemens". Un informe de auditoría que diga "37 incumplimientos del Styleguide 109478084, desglosados por bloque" vale dinero. Uno que diga "el código parece correcto" no.

**Veredicto: es la única pieza que hay que construir, y es la que os diferencia.** El resto del Top 5 lo integras; esta la escribes.

---

## 4. Las dos piezas condicionales — capa online

Tu descripción del proyecto menciona "buscar errores que aparezcan cuando nadie tiene disponibilidad para conectarse al programa del cliente". Eso implica contacto con máquina viva, que es un régimen aparte. Lo dejo fuera del Top 5 a propósito, porque **la decisión de si el agente se conecta a un PLC de cliente no es técnica, es contractual**.

### Vía preferente: OPC UA

`opcua-asyncio` (https://github.com/FreeOpcUa/opcua-asyncio, Python, LGPL-3.0, ~1.5k★, `asyncua` 2.0.1 en PyPI el 29-jun-2026) o `node-opcua` (MIT, ~1.7k★, npm 2.186.1 del 21-sep-2026, el más activo del inventario).

OPC UA es la vía correcta porque permite `Browse` del address space —descubrir el modelo de datos sin conocer direcciones absolutas—, usuarios con permisos diferenciados, cifrado, firma y auditoría del lado del servidor. **Nada de eso existe en S7comm clásico.**

Condición: el servidor OPC UA del S7-1500 **no es gratis**. Se licencia por clase de CPU (Small: 1511/1512/1513/ET200SP; Medium: 1515/1516/1507; Large: 1517/1518) y en S7-1200 requiere referencia aparte (`6ES7823-0BA00-2BA0`). Si el cliente no lo tiene licenciado, esta vía no existe en su máquina.

### Vía de compatibilidad: `python-snap7`

https://github.com/gijzelaerr/python-snap7 · MIT · ~845★ · **3.2.0 en PyPI el 21-sep-2026**.

Desde la 3.0.0 es **Python puro**: ya no envuelve la librería C de snap7, implementa la pila completa TPKT/COTP/S7 en Python. Sin toolchain, sin DLL. La 3.2.0 añadió **rate limiting configurable** (token-bucket y fixed-interval), que para no saturar un PLC de cliente es exactamente lo que hace falta.

Condición dura: requiere **PUT/GET activado**, **acceso optimizado desactivado** en cada DB a leer, y nivel **"Full access"**. Los tres están desactivados por defecto en S7-1200/1500 y los tres son degradaciones de la postura de seguridad del cliente. Pedirle a un cliente que active PUT/GET es pedirle que debilite su máquina, y desactivar el acceso optimizado **obliga a recompilar y recargar el programa**, es decir, una parada. Hay que saber justificarlo o no pedirlo.

**Además: desde TIA V17 con firmware S7-1500 ≥ V2.9, la comunicación PG/PC y HMI va por TLS 1.3 y la legacy está desactivada por defecto** (boletín Siemens SSB-898115). En un parque moderno bien mantenido, S7comm clásico simplemente no tiene puerta.

### Regla de oro para esta capa

Primera pasada **siempre pasiva**: captura con el disector S7comm de Wireshark (https://sourceforge.net/projects/s7commwireshark/), que disecciona S7comm y S7comm-Plus **sin emitir un solo paquete hacia el PLC**. Después reconocimiento con `s7scan` (https://github.com/klsecservices/s7scan, ~156★, solo lectura vía SZL — aunque **no declara licencia**, hay que resolverlo antes de integrarlo).

---

## 5. Lo que busqué y NO existe

Tan importante como el inventario. Estos huecos definen dónde no hay que perder tiempo buscando:

1. **No hay MCP server oficial de Siemens para Openness.** El único MCP oficial de Siemens es `@siemens/ix-mcp`, y es RAG sobre la documentación de su design system de UI. Nada que ver con PLC.
2. **No existe ningún parser open source de `FlgNet`** (LAD/FBD en SimaticML XML) hacia texto legible o representación semántica. `Parozzz/TiaUtilities` *genera* LAD desde recetas, pero no lo analiza en sentido inverso. Es el mayor vacío del ecosistema y afecta a todo proyecto en TIA ≤ V19. Copia lo hace, pero es comercial y cerrado.
3. **Ningún servidor open source de TIA Openness descarga a PLC físico.** Solo lo hacen los propietarios. Tu regla de "nunca descargar sin confirmación" coincide con el estado del arte por accidente feliz.
4. **Ninguno implementa backup automático antes de escribir.**
5. **No existe lector open source de ficheros `.ap16`–`.ap21` sin TIA instalado.** `DotNetSiemensPLCToolBoxLibrary` (~467★, LGPL-2.1) lee `.S5D` y `.S7P` de STEP 7 clásico directamente, pero para TIA depende de Openness.
6. **TIA no soporta PLCopen TC6 XML**, lo que impide reutilizar el tooling genérico IEC 61131-3.
7. **No hay XSD público de SimaticML distribuido independientemente**: el esquema vive dentro de la instalación de TIA y cambia con cada versión.
8. No existen, verificado por nombre exacto: `TiaOpennessHelper`, `Openness-Scripting`, `SiemensOpenness`, `TIAOpennessFramework`, `Siemens-Openness-Demo`, ni ninguna *awesome-list* mantenida que cubra Openness. El descubrimiento en este nicho ocurre por GitHub topics, no por listas curadas.

---

## 6. Descartados, y por qué

| Proyecto | Por qué no entra |
|---|---|
| `bulaofen0036-coder/TIA_Portal_Openness_MCP` (tu `tia-create`) | El MCP más grande (~183 tools, V20 **y** V21, incluye Version Control Interface). **No lo descarto: lo mantienes.** No entra en el Top 5 porque el Top 5 son piezas *nuevas* y esta ya la tienes. Su soporte de VCI merece revisión: mapea el proyecto binario a ficheros de texto diffeables |
| `Czarnak/totally-integrated-claude` (~62★, MIT) | **Es el precedente más cercano a lo que tú has construido**: plugin de Claude Code, 19 skills, hook `tia-write-guard.ps1`, skill `plc-code-analysis` que funciona sin TIA instalado, y `tia-doctor`. No entra como dependencia porque duplicaría tu harness, pero **léelo entero antes de escribir una línea más**: resuelve los mismos problemas que tu `AGENTS.md` y puede ahorrarte iteraciones |
| `mking2203/CodeGeneratorOpenness` (~160★) | El comunitario con más tracción en C#, pero **GPL-3.0 viral**. Inaceptable si el resultado se entrega a clientes |
| `Parozzz/TiaUtilities` (~38★) | La mejor generación comunitaria de SimaticML **con LAD**, lo más difícil de replicar. **GPL-3.0**. Y solo V16–V19 |
| `chewcw/tia-portal-openness-mcpserver` (~34★, 60+ tools, V20) | **Licencia no declarada.** Riesgo legal. Además su README cita el grupo de Windows como *"TIA Portal Openness Users"*, que no es el nombre oficial (*"Siemens TIA Openness"*) — señal de imprecisión |
| `a4webdev/tiacommander-mcp` (~32★) | Propietaria. Lee datos vivos del PLC, cubre V17–V20 pero **no V21** |
| `feelautom` / T-IA Connect | El núcleo es cerrado y de pago (desde 10 €/24 h). La extensión VS Code es Elastic License 2.0, source-available pero no OSS |
| `StaniB88/TIAOpennessManager` | **Ya no es open source.** Migró a AnyAutomation Studio, comercial freemium. Tenía detección de código muerto, que es justo lo que os interesa — replicadlo con `GetCrossReferences` |
| `daedalus/mcp-snap7` | **Evitar activamente.** 0 estrellas y expone `plc_stop`, `plc_cold_start` y `plc_hot_start` a un LLM sin ninguna capa de confirmación. Es el ejemplo perfecto de lo que tu `AGENTS.md` prohíbe |
| `awlsim` (~73★) | Simulador S7 real y maduro, pero del mundo **STEP 7 clásico / S7-300/400 / AWL**. No entiende TIA ni S7-1500. Nicho: auditar programas AWL legacy |
| `Repsay/tia-openness-api-client` (~50★, MIT) | Cobertura amplia, pero el autor declara no haber podido probarlo contra TIA. Úsalo como mapa del modelo de objetos, no como dependencia |

---

## 7. Arquitectura del centro de mando

Cinco capas. La regla que las gobierna: **una capa nunca llama a otra más peligrosa sin pasar por su puerta.**

```
┌─ CAPA 5 · GOBIERNO ────────────────────────────────────────────┐
│  AGENTS.md (contrato) · hooks PreToolUse (backup + write-guard) │
│  perfiles read/write/create/full · audit log · lease de sesión  │
│  claude --bare para carpetas de cliente                         │
└────────────────────────────────────────────────────────────────┘
        ↓ toda llamada de las capas inferiores pasa por aquí
┌─ CAPA 4 · REGLAS Y CONOCIMIENTO ───────────────────────────────┐
│  Styleguide 109478084 mecanizado · Top 20 Secure PLC            │
│  10-kb/ (cómo funciona TIA) · 20-standards/ (cómo se hace aquí) │
│  60-library/ (bloques propios probados)                         │
│  ref. arquitectónica: core-engineering/siemens-plc-tools        │
└────────────────────────────────────────────────────────────────┘
┌─ CAPA 3 · VERIFICACIÓN ────────────────────────────────────────┐
│  PLCSIM.UnitTest + PLCSIM Advanced V6 · compile_check           │
│  runner CLI para CI · fixtures desechables                      │
└────────────────────────────────────────────────────────────────┘
┌─ CAPA 2 · EJECUCIÓN ───────────────────────────────────────────┐
│  MCP lectura    tia-inspect (heilingbrunner)     ← por defecto  │
│  MCP escritura  Czarnak/tia-portal-mcp (V21)     ← preview→apply│
│  MCP creación   tia-create (bulaofen, lite)                     │
│  Scripting      TIA Scripting Python (oficial)   ← lote         │
└────────────────────────────────────────────────────────────────┘
┌─ CAPA 1 · SUSTRATO ────────────────────────────────────────────┐
│  TIA Portal V20 (+ V16/V17/V18/V19/V21 si el parque lo exige)   │
│  grupo Windows "Siemens TIA Openness" · .NET Framework 4.8      │
│  git + export textual a src/ · SIMATIC Source Documents si ≥Upd4│
└────────────────────────────────────────────────────────────────┘
        ↓ solo bajo autorización puntual y contractual
┌─ CAPA 0 · MÁQUINA VIVA (condicional, fuera del flujo normal) ──┐
│  Wireshark pasivo → s7scan → OPC UA read-only → python-snap7    │
│  NUNCA: write, force, plc_stop, download, copy_ram_to_rom       │
└────────────────────────────────────────────────────────────────┘
```

---

## 8. Catálogo de tareas y capacidades del agente

Esto es la respuesta a "saber exactamente qué capacidades le podemos otorgar al agente". Cada tarea tiene un nivel de riesgo, unas herramientas permitidas y una puerta que hay que cruzar.

### Niveles de riesgo

| Nivel | Qué toca | Reversible | Puerta |
|---|---|---|---|
| **N0** | Nada. Solo ficheros exportados a texto | Sí | Ninguna |
| **N1** | Lee el proyecto TIA vía Openness, sin escribir | Sí | Doctor OK |
| **N2** | Escribe en un **fixture desechable** | Sí (se tira) | Manifiesto de fixture |
| **N3** | Escribe en el proyecto real | Sí, vía backup | Backup + preview + compilación 0 errores |
| **N4** | Lee un PLC vivo | Sí | Autorización contractual del cliente |
| **N5** | Escribe en un PLC vivo o descarga | **No** | Confirmación humana puntual, siempre |

### Las diez familias de tarea

| # | Tarea | Nivel | Capa que la sirve | Puerta / condición |
|---|---|---|---|---|
| **T1** | **Auditoría offline de proyecto de cliente.** Recorrer el programa entero, mapear bloques, tags, llamadas y dependencias | **N1** | `tia-inspect` (`GetProjectTree`, `GetSoftwareTree`, `GetCrossReferences`) + export a `src/` | Instancia TIA de la versión exacta del cliente. `claude --bare` si se abre su carpeta |
| **T2** | **Documentación / ingeniería inversa.** Generar el documento "cómo funciona esta máquina" a partir del código | **N1** | T1 + capa de reglas + generación MkDocs/Draw.io | Declarar explícitamente el % del programa fuera de alcance por know-how protection |
| **T3** | **Revisión de estilo y normas.** Incumplimientos del Styleguide 109478084 y del Top 20 Secure PLC, con desglose por bloque | **N0** | Capa 4 sobre los `.scl` exportados | Ninguna. **Es la tarea más rentable y la más segura** |
| **T4** | **Detección de código muerto y anomalías.** Bloques sin referencias, tags sin uso, `CASE` sin `ELSE`, errores no evaluados, indirecciones sin bounds check | **N1** | `GetCrossReferences` + reglas | Igual que T1 |
| **T5** | **Desarrollo de bloque SCL nuevo** | **N2** | `New-TiaSclProposal.ps1` → fixture aislado → PLCSIM.UnitTest | Preflight completo: `isFailsafe=false`, `programmingLanguage=SCL`, `isKnowHowProtected=false` leídos del proyecto live |
| **T6** | **Modificación de bloque existente** | **N3** | Czarnak preview→apply + tu hook de backup | Leer el bloque entero antes. Cambio mínimo. Compilar 0 errores o revertir |
| **T7** | **Creación de proyecto, hardware, red, HMI** | **N3** | `tia-create` perfil `lite` | Reconocimiento explícito del perfil + `dryRun` cuando exista |
| **T8** | **Verificación funcional en PLCSIM** | **N2** | PLCSIM.UnitTest + PLCSIM Advanced | `plcsimVirtualAdapterReady=true` y target virtual desechable identificado |
| **T9** | **Diagnóstico online de solo lectura** | **N4** | Wireshark pasivo → s7scan → OPC UA read-only | **Autorización escrita del cliente.** Lista **blanca** de funciones a nivel de código. Rate limiting obligatorio. Una sola conexión reutilizada |
| **T10** | **Vigilancia desatendida / auditorías programadas** | **N0–N1** | `claude --bare -p` + tarea programada + gate sobre `mcp_server_errors` | Solo tareas N0/N1. **Una tarea desatendida nunca cruza a N2 o superior** |

### Lo que el agente no hace nunca sin ti delante

- Descargar a hardware físico (ya está en tu `AGENTS.md`).
- `force` / `cancel_force` sobre un PLC vivo. Esto merece mención aparte: aunque el agente "solo esté mirando", un force deja el PLC en **estado forzado persistente que sobrevive a la desconexión** y que un operario puede tardar horas en diagnosticar. Lista negra explícita, no convención.
- `plc_stop`, `plc_cold_start`, `plc_hot_start`, `copy_ram_to_rom`, `compress`, `set_plc_datetime`.
- Descubrimiento PROFINET/DCP en red de producción: puede provocar parpadeo de LEDs, entradas de diagnóstico y, mal usado, reasignación de nombres e IPs.
- Tocar F-blocks, tags Safety o bloques con know-how protection.

---

## 9. Riesgos que hay que declarar, no mitigar

Algunos no tienen solución técnica y hay que ponerlos por escrito en cada informe.

**Punto ciego absoluto: know-how protection y proyectos con contraseña.** Ni Openness, ni Copia, ni ninguna herramienta puede auditar esos bloques. Se exportan, pero el XML sale sin el contenido protegido. **Cualquier informe de auditoría debe declarar qué porcentaje del programa quedó fuera de alcance por esta causa.** Un informe que no lo diga es un informe que miente por omisión.

**Daño sin escribir nada.** El modo de fallo más probable y más caro de una conexión online no es escribir algo: es **agotar los recursos de conexión del PLC**. Un S7-1500 tiene un número finito. Si el agente abre conexiones y no las cierra limpiamente, o reintenta en bucle tras un fallo, puede dejar sin conexión al HMI o al SCADA del cliente. El segundo es la **carga de CPU por polling**: en una CPU al límite puede disparar el watchdog de ciclo y parar la máquina. Que la operación sea de lectura no la hace gratis.

**Ruido en el diagnóstico.** Conexiones y desconexiones repetidas ensucian el búfer de diagnóstico de la CPU, que es exactamente donde el técnico va a mirar después para investigar el fallo que ibais a auditar.

**PLCSIM Advanced no es la máquina.** Siemens reconoce que no reproduce timing determinista ni simulación completa de I/O. Un test que pasa en PLCSIM no es un test que pasa en planta.

**Responsabilidad contractual.** Conectarse a la máquina de un cliente sin autorización escrita tiene implicaciones de seguro y de seguridad funcional. Si la instalación tiene marcado CE y evaluación de riesgos, una intervención no documentada puede invalidar responsabilidades. Si hay F-CPU, es un régimen aparte.

---

## 10. Plan por fases

**Fase 0 — Reconfigurar y verificar ESTE equipo.**
Los siete puntos de §1.5. Decidir la salida A / B / C. Decidir el parque de versiones de TIA a soportar, que es la restricción más cara de todas. Nada de lo que afirma hoy `AGENTS.md` sobre el entorno vale aquí hasta que un `Doctor` local lo diga.

**Fase 1 — Cerrar el hueco más rentable y más seguro: T3.**
Codificar el Styleguide 109478084 y el Top 20 Secure PLC como reglas sobre los `.scl` exportados. Es **N0**: no toca TIA, no toca máquinas, no puede romper nada. Y es lo primero que un cliente puede ver y valorar. Empezar por aquí también valida el flujo de export sin arriesgar nada.

**Fase 2 — Verificación.**
Integrar PLCSIM.UnitTest y extender su plugin a Openness V20. A partir de aquí el agente puede demostrar en vez de suponer.

**Fase 3 — Desbloquear la escritura.**
Leer entero `Czarnak/totally-integrated-claude` antes de escribir nada más. Adoptar el modelo de tokens preview→apply en tu harness, y evaluar `Czarnak/tia-portal-mcp` cuando migréis a V21.

**Fase 4 — Scripting en lote.**
Incorporar TIA Scripting Python versionado en `30-tools/` para las tareas T1/T2/T4 sobre proyectos grandes.

**Fase 5 — Desatendido.**
Auditorías programadas con `claude --bare -p`, limitadas a N0/N1, con gate de CI sobre `mcp_server_errors`.

**Fase 6 — Online, solo si el negocio lo pide.**
Y solo con autorización escrita, empezando por la pasada pasiva de Wireshark.

---

## 11. Lo que necesito que decidas

Seis cosas que no puedo decidir por ti y que condicionan todo lo anterior:

1. **Salida A, B o C para este equipo** (§1.5). Es la decisión bloqueante: hasta que se tome, aquí no hay Openness de ninguna clase. Mi recomendación es C ahora y A en paralelo.
2. **¿Qué versiones de TIA hay en vuestro parque de clientes?** Determina cuántas instalaciones y binarios necesitáis, y si la ruta V18 de la salida B tiene sentido estratégico. Es la restricción más cara.
3. **¿Vais a migrar a V21?** De ello depende que `Czarnak/tia-portal-mcp` y SIMATIC Source Documents entren en el plan ahora o dentro de un año.
4. **¿El centro de mando se queda en casa o se entrega/vende a clientes?** Cambia qué licencias son aceptables: hoy descarté GPL-3.0 y licencias sin declarar por defecto, pero para uso interno son negociables.
5. **¿La capa online entra en alcance?** Si la respuesta es "solo si el cliente lo pide", la dejamos preparada pero desactivada. Si es "sí, es parte del servicio", hay que resolver antes el tema de licencias OPC UA y las autorizaciones contractuales.
6. **¿Prioridad: profundidad en un cliente o cobertura de muchos?** La auditoría en lote (T1–T4) y el desarrollo asistido (T5–T8) tiran de la arquitectura en direcciones distintas.

---

## 12. Fuentes

**Top 5**
https://github.com/heilingbrunner/tiaportal-mcp ·
https://github.com/Czarnak/tia-portal-mcp ·
https://support.industry.siemens.com/cs/document/109742322/tool-for-easier-use-of-the-tia-portal-openness-interface-(tia-scripting-python) ·
https://github.com/Codyte/Tia-Portal-CLI ·
https://github.com/Lorenz-Software/PLCSIM.UnitTest ·
https://github.com/core-engineering/siemens-plc-tools ·
https://github.com/jubnzv/iec-checker

**Oficial Siemens**
https://docs.tia.siemens.cloud/r/en-us/v21/tia-portal-openness-api-for-automation-of-engineering-workflows ·
https://github.com/siemens/tia-portal-openness-code-snippets ·
https://github.com/tia-portal-applications/tia-portal-openness-unified-library ·
https://support.industry.siemens.com/cs/document/109760816/tia-portal-openness-explorer ·
https://cache.industry.siemens.com/dl/files/802/109773802/att_1007204/v1/TIAPortalOpenness_en-US.pdf ·
https://cache.industry.siemens.com/dl/files/692/108716692/att_1353336/v1/108716692_TIA_PortalOpenness_GettingStartedAndDemo_V21_en.pdf ·
Styleguide 109478084: https://support.industry.siemens.com/cs/document/109478084/programming-styleguide-for-s7-1200-s7-1500 ·
Programming Guideline 81318674: https://cache.industry.siemens.com/dl/files/040/90885040/att_970576/v1/81318674_Programming_guideline_DOC_v16_en.pdf ·
Add-In VCI Git Connector 109773999: https://support.industry.siemens.com/cs/attachments/109773999/109773999_TIA_Add-In_VCI_Git_Connector_DOC_v1.0.0_en.pdf ·
Boletín TLS SSB-898115: https://cert-portal.siemens.com/productcert/html/ssb-898115.html

**Ecosistema MCP / IA**
https://github.com/Czarnak/totally-integrated-claude ·
https://github.com/bulaofen0036-coder/TIA_Portal_Openness_MCP ·
https://github.com/chewcw/tia-portal-openness-mcpserver ·
https://github.com/a4webdev/tiacommander-mcp ·
https://github.com/feelautom/tia-copilot-genai-bridge ·
https://github.com/Edge-JB/TwinCAT-XAE-MCP (análogo Beckhoff; arquitectura daemon + named pipe + dialog watchdog, muy copiable)

**Comunicación y simulación**
https://github.com/gijzelaerr/python-snap7 ·
https://github.com/gijzelaerr/s7commplus ·
https://github.com/FreeOpcUa/opcua-asyncio ·
https://github.com/node-opcua/node-opcua ·
https://github.com/OPCFoundation/UA-.NETStandard (hoy **MIT**, ya no RCL) ·
https://github.com/klsecservices/s7scan ·
https://sourceforge.net/projects/s7commwireshark/ ·
https://github.com/mushorg/conpot (honeypot ICS, diana segura para tests) ·
https://github.com/mbuesch/awlsim

**Código como texto / versionado**
https://github.com/IgorCoraine/TIA_Add-In_VCI_Git_Connector ·
https://github.com/Parozzz/TiaUtilities ·
https://github.com/caprican/SimaticML ·
https://github.com/TUM-AIS/IEC611313ANTLRParser ·
https://github.com/Serhioromano/vscode-st ·
https://github.com/dotnetprojects/DotNetSiemensPLCToolBoxLibrary ·
https://www.dmcinfo.com/latest-thinking/blog/id/9908/how-to-read-an-openness-xml-file

**Documentación de agentes**
https://code.claude.com/docs/en/mcp ·
https://code.claude.com/docs/en/hooks ·
https://code.claude.com/docs/en/permissions ·
https://code.claude.com/docs/en/sub-agents ·
https://code.claude.com/docs/en/headless ·
https://learn.chatgpt.com/docs/extend/mcp?surface=cli (Codex) ·
https://opencode.ai/docs/mcp-servers/

**Investigación académica**
LLM4PLC (ICSE SEIP 2024) https://arxiv.org/abs/2401.05443 ·
Agents4PLC https://arxiv.org/abs/2410.14209 · repo https://github.com/Luoji-zju/Agents4PLC_release ·
AutoPLC (SCL Siemens + CODESYS, 914 tareas) https://arxiv.org/abs/2412.02410 ·
Ladder Logic Translation (Rockwell L5X → SimaticXML vía Openness) https://arxiv.org/abs/2605.31458 ·
PLCBench (seguridad, hardware-in-the-loop) https://arxiv.org/abs/2608.26882
