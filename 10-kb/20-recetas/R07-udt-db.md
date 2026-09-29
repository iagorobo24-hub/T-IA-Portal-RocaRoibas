# R07 — Crear UDTs y bloques de datos

## Estado de aceptación

- **UDT raíz sencillo:** verificado en TIA Portal V20 mediante `tia-create/full`, en copia
  desechable. Incluye preflight de safety independiente, importación, compilación 0/0, guardado,
  exportación, lectura en otra sesión, borrado con preview, compilación/guardado posteriores,
  lectura independiente de ausencia y comparación de restauración. Véase
  [aceptación UDT V20](../../70-runs/e2e/mcp-udt-import-acceptance-20260924/README.md) y
  [registro](../../70-runs/e2e/mcp-udt-import-acceptance-20260924.json).
- **DB global:** `ExportBlock` V20 fue verificado como exportación read-only de un Global DB sencillo
  en una fixture; la importación V20 sigue **bloqueada y con estado no verificado**. La creación visual diagnóstica
  de `DB_AgentGlobalAcceptance` compiló 0/0, pero el readback devuelve `GetBlocks.isFailsafe=null`
  y `programmingLanguage=DB`; `GetBlockInfo` no añade clasificación failsafe y `ImportBlock` no tiene
  `dryRun`. Según `AGENTS.md`, metadata nula no autoriza escritura. Evidencia:
  [export y evaluación de la barrera](../../90-tmp/e2e/20260924-globaldb-import-acceptance/artifacts/04-computer-use-globaldb.md).
  No uses esta receta para importar/crear un DB hasta que una ruta aprobada clasifique el objeto de
  forma explícita como estándar antes de escribir y permita readback seguro independiente.
- **F/Safety:** excluido. No editar UDT, DB, tag table, bloque ni referencia Safety.

## UDT raíz sencillo — V20

Solo aplica al alcance probado: UDT `PlcStruct` en la raíz del PLC, miembros sencillos y sin
referencias existentes. `ImportType` no ofrece preview; por eso la única ruta aceptada es una copia
desechable con backup completo. Para otro tipo, grupo anidado o dependencia, detente y amplía la
aceptación en un fixture independiente antes de usarlo.

### Precondiciones

1. Ejecuta `Doctor`; exige TIA V20 y pertenencia al grupo Siemens Openness. Revisa la ventana con
   Computer Use nativo. Si hay una instancia visible, confirma título, versión y proyecto; no la
   cierres ni la sustituyas. Mantén TIA maximizado durante el trabajo y al terminar.
2. Crea una copia completa nueva del proyecto de prueba bajo `90-tmp/e2e/`, guarda el backup en una
   carpeta hermana y crea el manifiesto del fixture solo después de comparar copia y backup.
   Nunca apuntes el manifiesto a `40-projects/`, al original de `50-examples/` ni al original del
   cliente.
3. Ejecuta `tia-inspect/read` aislado sobre esa copia manifiestada. Lee `GetProjectTree` y
   `GetSoftwareTree` para descubrir el path real del PLC y del grupo de tipos. `GetBlocks` debe
   clasificar todos los bloques (`isFailsafe=false`, lenguaje conocido, sin know-how protection,
   metadata consistente). `GetTags` debe devolver `isSafety=false` para todos los tags. Si falta,
   es nulo o está incompleto cualquier dato, para. Lee `GetTypes`/`GetTypeInfo` para comprobar que
   el nombre destino no existe y que ningún tipo relevante está protegido.
4. Revisa el XML completo, nombre, namespace, miembros y tipos de datos. Reserva un nombre único.
   Exporta la tabla de tags para conservar el inventario usado en el preflight. No reutilices el
   XML de aceptación como plantilla de producción.
5. Usa `tia-create/full` únicamente sobre el clon desechable. Serializa las llamadas mediante
   `Invoke-McpToolSequence.ps1`; confirma proyecto y PLC exactos antes de mutar.

### Importar, compilar y releer

1. En `tia-create/full`, conecta a la sesión aislada que contiene el clon y confirma el proyecto
   mediante `GetState` y el árbol. `AttachToOpenProject` solo es válido si el servidor/perfil lo
   expone y la ventana/proyecto identificado es exactamente ese clon; el perfil `tia-inspect/read`
   no expone Attach. Si no puedes demostrarlo, para.
2. Importa un solo UDT con `ImportType(softwarePath=<PLC leído>, groupPath="", importPath=<XML
   exacto>)`. En la raíz se debe usar `groupPath=""`; no inventes `PLC_1/PLC data types`. Si se
   quiere un grupo, debe leerse su ruta real y aceptarse por separado. Como no hay preview, no
   llames `ImportType` sobre un proyecto real.
3. Relee con `GetTypes`/`GetTypeInfo`: exige nombre/tipo exactos, consistencia identificable y
   `isKnowHowProtected=false`. Si metadata falta, para y restaura el clon.
4. Ejecuta `CompileAndDiagnosePlc` (o la herramienta de compile verificada para el perfil). Exige
   estado `Success`, cero errores y cero avisos. Si no cumple, no guardes; corrige en un fixture
   nuevo o restaura.
5. Guarda con `SaveProject`, exporta el UDT con `ExportType`, y cierra/desconecta limpiamente.
   Abre una segunda copia exacta del proyecto guardado con `tia-inspect/read --isolated
   --fixture-root <manifiesto>` y confirma tipo presente, consistente, sin protección; vuelve a
   comprobar blocks/tags para asegurar las clasificaciones.

### Borrar UDT

El borrado puede romper DBs o interfaces que dependan del tipo. Solo se admite tras leer referencias
cruzadas y confirmar `crossReferenceAvailable=true` y cero referencias. En `DeletePlcType`, ejecuta
primero `dryRun=true`; inspecciona el path, el recuento y todas las referencias. Si falta el índice,
hay referencias o el objeto no es exacto, no apliques. Con cero referencias, aplica en el clon, exige
`deleted=true` y `verifiedAbsent=true`, vuelve a compilar 0/0, guarda, y relee en una sesión
independiente que el tipo está ausente.

### Restauración y evidencia

Compara todos los archivos de una copia restaurada desde el backup; no basta con el hash del `.ap20`,
porque TIA puede recrear `IM/SearchIndex` y modificar `System/PEData.*`. Registra hashes, diferencias,
logs crudos de cada llamada, XML fuente/exportado, preflight, compile, readback y versión del servidor.
No declares restauración in-place si solo comparaste una copia restaurada aparte.

La aceptación V20 actual cubre únicamente un UDT raíz con `Counter : DInt` y cero referencias. No
acepta UDT anidados, referencias, arrays o tipos complejos, `.s7dcl`, DB global, tipos Safety ni
operaciones online. Hardware físico y descarga están fuera de esta receta.
