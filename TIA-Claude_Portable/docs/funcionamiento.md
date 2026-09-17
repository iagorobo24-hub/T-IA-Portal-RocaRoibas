# Funcionamiento operativo

> Antes de elegir perfil, consulta
> [`10-kb/10-openness/capacidades-y-alcance-por-conexion.md`](../../10-kb/10-openness/capacidades-y-alcance-por-conexion.md):
> es la matriz de qué puede y qué no puede hacer cada conexión (`read`/`write`/`create`/`full` y
> el destino PLCSIM/hardware) sin tener que deducirlo de la lista de herramientas MCP.

## Arranque obligatorio

1. Ejecutar `Doctor`.
2. Conectar o adjuntarse a la instancia existente de TIA Portal.
3. Ejecutar `GetProjectTree`.
4. Obtener las rutas reales con `GetSoftwareTree`.
5. Leer antes de escribir.
6. Hacer backup.
7. Usar preview/dryRun.
8. Cambiar un bloque cada vez.
9. Compilar con cero errores antes de guardar.
10. Exportar a `src/` y registrar la evidencia.

### Evidencia de E/S cuando el roster MCP es parcial

`tia-create lite` muestra solo un subconjunto de herramientas. Para leer tags detalladas:

1. `GetPlcTagTables` para obtener los nombres reales.
2. Si `ExportPlcTagTable` no aparece, `FindTools("export PLC tag table")`.
3. `CallTool("ExportPlcTagTable", argumentosJson)` con el `softwarePath`, tabla y ruta exactos.
4. `Convert-TiaTagTableExportToInventory.ps1` y después `New-TiaIoList.ps1`.
5. Si se parte de dos inventarios, `Merge-TiaTagEvidenceIntoInventory.ps1` exige que el
   `softwarePath` resuelva un único PLC antes de generar el dossier.

No se acepta una lista construida desde contadores, nombres supuestos o texto resumido del árbol.

Para una secuencia MCP real, usar `30-tools/scripts/Invoke-McpToolSequence.ps1`: mantiene un
único proceso/una única sesión y adquiere el lease `Local\TIA-Claude-McpSession`. Si otro agente
está usando TIA, la segunda secuencia espera hasta el timeout y falla explícitamente; no intenta
compartir handles ni abrir una segunda instancia.

## Simulación por capas

1. `Test-SimulationReadiness.ps1`: comprueba versiones, medios HMI y seguridad de la sesión.
2. `Test-PlcSimRuntimeApiProbe.ps1`: inicializa y libera la API instalada sin crear CPU.
3. `Test-PlcSimNativeAdapter.ps1`: registra una CPU temporal, verifica sus propiedades y pasa
   PowerOn/PowerOff; la desregistra siempre.
4. Solo después se puede plantear una descarga a PLCSIM, con una ruta virtual explícita y un
   proyecto desechable. Compilar o arrancar una CPU no demuestra todavía el comportamiento del
   programa ni habilita la simulación HMI.

El gate adicional `plcsimVirtualAdapterReady` debe estar a `true`. Si el adaptador
`Siemens PLCSIM Virtual Ethernet Adapter` aparece como `Not Present`, el configurador de PLCSIM
debe activarlo con privilegios de administrador; el agente no lo activa silenciosamente porque
modifica la configuración de red del equipo.

## Limitaciones deliberadas

- Openness utiliza rutas de ingeniería, no nombres inventados.
- Openness no es thread-safe.
- Los bloques protegidos y F-blocks no se editan.
- El agente no genera LAD XML a mano.
- El servidor MCP no sustituye al Runtime HMI ni a la validación visual de una pantalla.
- La descarga a un PLC físico siempre requiere confirmación puntual del usuario.
- El adaptador nativo de PLCSIM necesita LLVM `clang-cl`, Visual Studio C++ Build Tools, Windows
  SDK y PLCSIM Advanced instalado en la máquina; el paquete transporta el código, no las DLL de
  Siemens.
