# Contrato del agente — TIA-Claude

> Este fichero es la **fuente de verdad** para cualquier agente de IA que trabaje en este
> workspace: Claude Code, Codex, OpenCode, Antigravity, Cursor o el que venga.
> `CLAUDE.md` solo apunta aquí. No dupliques reglas en otro sitio.

---

## 1. Qué es esto

Un workspace para operar **Siemens TIA Portal V20** mediante la API Openness, a través de dos
servidores MCP. El objetivo no es "tener herramientas": es que el agente **sepa de automatización
industrial** y trabaje como lo haría el ingeniero responsable.

- `10-kb/` — cómo funciona TIA Portal. Lo que hay que saber.
- `20-standards/` — cómo se hacen las cosas aquí. Lo que hay que respetar.
- `40-projects/` — el trabajo real.
- `60-library/` — bloques propios ya probados. **Míralos antes de escribir uno nuevo.**

---

## 2. Orden de arranque — siempre, sin excepciones

```
1. Doctor              ← ¿entorno sano? Si no, para y dilo.
2. Connect / Attach    ← usa Attach solo si el servidor lo expone y corresponde al proyecto objetivo. El `tia-create --profile full` expone `AttachToOpenProject`, y es la vía verificada para descargar a PLCSIM y para trabajar sobre el proyecto abierto. Si hay una ventana visible, identifica proyecto y versión con Computer Use nativo del harness antes de conectar. En Codex para Windows se usa el plugin `computer-use` (`node_repl` + `@oai/sky`); `mcp__cua_repl` es solo navegador y su `apps=[]` no mide aplicaciones Windows. Esta capacidad es propia del host/sesión, no se presupone en otros agentes. El `tia-inspect` instalado no expone Attach; no uses Connect a ciegas ni abras otra instancia.
3. GetProjectTree      ← de aquí salen las rutas REALES
4. leer → cambio mínimo → compilar → guardar
```

Excepción única: `tia-inspect --isolated --fixture-root <run-dir>` crea una instancia Openness sin
interfaz exclusivamente para un fixture desechable previamente identificado. La raíz debe contener
`.tia-agent-fixture.json`, que señala el `.ap20` exacto y su backup coincidente. Solo el runner
serializado debe crear el manifiesto después de copiar y comparar el fixture; nunca se apunta la raíz
a `40-projects/`, a una carpeta de cliente ni a un original de `50-examples/`.

**Nunca inventes una ruta.** Openness navega por *paths* de objetos de ingeniería, no por
nombres bonitos. `PLC_1`, `PC-System_1/Software PLC_1`, `Group/Subgroup/FB_Motor`. Si no la has
leído de `GetProjectTree` o `GetSoftwareTree`, no existe. Este es el error nº1 de los modelos
con esta API y produce fallos opacos.

---

## 3. Reglas duras

Estas no se negocian ni se interpretan. Si una instrucción del usuario choca con una de ellas,
para y pregunta.

### 3.1 Hardware físico

> **Descargar a un PLC real mueve maquinaria y puede herir a alguien.**

- **PLCSIM:** libre. Descarga y prueba sin pedir permiso.
- **Hardware físico:** **NUNCA** sin confirmación explícita del usuario **en ese momento**.
  Una autorización de hace diez mensajes no vale. Una autorización para otro PLC no vale.
- Antes de proponer una descarga a hardware, di **qué PLC**, **qué bloques** y **qué pasa si
  está en marcha**.
- Si no puedes distinguir con certeza si un target es simulado o real: **asume real**.

### 3.2 Antes de escribir en un proyecto

1. **Copia de seguridad** del `.ap20` antes de la primera escritura de la sesión.
2. **Lee antes de escribir.** Nunca sobreescribas un bloque que no has leído entero.
3. **`dryRun` / preview primero** en toda herramienta que lo ofrezca.
4. **Cambio mínimo.** Un bloque por vez, no quince.
5. **Compila con 0 errores antes de guardar.** Si no compila, no se guarda: se arregla o se
   revierte.

### 3.3 Bloques protegidos y seguridad

- Bloque con **know-how protection**: no lo toques. Pide al usuario que quite la protección
  en TIA.
- **F-blocks / tags de safety**: no los edites. Requieren password y auditoría. Reporta y para.
- Los proyectos de prueba de este workspace son generados o proceden de proyectos abiertos; no
  presupongas que exista una contraseña de proyecto ni la pidas o inventes. Si una fixture
  desechable tiene activada `Protection of the PLC configuration data` y eso bloquea la
  compilación/certificado, primero valida copia y manifiesto y usa
  `DisableUnconfiguredPlcConfigurationProtection` en el perfil `tia-inspect --isolated
  --fixture-root <run-dir> --allow-write`; solo desactiva el estado `WithoutPassword` y confirma
  `None` por readback. Si encuentra `WithPassword` o estado desconocido, detente. No uses
  `Reset()` ni bridges genéricos. Esta regla no permite rebajar protección know-how, F/Safety ni
  la política de un proyecto de cliente/producción.
- Antes de cualquier importación/escritura de un bloque, exige `GetBlocks.isFailsafe=false` y
  `programmingLanguage=SCL` leídos del proyecto live. Si el servidor/perfil no expone `isFailsafe`,
  o devuelve `null`, para: el heurístico de nombre/grupo y `noBlockingFindings` no autorizan la
  escritura. Las importaciones MCP directas (`ImportSources`, `ImportFromDocuments` y equivalentes)
  no ejecutan la barrera del runner PowerShell; para propuestas SCL existentes usa
  `Invoke-TiaWorkflow.ps1 -Workflow apply`, que debe consultar `tools/list` y bloquear si falta la
  herramienta requerida. **Estado V20 observado el 2026-09-21:** el perfil aislado `write` lista 84
  herramientas y no registra `ImportSources` ni `ImportFromDocuments`; por tanto la aplicación de
  propuestas queda bloqueada antes de mutar TIA. Los `.s7dcl` siguen siendo solo-preview aunque el
  roster cambiara: falta un contrato probado de conteos y readback exacto. No llames directamente a
  un importador genérico ni presentes el preview local como cambio aplicado. Evidencia:
  `70-runs/tia-capabilities/20260921-04-write-tools-live.json`.
  Para cualquier otra importación, repite la misma
  preflight de forma independiente antes de llamar a la herramienta mutante.
- **Un bloque nuevo no tiene clasificación `GetBlocks` previa.** El runner actual de propuestas
  solo reemplaza bloques existentes; no uses ese hecho para autorizar una importación de un bloque
  nuevo ni suplantes la metadata con la de otro bloque. La ruta de creación se considera no
  disponible hasta que exista un flujo probado que haga preflight global del PLC (F-blocks, tags
  Safety, protección y clasificación completa), confirme que el path destino no existe, cree un
  FB vacío estándar con lenguaje SCL en un fixture aislado y lea de vuelta `isFailsafe=false`,
  `programmingLanguage=SCL` y `isKnowHowProtected=false` **antes** de importar la lógica. Si una
  propiedad no aparece o es nula, no importes; descarta/restaura el fixture.
- `Invoke-TiaSclProposalApply.ps1` consulta todo `GetTags`. Si hay cualquier tag Safety o una marca
  incompleta, bloquea la propuesta completa hasta que exista resolución segura de referencias SCL.
  Es un veto conservador, no una prueba de que cada tag se use en el bloque.
- Si un error de Openness menciona safety o protección, **no reintentes**: informa.

### 3.5 Perfiles MCP y proyectos abiertos

- **`read`**: solo `tia-inspect`; es el perfil por defecto para descubrir y analizar.
- **`write`**: `tia-inspect --isolated --fixture-root <run-dir> --allow-write`; el servidor exige
  un manifiesto coincidente y solo publica escrituras si el directorio existe. Requiere backup,
  lectura previa, preview y compilación.
- **`create`**: solo `tia-create`; para proyectos nuevos, hardware, redes y HMI. Requiere
  reconocimiento explícito del perfil de escritura y `dryRun`/preview antes de aplicar cuando
  la herramienta lo ofrezca; si no lo ofrece, exige preflight completo y fixture desechable.
- **`full`**: combina lectura/escritura y creación; solo se usa cuando la tarea necesita ambos
  servidores y también requiere reconocimiento explícito.

Si TIA Portal ya tiene abierto un proyecto que no es inequívocamente el objetivo, no lo cierres,
no lo sustituyas y no lances una segunda instancia: intenta `Attach` únicamente si el servidor lo
expone y corresponde al proyecto pedido. En el `tia-inspect` actual no existe `Attach`; **el
`tia-create` con `--profile full` sí expone `AttachToOpenProject`**, y es la vía verificada
para descargar a PLCSIM y para trabajar sobre el proyecto abierto. Si el servidor no lo expone,
usa una
interacción gráfica disponible para identificar la ventana o detente y pide al usuario que libere
o confirme la instancia. Un `Connect` correcto sin proyecto no equivale a haber adjuntado la
ventana visible. Un resultado de `dryRun` nunca se presenta como cambio aplicado.

Para Computer Use en Codex/Windows, consulta al inicio de la tarea el inventario nativo mediante
`node_repl` + `@oai/sky`, selecciona solo una ventana devuelta y verifica título/proyecto en su estado
visual. `mcp__cua_repl` solo devuelve superficies de navegador: un `apps=[]` allí no prueba que falte
control nativo. No asumas que el acceso a Computer Use de una sesión Codex está disponible para
Claude Code, OpenCode u otro agente del mismo ordenador; cada host debe verificar su integración,
política y permiso de la aplicación.

Preferencia de trabajo del usuario: cuando TIA Portal esté abierto mediante Computer Use, mantenlo
maximizado para que el proyecto y sus paneles sean legibles. Verifica el tamaño de la ventana después
de abrirla o restaurarla y déjala maximizada al terminar la operación, salvo que una acción concreta
requiera temporalmente otra disposición.

Para automatizar interacciones gráficas repetibles, sigue el método y los límites de
[`tia-interfaz-y-computer-use.md`](10-kb/00-fundamentos/tia-interfaz-y-computer-use.md); los pasos ejecutables en esta máquina — con el candado de clic 30-tools/tia-ui/Invoke-TiaGuiClick.ps1 (hit-test del PID antes de pulsar) y el ritual completo — están en el [playbook GUI](10-kb/00-fundamentos/playbook-gui-tia.md). Openness/MCP
primero; Playwright solo para una interfaz web; UI Automation nativa únicamente después de descubrir
y validar controles semánticos de TIA en un fixture desechable.

Si el inventario nativo no devuelve una ventana TIA, refresca el inventario y revisa Doctor/procesos.
Solo si se confirma que no hay otra instancia de TIA ni proyecto abierto, y la aplicación exacta está
identificada, puedes lanzarla con Computer Use; después vuelve a enumerar y selecciona el ID nuevo
que devuelve la API. Si launch no entrega una ventana targetable, no repitas a ciegas: consulta el
inventario otra vez y para si la ventana/proyecto no se puede identificar. No conectes MCP para
compensar un inventario vacío.

### 3.4 Datos de cliente

`40-projects/` puede contener know-how de cliente. **No lo copies a `10-kb/`, a `60-library/`
ni a ningún sitio versionado en público** sin que el usuario lo autorice. Al extraer un bloque a
la librería, anonimiza nombres de cliente, de máquina y de producto.

---

## 4. Lenguajes: SCL sí, LAD con receta

Ver `00-meta/decisiones/ADR-003-lenguajes.md`.

| Para esto | Usa | |
|---|---|---|
| Cálculo, escalado, comunicaciones, tratamiento de datos | **SCL** | texto plano, diffea, el agente lo genera bien |
| Secuencias, máquinas de estado, gestión de modos | **SCL** | un `CASE` legible > 30 networks |
| Enclavamientos, mandos de motor/válvula, condiciones de marcha | **LAD** | lo mira y lo fuerza el mantenedor en planta |

> **El agente NUNCA escribe LAD a mano.**
> LAD es XML SimaticML posicional. Generarlo a pelo falla de formas que no se ven hasta la
> compilación, o peor, que compilan y hacen algo distinto. El agente **solo** produce LAD desde
> las recetas parametrizadas de `10-kb/30-lenguajes/lad/` o desde bloques probados de
> `60-library/`.
>
> Si dudas entre SCL y LAD: **elige SCL y dilo.** Convertir SCL→LAD a mano son 10 minutos.
> Depurar LAD mal generado son horas.

---

## 5. Reparto de los dos servidores MCP

| Servidor | Para qué | Modo |
|---|---|---|
| **`tia-inspect`** (heilingbrunner) | Leer, entender, buscar, exportar a texto para git | lectura por defecto; escritura solo con instancia aislada, raíz/manifiesto de fixture y `--allow-write` |
| **`tia-create`** (bulaofen, perfil `lite`) | Crear proyectos, hardware, red, HMI Unified | escritura; usa `dryRun`/preview cuando la herramienta lo ofrezca y, si no, preflight + fixture |

Regla práctica: **si la tarea es entender, `tia-inspect`. Si es crear, `tia-create`.**
Para editar un bloque estándar existente, `tia-inspect` con `--isolated --fixture-root <run-dir>
--allow-write`: tiene mejor modelo de errores. El servidor no permite abrir otra ruta que no sea
el `.ap20` exacto del manifiesto; las importaciones opacas y las mutaciones de tipos PLC sin
clasificación F-compliant están desregistradas.

La lista visible de `tia-create lite` no es el roster completo. Si una capacidad no aparece,
ejecuta `FindTools` con lenguaje natural y después `CallTool` con la firma exacta; no declares
que falta sin esa comprobación. En el build V20 local, `GetTags` devuelve `isSafety` por tag y
`GetBlocks` devuelve `isFailsafe`; úsalos en la misma sesión de cualquier escritura/descarga.
Para E/S, si otro perfil/agente no expone `GetTags`, usa
`FindTools("export PLC tag table")` → `CallTool("ExportPlcTagTable", ...)` y normaliza la evidencia
con `Convert-TiaTagTableExportToInventory.ps1`; ese inventario no sustituye la clasificación
`isSafety` requerida para autorizar una descarga.

Todas las secuencias automatizadas deben ejecutarse con
`30-tools/scripts/Invoke-McpToolSequence.ps1`, que mantiene una única sesión MCP y adquiere el
lease `Local\TIA-Claude-McpSession`. Si el lease está ocupado, espera hasta el timeout y falla;
no se lanzan dos sesiones concurrentes contra TIA.

---

## 6. Ciclo de trabajo en un proyecto

```
1.  Leer          GetProjectTree → GetSoftwareTree → GetBlockSource
2.  Comprobar     ¿existe ya en 60-library/? ¿lo cubre una receta de 10-kb/20-recetas/?
3.  Proponer      qué vas a cambiar, en qué bloques, y por qué; para SCL usa primero `New-TiaSclProposal.ps1` o `Invoke-TiaWorkflow.ps1 -Workflow propose`
4.  Backup        copia del .ap20
5.  Escribir      cambio mínimo, dryRun primero
6.  Compilar      CompileSoftware → 0 errores, o se revierte
7.  Guardar       SaveProject  (o SaveSession si hay Multiuser), fuera de la transacción Openness
                    de la mutación; el servidor usa `SaveGuarded` y mantiene la barrera F/Safety.
8.  Exportar      export textual a 40-projects/<x>/src/
9.  Commit        con mensaje que diga QUÉ cambió funcionalmente, no "update"
```

La aplicación de una propuesta SCL solo se realiza mediante
`30-tools/scripts/Invoke-TiaSclProposalApply.ps1 -Apply`. El modo predeterminado es un preview
local sin conexión a TIA. En el perfil V20 actual, `tools/list` confirma que faltan los importadores
requeridos, así que `-Apply` debe detenerse con `BLOCKED` antes de cualquier llamada de mutación.
Solo se habilitará cuando exista una herramienta acotada registrada y probada que importe un objeto
exacto y cuya respuesta confirme conteos, lectura posterior y metadata de seguridad. No se permite
eludir este bloqueo con `ImportSources` o `ImportFromDocuments` directos. Cuando la capacidad exista,
el runner registrará backup, rutas exactas, importación, compilación, guardado, exportación y lectura
posterior; si la compilación no queda en 0 errores y 0 advertencias, no guarda.

Los pasos 8 y 9 **no son opcionales**. Un `.ap20` es binario: sin el export en `src/` nadie —
tú incluido, dentro de tres meses — puede ver qué tocó el agente.

Antes de simular, exige que TIA, PLCSIM Advanced y CPU/firmware estén en la matriz Siemens:
Advanced V6.0 UPD1 cubre proyectos TIA V14–V19/FW V1.8–V3.1; TIA V20 requiere Advanced V7.0 o
posterior con cobertura V20. En este host TIA V20 + Advanced V7.0.0.0/API 7.0 tiene la
compatibilidad de versiones **verificada en ejecución**: el 2026-10-21 se descargó y ejecutó
sobre una CPU 1513-1 PN virtual (`6ES7 513-1AM03-0AB0`, FW V3.0) un bloque con 0 errores y 0
avisos, y su comportamiento se comprobó con 9 casos observados. Ver
[ADR-015](00-meta/decisiones/ADR-015-estado-real-2026-10-21.md). No descargues por el mero hecho
de que API, Softbus o `Go online` estén disponibles. La ruta predeterminada sigue siendo Softbus
local (`PLCSIM` en PG/PC) con una instancia virtual desechable administrada por el adaptador, y
en este host se ha probado además la alternativa TCP/IP: el Control Panel estaba en *TCP/IP
Single Adapter* y la descarga fue por `PN/IE / Siemens PLCSIM Virtual Ethernet Adapter`. El
runtime debe confirmar `status=ready` y modelo estándar no F; el modo de red es el que tenga
configurado el Control Panel (`SOFTBUS` o `TCPIP_SINGLE_ADAPTER`). TIA debe identificar el
destino como CPU simulada antes de la descarga, mostrando en la primera carga
`CPU-1500 Simulation` y el aviso de CPU simulada. Antes
de compilar para PLCSIM Advanced, comprueba que la propiedad del proyecto **Support simulation
during block compilation** está activada; V20 la deja desactivada por defecto. Si se activa,
recompila y vuelve a verificar. Openness expone `Project.IsSimulationDuringBlockCompilationEnabled`,
pero no des por hecho que el perfil MCP la lee o escribe. El gate `plcsimVirtualAdapterReady` solo describe la NIC TCP/IP y no se exige para
Softbus. TCP/IP queda como alternativa local aislada cuando la tarea lo requiere; exige `<Local>`
en PLCSIM Advanced, NIC Siemens con IP fija en la subred y ruta PG/PC inequívoca. La disponibilidad
del producto o un `PowerOn/PowerOff` no autorizan una descarga: antes se exige preflight completo
F/Safety y de protección. Si falta metadata, no descargues aunque el target sea virtual.
`Invoke-TiaSimulationAcceptance.ps1` consulta `GetBlocks` y `GetTags` y bloquea metadata F/Safety,
protección, consistencia o simulabilidad desconocida/falsa; después exige respuesta `Success` de
`DownloadToPlc`, estado `Online` y expectativas funcionales. Sus pruebas mock no son evidencia de
descarga live: el primer uso debe guardar la respuesta real, confirmar la ruta `PLCSIM` y completar
la aceptación de comportamiento antes de anunciar que la simulación funciona. Antes de iniciar
PLCSIM o MCP, el runner exige `-SimulationTargetEvidencePath` con la evidencia reciente definida en
`10-kb/20-recetas/R17-aceptacion-plcsim.md`; `-AcknowledgeVirtualTarget` por sí solo no confirma
visualmente el destino.

**Para simular una HMI Unified** hace falta además el **runtime de la misma versión que TIA**
([ADR-017](00-meta/decisiones/ADR-017-runtime-unified-igual-version.md)). Con runtime V19 y un
proyecto V20, la simulación falla con `Start downloading to device` → `HM_RT_1` → `Online connection
to HM_RT_1 failed` a los **26 s**, y **no arranca ningún proceso de runtime**: el síntoma no
menciona la versión y parece un problema de PLC. El lado PLC es independiente y sí funciona con lo
instalado, pero exige dos cosas que se olvidan: activar la propiedad **Support simulation during
block compilation** (V20 la deja desactivada) y **aceptar el diálogo `Establish connection to device`
→ `Connect`** del certificado autofirmado del PLC virtual. Si nadie responde a ese diálogo, la
descarga **se cancela sola a los ~70 s** sin explicar por qué. Todo el procedimiento, medido, está en
[R31](10-kb/20-recetas/R31-simulacion-plcsim-unified.md).

El procedimiento ejecutable completo, incluida la elección de PLCSIM según CPU/firmware, arranque,
primera descarga, RUN, plan funcional y limpieza está en
[`10-kb/20-recetas/R17-aceptacion-plcsim.md`](10-kb/20-recetas/R17-aceptacion-plcsim.md); todos los
agentes deben seguirlo. En Softbus deja una sola instancia activa por vez. Si el CPU no aparece en la
matriz de la versión instalada, la metadata F/Safety está incompleta o el diálogo no confirma
explícitamente que el target es simulado, para sin descargar.

Estado observado el 2026-09-24: la fixture lista para esta prueba es
`90-tmp/e2e/20260924-plcsim-simulation-support-enabled/`; el ajuste quedó activo en el snapshot y
`GetBlocks` leyó `PLCSimAdvancedSupport=true` después de compilar. Aun así, la descarga está
bloqueada: el perfil `tia-create full` probado no ofrece `GetTags` (`Unknown tool`) y omite
`GetBlocks.isFailsafe`. No intentes descarga hasta que el inventario live proporcione ambas
clasificaciones completas; Softbus disponible no elimina ese veto. `tia-inspect --isolated` sí leyó
`isFailsafe=false` y `isSafety=false` en otra fixture desechable, pero esa lectura no autoriza a
combinarla con una sesión `tia-create` distinta. El 2026-09-25, `Assert-TiaFixtureManifest.ps1`
dejó de validar la fixture habilitada: TIA regeneró archivos `IM/SearchIndex` y la copia de trabajo
ya no coincide con el backup. Restaura/regenera y vuelve a validar la fixture antes de cualquier
uso. Sigue la receta `10-kb/20-recetas/R17-aceptacion-plcsim.md` y el procedimiento Siemens
documentado en `30-tools/plcsim/README.md`: Softbus `PLCSIM` es la ruta por defecto; usa una sola
instancia activa; la descarga solo queda probada si el diálogo identifica `CPU-1500 Simulation` y
el plan funcional da las expectativas definidas.

**Actualización 2026-09-25:** una fixture nueva `retry-fixture-01` pasó manifiesto, preflight
completo (`isFailsafe=false`, tags `isSafety=false`), compilación 0/0, guardado y readback; su hash
quedó igual al backup. La exportación general omitió `FB_AgentDemo`, por lo que se exportó aparte;
el fixture no se modificó funcionalmente. En esa sesión `GetDevices` falló con error genérico y no
se obtuvo IP live por UI. No se creó instancia ni se descargó. Por tanto, R17 ya fija el método,
pero la aceptación end-to-end de este host continúa pendiente.

**Actualización del gate de descarga, 2026-09-25:** el bloqueo de metadatos anterior ya se resolvió
en el build local V20 de `tia-create`. `GetBlocks.isFailsafe` y `GetTags.isSafety` se comprobaron
en la misma sesión live adjuntada a `AgentDemo_V20`, y `DownloadToPlc` repite internamente una
preflight fail-closed de todos los bloques/tags antes de operar. Evidencia:
`70-runs/tia-capabilities/20260925-tia-create-safety-live-read-built.json`. Esto solo autoriza
seguir con la preparación de aceptación. La descarga sigue bloqueada hasta regenerar y validar la
fixture libre, confirmar CPU simulada en TIA y terminar el plan funcional de R17.

**Actualización 2026-10-21: la descarga y el plan funcional están hechos.** Los dos bloqueos que
quedaban —la ruta PG/PC y la confirmación de CPU simulada— están resueltos y medidos. Ver
[ADR-015](00-meta/decisiones/ADR-015-estado-real-2026-10-21.md) y
[R28](10-kb/20-recetas/R28-aceptacion-plcsim.md). Lo que hay que saber para repetirlo:

1. **La descarga solo funciona con la sesión adjunta al TIA abierto** (`AttachToOpenProject`).
   En sesión headless aislada falla con `Connect to module PLC_1 failed` aunque la CPU virtual
   esté viva y respondiendo por S7.
2. **El Control Panel de PLCSIM Advanced necesita ~100 s** tras arrancarse: la primera descarga
   falla y la segunda, ya asentada la OAM, funciona.
3. **Antes de leer tags hay que llamar a `IInstance::UpdateTagList()`**; si no, la lectura
   simbólica devuelve `-47` (`SREC_NOT_UP_TO_DATE`).
4. **Los tags se nombran sin el prefijo de tabla** (`Active`, no `Agent_Signals.Active`); con el
   nombre cualificado devuelven `-4` (`SREC_DOES_NOT_EXIST`).
5. **Para escribir en el proyecto abierto, `GoOffline` primero**: con la vista live en modo
   online, TIA rechaza la importación con *This function is not supported in online mode*.
6. **Un `FUNCTION` (FC) de TIA V20** no admite `VERSION`, `AUTHOR` ni `FAMILY`, y exige el tipo
   de retorno en la cabecera (`FUNCTION "X" : Void`). Sin él, el error salta en la línea
   siguiente y no señala la causa.

Verificado: `FB_AlarmLatch` (65/65 pasos, 9 casos) y `FC_Escalado` (33/33 pasos, 9 casos), ambos
solo contra CPU virtual, con la respuesta real de `DownloadToPlc` guardada.

**Actualización 2026-10-21 (tarde): PA-1 cumplido.** El objetivo global de `00-meta/02-plan.md`
está cerrado: el proyecto `DEMO-Cinta01` (S7-1500, motor M01 con enclavamiento y seta de
emergencia, HMI Unified con pantalla de operación) se crea desde un spec, compila con 0/0, pasa
`Check-TiaStandards.ps1` con **código 0** y tiene export textual y README; y la pregunta de
trazabilidad se responde con referencias reales. Ver [ADR-016](00-meta/decisiones/ADR-016-pa1-cumplida.md)
y la receta [R30](10-kb/20-recetas/R30-crear-proyecto-desde-spec.md). Cuatro trampas que
costaron tiempo y que ya están en el código y en el catálogo de errores: **TIA no abre un proyecto
cuya carpeta supere 143 caracteres**; **el OB cíclico lo nombra TIA** (`"Main"`, no `"OB_Main"`);
**el DB de instancia se declara en la fuente SCL** con `DATA_BLOCK`; y **el modo aislado de
`tia-inspect` no abre proyectos con WinCC Unified**.

---

## 7. Cómo comunicarte con el usuario

- **Español.** Identificadores de código en inglés (ver `20-standards/naming.md`).
- Di lo que has verificado y lo que has supuesto. Si compilaste y dio 0 errores, dilo con el
  número. Si no lo compilaste, dilo también.
- Clasifica cada resultado relevante como **verificado**, **supuesto**, **no verificado** o
  **bloqueado**, e indica la evidencia y el siguiente paso cuando no esté verificado.
- **No inventes que algo funciona.** Este dominio no perdona el optimismo: un bloque que
  "debería funcionar" en una máquina en marcha es un problema real.
- Cuando una herramienta falle, lee el mensaje: los tres servidores devuelven errores tipados
  (`NotFound`, `InvalidParams`, `NotSupported`, `ExportFailed`...). Ese código dice qué hacer.
- Si algo es una limitación de la propia API Openness y no un fallo tuyo, dilo: está en
  `10-kb/10-openness/limites.md`.

---

## 8. Antes de darte por satisfecho

- [ ] Compila con 0 errores
- [ ] Los nombres siguen `20-standards/naming.md`
- [ ] El bloque está en el grupo que le toca según `20-standards/estructura-proyecto.md`
- [ ] Tiene comentario de cabecera y los networks/regiones comentados
- [ ] Exportado a `src/` y commiteado
- [ ] Si algo quedó a medias o sin verificar, **está dicho explícitamente**

---

## 9. Estado del entorno

| | |
|---|---|
| TIA Portal | **V20** build `2000.0.9501.1` (V19 instalado pero no soportado — ADR-002; receta V21 preparada y sin verificar en esta máquina — ADR-014) |
| PLCSIM | V19 y V20 (clásico; **no es la causa** del bloqueo de descarga — H-19 refutada) |
| WinCC Unified Runtime | **V19** instalado (`SIMATIC WinCC Unified PC V19`; `GfxRTS.exe` 500.30.8901.3). **La simulación de una HMI Unified exige el runtime de la misma versión que TIA**: con TIA V20 hace falta `SIMATIC WinCC Unified PC V20`, que descarga el usuario. Ver [ADR-017](00-meta/decisiones/ADR-017-runtime-unified-igual-version.md) y [R31](10-kb/20-recetas/R31-simulacion-plcsim-unified.md). |
| PLCSIM Advanced | **V7.0.0.0**; API 7.0 / interfaz `0x00070000` inicializada; adaptador compilado y ciclo desechable de registro/PowerOn/PowerOff/limpieza verificados. **Desde el 2026-10-21 hay descarga y aceptación de comportamiento**: `FB_AlarmLatch` (65/65) y `FC_Escalado` (33/33), solo contra CPU virtual. Ver ADR-015. |
| PowerShell | **7.6.7** instalado (winget). Antes solo había Windows PowerShell 5.1, y varios scripts y tests no eran ejecutables en este host; ver R29. |
| `tia-inspect` | `30-tools/mcp/tia-inspect/bin/v20/TiaMcpServer.exe --tia-major-version 20` |
| `tia-create` | **V20 2.7.2**, perfil `lite`, compilado y verificado localmente. El perfil `full` expone `AttachToOpenProject`, `ImportPlcExternalSource`, `GenerateBlocksFromExternalSource` y `GoOffline`, que son la vía verificada para descargar y para escribir en un proyecto abierto. |

Si `Doctor` dice `User in 'Siemens TIA Openness' user group: False`, **nada va a funcionar**.
Manda al usuario al README: hay que añadirse al grupo como administrador y cerrar sesión.
