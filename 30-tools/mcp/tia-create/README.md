# tia-create V20

Estado actual: **instalado y verificado**.

El runtime se compiló desde `bulaofen0036-coder/TIA_Portal_Openness_MCP`, proyecto
`TiaMcpServer.V20.csproj`, contra Openness V20 local. La versión es `2.7.2` y el manifest central
lo expone solo mediante el perfil explícito `create` o `full`, ambos con reconocimiento obligatorio.

Ruta relativa:

```text
30-tools/mcp/tia-create/bin/v20/TiaMcpServer.exe
```

El proceso se lanza con `--tia-major-version 20 --profile lite`. `lite` mantiene un roster pequeño
y deja las capacidades no listadas accesibles mediante el puente `FindTools`/`CallTool` del propio
servidor. No se usa el binario V21 como sustituto.

Evidencia de instalación:

- `dotnet build -c Release`: **0 errores, 2 advertencias** del proyecto fuente.
- `--doctor --tia-major-version 20`: Openness V20 inicializada y grupo `Siemens TIA Openness`
  confirmado.
- Disponibilidad de fichero: `30-tools/tests/Test-TiaCreateAvailability.ps1`.

Pendiente de la siguiente tarea: listar las herramientas MCP del runtime y ejecutar un scaffold
mínimo en una copia desechable. La existencia del binario no demuestra todavía que la generación
completa de proyectos funcione.
