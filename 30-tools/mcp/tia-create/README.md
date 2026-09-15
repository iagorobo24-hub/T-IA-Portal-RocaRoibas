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

Evidencia de instalación y uso:

- `dotnet build -c Release`: **0 errores, 2 advertencias** del proyecto fuente.
- `--doctor --tia-major-version 20`: Openness V20 inicializada y grupo `Siemens TIA Openness`
  confirmado.
- Disponibilidad de fichero: `30-tools/tests/Test-TiaCreateAvailability.ps1`.
- Runtime smoke: `30-tools/tests/Test-TiaCreateRuntime.ps1` pasa con el perfil `lite` y 55
  herramientas.
- Scaffold E2E: `30-tools/tests/Test-AgentDemoScaffoldEvidence.ps1` crea un proyecto V20
  desechable, compila con 0 errores/0 warnings, guarda, inspecciona y exporta el bloque creado.
- Secuencia MCP: `30-tools/scripts/Invoke-McpToolSequence.ps1` conserva una única sesión
  Bootstrap → Connect → trabajo → Disconnect y aplica un lease global para evitar carreras.
