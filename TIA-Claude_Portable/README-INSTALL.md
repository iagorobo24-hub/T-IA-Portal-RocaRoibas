# TIA-Claude Portable

Paquete portable para preparar un ordenador con TIA Portal V20 para trabajar desde Claude Code u otro harness de IA mediante MCP.

## Qué contiene

- `workspace/`: contrato del agente, base de conocimiento, estándares, scripts, librería y ejemplos.
- `install/`: instalación idempotente y verificación por hashes.
- `manifests/`: versiones, commits y hashes del paquete.
- `docs/`: arquitectura, funcionamiento y guía de uso.

## Prerrequisitos que no puede transportar este paquete

1. TIA Portal V20 instalado y licenciado por Siemens.
2. WinCC/PLCSIM instalados si se van a simular HMI o PLC.
3. Permisos de administrador para pertenecer al grupo `Siemens TIA Openness`.
4. Windows con una sesión nueva después de modificar el grupo.

## Instalación en otro ordenador

El paquete recomendado y actual se genera en `dist\TIA-Claude_Core` y `dist\TIA-Claude_Examples`.
El núcleo es autónomo y no contiene proyectos TIA; los ejemplos son opcionales y están separados.

Desde la carpeta `dist\TIA-Claude_Core`:

```powershell
.\install\Verify-CorePackage.ps1
.\install\Install-CorePackage.ps1 -DestinationRoot 'C:\TIA-Claude'
```

El instalador genera el perfil MCP de lectura con rutas relativas al ordenador destino. Para usar
los ejemplos, copia `dist\TIA-Claude_Examples\50-examples` aparte; no se mezclan automáticamente
con proyectos de trabajo.

El paquete monolítico histórico bajo `workspace\` se conserva solo como referencia de la primera
versión.

Desde PowerShell:

```powershell
Set-Location .\install
.\Install-TIA-Claude.ps1 -DestinationRoot 'C:\TIA-Claude'
```

Para actualizar una instalación existente hay que indicarlo explícitamente:

```powershell
.\Install-TIA-Claude.ps1 -DestinationRoot 'C:\TIA-Claude' -Update
```

La instalación genera un `.mcp.json` con la ruta real de ese ordenador y deja el servidor en modo lectura. Las escrituras requieren lanzar el servidor con `--allow-write` de forma deliberada.

## Comprobación

```powershell
.\Verify-TIA-Claude.ps1 -WorkspaceRoot 'C:\TIA-Claude' -RunDoctor
```

La verificación debe mostrar los hashes correctos y un diagnóstico de TIA V20 válido. Si el grupo Openness no es correcto, detente, añádelo como administrador y cierra sesión en Windows.

## Seguridad

- Nunca se descarga a hardware físico sin confirmación explícita en ese momento.
- No se incluyen proyectos de cliente.
- `_ref/` contiene material de terceros para uso privado y no debe publicarse automáticamente.
- Compilar no equivale a validar el comportamiento en runtime.
