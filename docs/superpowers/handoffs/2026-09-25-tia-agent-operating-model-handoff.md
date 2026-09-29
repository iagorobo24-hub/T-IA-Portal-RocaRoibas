# Handoff — TIA agent operating model

**Fecha:** 2026-09-25  
**Objetivo pausado:** completar el plan `docs/superpowers/plans/2026-09-21-tia-agent-operating-model.md` y aceptar con evidencia las operaciones de agentes en TIA Portal V20.  
**Estado:** PLCSIM Advanced V7 está instalado y el refuerzo F/Safety de `tia-create` está compilado; descarga PLC y aceptación de comportamiento siguen pendientes.

## Estado confirmado

### Verificado

- TIA Portal V20 y PLCSIM Advanced V7.0.0.0 están instalados. El API `API\7.0` declara la interfaz `0x00070000`.
- El adaptador nativo V7 completó inicialización, registro, `PowerOn`, `PowerOff`, baja y liberación con códigos `0x0`. La prueba de ruta de esta continuación también creó una instancia Softbus temporal y la limpió: `status=stopped`, `powerOffCode=unregisterCode=destroyCode=0x0`. No queda una instancia virtual creada por el agente.
- TIA mantiene abierto el proyecto desechable `AgentDemo_V20`, en `70-runs/e2e/20260925-plcsim-scaffold/retry-fixture-01/isolated-fixture/project/AgentDemo_V20/AgentDemo_V20.ap20`. La ventana visible estaba maximizada. El modelo visible es CPU 1513-1 PN. No cerrar ni reemplazar esta instancia sin autorización.
- PLCSIM Advanced muestra `PLCSIM` (Softbus) seleccionado en `Online Access` y `No Active PLC Instance`.
- `tia-create` se reconstruyó desde el commit upstream fijado con `30-tools/mcp/tia-create/patches/0001-explicit-failsafe-and-safety-gates.patch`. Build V20: 0 errores y dos advertencias existentes (MSB3539 de ruta intermedia y CS8602 en `OpcUaLiveReader.cs`). Falta Developer Pack net48; el builder usa net481.
- Doctor del binario reconstruido: Openness V20 inicializada y grupo `Siemens TIA Openness` confirmado. Runtime smoke `lite`: 56 herramientas, incluido `GetTags`.
- Se añadió `GetBlocks.isFailsafe` nullable y `GetTags` con inventario completo de tags anidados y `isSafety`. `DownloadToPlc` repite dentro de su sesión la clasificación del PLC y bloquea F/Safety, protección o metadata desconocida.
- Lectura live serializada con el binario instalado: `Bootstrap → Connect → AttachToOpenProject → GetProjectTree → GetBlocks → GetTags → Disconnect`. Adjuntó `AgentDemo_V20`, confirmó `PLC_1`, leyó `Main` y `FB_AgentDemo` como no F, consistentes y no protegidos; ambos tags `Agent_Signals/Cmd_Enable` y `Agent_Signals/Status_Active` dieron `isSafety=false`. Evidencia: `70-runs/tia-capabilities/20260925-tia-create-safety-live-read-built.json`.
- `GetDeviceIpAddress` devolvió `192.168.0.1`. `CheckDownloadReadiness` respondió `Ready=true` e `IsConsistent=true`, pero publicó cinco rutas PN/IE con direcciones PG/PC y target vacías y ninguna preferida. Esto acredita proveedor/configuración Openness, no una ruta seleccionable ni conexión a una instancia. Evidencias: `70-runs/simulation/20260925-plcsim-v7-download-readiness.json` y `20260925-plcsim-v7-device-readiness.json`.
- Se regeneró `readiness-latest.json`: encontró el proyecto abierto en PID 11952 y dejó `tiaInstanceSafeForApply=false`. La sesión MCP de solo lectura identificó `AgentDemo_V20`; la fixture sigue bloqueada por TIA para verificar hash posterior.
- Pasaron `Test-TiaCreateAvailability.ps1`, `Test-TiaCreateRuntime.ps1`, `Test-DocumentationState.ps1`, `Test-TiaSimulationAcceptanceSafety.ps1`, `TIA-Claude_Portable/tests/Test-PortablePackageContent.ps1` y `git diff --check`. La prueba portable generó una copia temporal coherente; no demuestra que `TIA-Claude_Portable/dist` se haya reconstruido con el binario nuevo.

### No probado / bloqueado

- No se descargó el proyecto, no se puso la CPU en RUN y no se midió comportamiento PLC.
- No se probó con una fixture con Safety que el veto de `DownloadToPlc` rechace efectivamente la operación. Hay compilación, revisión de código y lectura live de un PLC estándar, pero falta una prueba negativa controlada.
- Firmware exacto de la CPU no confirmado. Obtenerlo y cotejar CPU/firmware con la matriz oficial V7.
- No se puede validar/hash el manifiesto mientras TIA tiene el `.ap20` bloqueado. Había backup coincidente antes de abrir, pero hace falta recuperar una copia libre y volver a validar antes de escribir.
- No hay aceptación del recorrido TIA → CPU virtual → RUN → transición funcional con entradas/salidas.
- `CheckDownloadReadiness` no expone direcciones ni ruta preferida; no elegir Ethernet, Wi-Fi, VPN ni la NIC Siemens por heurística. Softbus seleccionado en el panel no prueba que TIA haya resuelto el target simulado.

## Trabajo pendiente, en orden

1. **Preservar el árbol de trabajo.** Ejecutar `git status --short`; no descartar ni revertir cambios previos. Revisar los cambios de esta sesión en `30-tools/mcp/tia-create/build.ps1`, README, patch, test runtime, `AGENTS.md`, matriz, plan y este handoff.
2. **Alinear R17 y el runner.** `10-kb/20-recetas/R17-aceptacion-plcsim.md` todavía contiene instrucciones históricas que dicen que `tia-create` no ofrece `GetTags/isFailsafe`. `Invoke-TiaSimulationAcceptance.ps1` espera `GetTags.meta.totalTags`, pero el build actual devuelve `meta.count` y `meta.complete`; además envía argumentos antiguos. Adaptar y probar fail-closed. Readiness marca inseguro cualquier proyecto visible; implementar flujo que adjunte solo al proyecto exacto confirmado y verifique identidad/ruta/hash, sin cerrar proyectos ni abrir otra instancia.
3. **Resolver Softbus inequívocamente.** El runner espera una ruta que coincida exactamente con `PLCSIM` y pasa IP objetivo a `DownloadToPlc`. El inventario actual no tiene direcciones aunque el PLC informa `192.168.0.1`; la selección del servidor filtra IP contra `TargetAddresses`. Corregir y probar la ruta Softbus sin adivinar. La primera carga debe mostrar `CPU-1500 Simulation` y el aviso de CPU simulada que fija R17; cancelar si aparece target físico o ambiguo.
4. **Recuperar fixture exacta e íntegra.** El proyecto de prueba sigue abierto; no cerrarlo desde el agente sin autorización. Preparar un fixture nuevo desde el backup coincidente con manifiesto creado por el runner serializado, o pedir al usuario que libere la ventana. Verificar backup/hash antes de escribir. En una sola sesión MCP repetir clasificación F/Safety, protección, consistencia y soporte de compilación simulable.
5. **Completar aceptación PLC.** Leer firmware y compatibilidad exactos; compilar en TIA con 0 errores/0 avisos; iniciar una instancia V7 Softbus; demostrar ruta y target simulado; descargar solo a PLCSIM; verificar Online/RUN; ejecutar un plan de E/S con expectativas funcionales; guardar/exportar/readback; limpiar instancia y comparar/restaurar hash. Si algún preflight falla, registrar bloqueo sin forzar la ruta.
6. **Cerrar riesgo de credencial histórica.** `50-examples/npatel-iot/FICHA.md` documenta que el valor MindSphere se retiró de las copias de trabajo detectadas, pero apareció en 47 de 66 snapshots/commits. La revocación/rotación por el propietario sigue sin confirmarse. No mostrar el valor ni redistribuir copias; pedir confirmación de revocación. Cualquier reescritura de historial requiere respaldo y autorización.
7. **Reconstruir distribución portable.** La prueba temporal de contenido pasó, pero no regeneró `TIA-Claude_Portable/dist`. Reconstruirlo con el binario patched, verificar manifiestos, conteos e instalación/relocation/content. Mantener secretos fuera del paquete.
8. **Completar cobertura profesional.** R18 medidas analógicas, R19 diagnóstico/tráfico de comunicaciones y R20 aceptación HMI por modelo/runtime tienen documentación, pero faltan fixtures aceptadas, casos esperados y evidencia. WinCC Runtime Advanced V20 no está verificado. Expandir matriz MCP vs Openness vs Computer Use: la mayoría de schemas aún no son pruebas de comportamiento.
9. **Cerrar el resto del plan.** Reconciliar capacidad por familia y tareas aceptadas; correr suites pertinentes, regenerar estado y mantener `accepted=false` hasta probar comportamiento/runtime. Hardware físico y F-blocks/tags Safety siguen excluidos por `AGENTS.md`.

## Estado de archivos

Hay cambios sin commit. No ejecutar `git reset`, `git checkout`, limpieza recursiva ni reemplazo de `dist` sin inventariar y proteger lo existente. El siguiente agente debe partir del árbol actual; no asumir que los cambios ya están comprometidos.

## Prompt de continuación

<PROMPT>
Continúa el objetivo TIA-Claude en la raiz del repositorio. Lee primero AGENTS.md, este handoff (docs/superpowers/handoffs/2026-09-25-tia-agent-operating-model-handoff.md) y el plan docs/superpowers/plans/2026-09-21-tia-agent-operating-model.md. No reinicies el trabajo. Inspecciona git status --short y conserva todos los cambios actuales y previos.

Objetivo: completar, paso a paso y con evidencia verificable, el método profesional para que agentes trabajen con TIA Portal V20. Empieza por alinear R17 y corregir/testear Invoke-TiaSimulationAcceptance.ps1 contra el contrato local actual: GetBlocks.isFailsafe, GetTags.items/meta.count/meta.complete/meta.success, barrera F/Safety en la misma sesión de descarga y rechazo fail-closed. El build reproducible está en 30-tools/mcp/tia-create/build.ps1 y usa 30-tools/mcp/tia-create/patches/0001-explicit-failsafe-and-safety-gates.patch. No borres ese trabajo. No declares probada la barrera sin una prueba negativa controlada.

TIA V20 tiene abierto AgentDemo_V20 en 70-runs/e2e/20260925-plcsim-scaffold/retry-fixture-01/isolated-fixture/project/AgentDemo_V20/AgentDemo_V20.ap20. Antes de conectar, identifica la ventana con Computer Use nativo node_repl + @oai/sky, verifica versión/proyecto y déjala maximizada. No cierres ni sustituyas esa ventana sin autorización. El manifiesto/hash posterior está bloqueado mientras TIA retiene el archivo; crea una fixture nueva desde el backup verificado con el runner correcto o espera que el usuario libere TIA. No escribas hasta validar backup y hash.

PLCSIM Advanced V7.0 está instalado. El API V7 y el ciclo de vida del adaptador Softbus se verificaron; la última instancia temporal fue detenida, desregistrada y liberada con códigos 0x0. El panel PLCSIM mostraba PLCSIM/Softbus seleccionado y ninguna instancia activa. CPU visible: 1513-1 PN; confirma firmware. IP de proyecto leída: 192.168.0.1. CheckDownloadReadiness respondió Ready=true pero devolvió cinco rutas PN/IE sin direcciones ni ruta preferida; eso no autoriza descarga. El runner pasa la IP al filtro de ruta aunque TargetAddresses está vacío. Corrige y demuestra selección Softbus inequívoca; nunca selecciones una NIC por heurística. No descargues hasta que TIA identifique explícitamente CPU-1500 Simulation/CPU simulada. Target físico prohibido.

Tras arreglar el runner, ejecuta la aceptación completa solo en una fixture desechable: Doctor; backup/manifiesto; Connect/Attach seguro al path exacto; GetProjectTree; preflight completo de F/Safety, protección, consistencia y soporte de compilación simulable; CompileSoftware con 0 errores/0 avisos; una instancia V7 Softbus; selección inequívoca y confirmación visual de target simulado; descarga; Online/RUN; plan de E/S con resultados esperados; guardar/exportar/readback; detener instancia; comparar/restaurar hash. Si una puerta falla, registrar BLOQUEADO con evidencia y siguiente acción, sin saltarla.

Después, resuelve por prioridad la revocación externa de la credencial MindSphere histórica (no reveles el valor; se halló en 47/66 snapshots), reconstruye TIA-Claude_Portable/dist con el binario patched y verifica manifiestos/install/relocation, y acepta con fixtures medidas analógicas, diagnóstico de comunicaciones y HMI por modelo/runtime. Runtime Advanced V20 no está verificado. Completa la matriz MCP/API Openness/Computer Use y las acciones del plan pendientes. Conserva accepted=false hasta demostrar comportamiento real. No pidas permiso para acciones ya autorizadas; si el siguiente paso requiere al propietario (confirmar revocación/liberar TIA), completa lo independiente y solicita solo la acción concreta necesaria. Clasifica cada resultado como verificado/supuesto/no verificado/bloqueado.
</PROMPT>
