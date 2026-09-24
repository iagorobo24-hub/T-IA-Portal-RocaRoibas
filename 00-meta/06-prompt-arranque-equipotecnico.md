# Prompt de arranque para Claude Code en `equipotecnico`

Sesión de puesta en marcha y adaptación del workspace a este equipo. Es un prompt **de una sola
vez**: cuando el entorno quede verificado y reconfigurado, se vuelve al prompt operativo normal de
`TIA-Claude_Portable/docs/prompt-claude-code.md`.

**Cómo usarlo.** Abrir Claude Code con el directorio de trabajo en
`C:\Users\Dpto. Técnico\Documents\TIA-Claude` y pegar el bloque completo de abajo.

**Antes de pegarlo**, dos comprobaciones de treinta segundos: que el repo esté limpio
(`git status`) y que exista una rama o un commit al que volver. Esta sesión va a tocar
configuración y, en la fase D, código de build.

---

```text
Estás en la raíz del workspace TIA-Claude, en el equipo `equipotecnico`, usuario Windows
`Dpto. Técnico`. Este workspace se acaba de copiar desde otro ordenador y NO está verificado aquí.

Lee primero, en este orden y enteros:
  AGENTS.md
  00-meta/decisiones/ADR-015-estado-equipo-equipotecnico.md
  00-meta/decisiones/ADR-016-consolidacion-portable.md
  70-runs/entorno/20260922-equipotecnico-inventario.md
  00-meta/05-comparacion-portable-2026-09-22.md

AVISO QUE MANDA SOBRE AGENTS.md: la sección 9 de AGENTS.md ("Estado del entorno") describe OTRO
ordenador. Afirma TIA V20, PLCSIM V19 y PLCSIM Advanced V6.0.0.1 verificados. Aquí NO hay V19, V20
ni V21: hay V15.1, V16, V17 y V18. Los binarios MCP del workspace están compilados contra Openness
V20 y no pueden cargar en esta máquina. El fichero
`30-tools/mcp/tia-create/bin/v20/TiaMcpServer.startup.log`, que registra arranques correctos y
pertenencia al grupo `Siemens TIA Openness`, es de la otra máquina: todas sus entradas llevan
`BaseDir: C:\Users\jose.mellid\...`. No lo uses como evidencia de nada.

Todo lo que el repo afirme sobre el entorno es HIPÓTESIS hasta que lo verifiques aquí.

OBJETIVO DE LA SESIÓN
Dejar este equipo en un estado conocido: entorno inventariado con evidencia local, configuración
apuntando a rutas de esta máquina, consolidación de las dos copias de TIA-Claude_Portable, y un
informe honesto de viabilidad para conectar Openness a las versiones que SÍ están instaladas aquí
(V18 primero, luego V17/V16/V15.1).

REGLAS DURAS DE ESTA SESIÓN
- Siguen vigentes todas las reglas de AGENTS.md §3. Nada de descargas a hardware físico.
- No borres ningún fichero. Si algo sobra, muévelo a `90-tmp/_to_delete/` y repórtalo.
- No modifiques ficheros existentes en las fases A, B y C salvo los cuatro de configuración que se
  nombran explícitamente en la fase B.
- No intentes arrancar los binarios `bin/v20/` esperando que funcionen. Si los ejecutas, es para
  capturar el error, no para usarlos.
- Clasifica cada resultado como VERIFICADO / SUPUESTO / NO VERIFICADO / BLOQUEADO, con la evidencia
  y el siguiente paso. Compilar no es funcionar; instalar no es licenciado.
- Al final de cada fase, PARA y resume antes de seguir. No encadenes fases sin que yo lo diga.

═══════════════════════════════════════════════════════════════════════════
FASE A — INVENTARIO Y DIAGNÓSTICO (solo lectura, no toques nada)
═══════════════════════════════════════════════════════════════════════════

A1. Versiones de TIA realmente instaladas y utilizables. Para cada carpeta
    `C:\Program Files\Siemens\Automation\Portal V*`, comprueba si existe
    `PublicAPI\V<n>\Siemens.Engineering.dll` y anota su versión de fichero. Una carpeta de producto
    no prueba que Openness esté instalado: el componente Openness es opcional en el setup.
    Reporta tabla: versión / ruta / existe Engineering.dll sí-no / versión del DLL.

A2. Nivel de update de cada TIA instalado. Si no hay forma fiable por línea de comandos, dilo y
    deja la comprobación como manual para mí.

A3. Grupo de Windows. Ejecuta `net localgroup "Siemens TIA Openness"` y di literalmente si el
    usuario actual (`whoami`) aparece. Si no aparece: NO lo añadas tú. Dime el comando exacto que
    tengo que ejecutar como administrador y recuérdame que hay que cerrar sesión y volver a entrar.

A4. PLCSIM Advanced. Localiza
    `C:\Program Files (x86)\Common Files\Siemens\PLCSIMADV\API\<ver>\Siemens.Simatic.Simulation.Runtime.Api.x64.dll`,
    anota la versión de la API y contra qué TIA está emparejada. Comprueba también qué hay en
    `C:\Program Files (x86)\Siemens\Automation\PLCSIMADV`.

A5. Toolchain. Versión de .NET SDK (`dotnet --info`), .NET Framework Developer Pack 4.8/4.8.1,
    PowerShell, git, y si hay Visual Studio Build Tools con carga de C++.

A6. Intento de arranque controlado. Ejecuta
    `30-tools\mcp\tia-inspect\bin\v20\TiaMcpServer.exe --tia-major-version 20 --doctor`
    y captura la salida COMPLETA, incluido stderr. Espero que falle; quiero el error exacto para
    confirmar que la causa es la ausencia de V20 y no otra cosa.

A7. Escribe todo en `70-runs/doctor/equipotecnico.json` (JSON estructurado) y un resumen legible en
    `70-runs/doctor/equipotecnico.md`. Este par de ficheros pasa a ser la fuente de verdad del
    entorno de esta máquina.

PARA AQUÍ. Resume: qué versiones de Openness hay realmente utilizables, si el grupo está resuelto,
y qué versión de PLCSIM Advanced hay.

═══════════════════════════════════════════════════════════════════════════
FASE B — RECONFIGURACIÓN DE RUTAS (reversible, commit aparte)
═══════════════════════════════════════════════════════════════════════════

B1. Archiva la evidencia heredada: mueve
    `30-tools/mcp/tia-create/bin/v20/TiaMcpServer.startup.log`
    a `70-runs/heredado/jose.mellid-TiaMcpServer.startup.log` y añade al lado un `LEEME.md` de dos
    líneas diciendo que es de otra máquina y no vale como verificación.

B2. Regenera la configuración con rutas de este equipo, usando el script del workspace y NO a mano:
    `30-tools\scripts\Sync-HarnessConfigs.ps1 -WorkspaceRoot (Get-Location).Path -Profile read`
    Antes de ejecutarlo, léelo entero y dime qué ficheros va a tocar. Deben quedar apuntando a
    `C:\Users\Dpto. Técnico\Documents\TIA-Claude\...`, nunca a `jose.mellid`.
    Afecta al menos a `.mcp.json` y a `30-tools/mcp/servers.local.json`.

B3. Busca en TODO el repo cualquier otra ruta absoluta de la máquina anterior
    (`jose.mellid`, `C:\TIA-Claude`, u otras rutas absolutas hardcodeadas) y repórtalas en una lista.
    No las cambies aún: dime dónde están y qué propones para cada una.

B4. Anota en `servers.json` que el perfil V20 no es ejecutable en este equipo, sin borrar la entrada:
    es válida para el otro ordenador. Añade un campo de estado por máquina si el esquema lo permite;
    si no, propón el cambio de esquema y espera mi visto bueno.

PARA AQUÍ. Enséñame el diff completo antes de commitear.

═══════════════════════════════════════════════════════════════════════════
FASE C — CONSOLIDACIÓN DE LAS DOS `TIA-Claude_Portable`
═══════════════════════════════════════════════════════════════════════════

Contexto ya resuelto en ADR-016: manda la copia INTERNA
(`TIA-Claude\TIA-Claude_Portable`). La SUELTA (`Documents\TIA-Claude_Portable`) es una salida
generada el 2026-09-15 que se autodeclara legacy y trae un `workspace/` obsoleto.

C1. Verifica el veredicto antes de actuar: compara `manifests/package-info.json` de ambas y
    confirma que la interna tiene `metadataRole: "build-input-template"` y `generatedUtc: null`, y
    que la suelta tiene `legacyMonolithicWorkspace: "workspace/"`. Si no cuadra, PARA y dímelo.

C2. Rescata `Documents\TIA-Claude_Portable\workspace\_ref\` → `TIA-Claude\_ref\`.
    Son clones de siete repos de terceros (PLC_Projects, TIA_Portal_Openness_MCP, tia-integration-ai,
    tia-portal-mcp, tia-portal-openness-code-snippets, tiaportal-mcp, TIAPortalGames).
    Usa `Move-Item` sin sobrescribir. Añade `_ref/` al `.gitignore`: es código ajeno con licencias
    propias y no se versiona en nuestro repo. Deja un `_ref/LEEME.md` con el origen y la licencia de
    cada uno.

C3. Rescata `Documents\TIA-Claude_Portable\Prompt.txt` → `00-meta/encargo-original.txt`.

C4. NO promuevas nada más de la suelta. Su `workspace/AGENTS.md` (10 281 B) es una regresión frente
    al vivo (15 942 B).

C5. Cuando C2 y C3 estén confirmados, NO borres la carpeta suelta. Dime que está lista para que la
    borre yo, con el tamaño que ocupa.

PARA AQUÍ.

═══════════════════════════════════════════════════════════════════════════
FASE D — VIABILIDAD DE OPENNESS EN V18 (investigar y REPORTAR, no ejecutar)
═══════════════════════════════════════════════════════════════════════════

Esto NO es un cambio de configuración, es un port. Quiero el estudio antes que el código.

Punto de partida, de `30-tools/mcp/tia-inspect/build.ps1`:
  - `[ValidateSet(20, 21)]`, por defecto 20.
  - Mapa de paquetes NuGet solo con 19, 20 y 21.
  - Documenta: "V19 AÚN NO está soportado: la API de documentos SIMATIC SD (.s7dcl/.s7res) no existe
    antes de Openness V20 y habría que compilar fuera toda esa funcionalidad. Ver ADR-002."

D1. Lee ADR-002 entero y resume qué se descartó exactamente y por qué.

D2. Averigua si existe el paquete NuGet
    `Siemens.Collaboration.Net.TiaPortal.Packages.Openness` en versión `18.0.x`, y cuál. Búscalo en
    nuget.org. Si no existe, la vía B muere ahí y hay que decirlo claramente.

D3. Inventaria el coste real del port. Recorre `30-tools/mcp/tia-inspect/upstream/src/` y lista los
    ficheros y símbolos que dependen de APIs de Openness V19+ o V20+. Como mínimo revisa:
      - `McpServer.Documents.cs`, `Portal.Documents.cs`, `McpServerWrite.Documents.cs`
        (SIMATIC Source Documents — .s7dcl/.s7res, no existen antes de V20)
      - `Portal.Write.cs` → `RenameWatchTable` tras `#if TIA_V21_PLUS`
      - `Diagnostics.cs` → suelo de detección de versión
      - `Portal.GenerateSource.cs`, `Portal.ExternalSources.cs`, `Portal.Safety.cs`,
        `Portal.CrossReferences.cs`
    Para cada uno: ¿se puede compilar fuera con un `#if`, o está entretejido?

D4. Di qué se PIERDE en V18 si se hace el port. Me interesa especialmente: ¿queda export textual
    utilizable (`.scl`/`.db`/`.udt` vía generate-source), o solo XML SimaticML? ¿Sobrevive
    `GetCrossReferences`? Sin cross-references no hay detección de código muerto y la auditoría
    pierde su mejor herramienta.

D5. Comprueba lo mismo, en corto, para V17, V16 y V15.1. Quiero saber hasta dónde baja el suelo
    realista, no solo si V18 es posible.

D6. Escribe el informe en `00-meta/07-viabilidad-openness-v15-v18.md` con una recomendación clara:
    portar, no portar, o portar solo un subconjunto de lectura.

PARA AQUÍ. No escribas una línea de código de port sin que yo lo apruebe leyendo D6.

═══════════════════════════════════════════════════════════════════════════
FASE E — SOLO SI APRUEBO D6: BUILD V18
═══════════════════════════════════════════════════════════════════════════

E1. Rama nueva (`feat/openness-v18`). Nada de esto toca `master`.
E2. Extiende `build.ps1`: `ValidateSet` y mapa de paquetes NuGet. Sin tocar la ruta V20/V21.
E3. Aplica los recortes acordados en D6 tras `#if`, no borrando código.
E4. Compila y captura errores y avisos con su número exacto.
E5. Ejecuta `--doctor` contra V18 y captura la salida entera.
E6. Prepara un fixture V18 desechable: el actual `TestProject1.zap20` es V20 y no abre aquí.
    Necesito un `.ap18` de prueba propio, nunca un proyecto de cliente ni un original de
    `50-examples/`. Genera su manifiesto con `New-TiaFixtureManifest.ps1`.
E7. Smoke test de SOLO LECTURA sobre el fixture: Doctor, Connect, GetProjectTree, GetSoftwareTree,
    GetBlocks y un export textual. Nada de escritura en esta fase.
E8. Guarda toda la evidencia en `70-runs/v18/`.

═══════════════════════════════════════════════════════════════════════════
INFORME FINAL
═══════════════════════════════════════════════════════════════════════════

Termina con cuatro listas separadas — VERIFICADO, SUPUESTO, NO VERIFICADO, BLOQUEADO — cada línea
con su ruta de evidencia. Y responde explícitamente a estas cinco:

1. ¿Qué versiones de Openness son realmente utilizables en este equipo, con DLL comprobado?
2. ¿Está el usuario en el grupo `Siemens TIA Openness`? Si no, ¿qué tengo que hacer yo?
3. ¿Qué versión de PLCSIM Advanced hay y con qué TIA está emparejada?
4. ¿Es viable V18, a qué coste y perdiendo qué?
5. ¿Qué queda pendiente que necesite una decisión mía y no tuya?

No cierres la sesión afirmando que algo funciona si no lo has ejecutado y observado.
```

---

## Qué NO está en este prompt, a propósito

- **Nada de escritura en proyectos TIA.** Esta sesión no es para programar, es para dejar el equipo
  en un estado conocido.
- **Nada de instalar TIA V20.** Es una decisión de licencia y de negocio (ADR-015, salida A), no algo
  que un agente deba proponer resolver por su cuenta.
- **Nada de borrar.** Todo lo que sobra se mueve y se reporta.
- **Nada de la capa de reglas** (Styleguide 109478084 + Top 20 Secure PLC). Es la siguiente sesión, y
  es la única que no depende de resolver nada de lo anterior: trabaja sobre `.scl` exportados y no
  necesita Openness. Ver `00-meta/04-ecosistema-open-source-2026-09.md` §3 pieza 5 y §10 fase 1.
