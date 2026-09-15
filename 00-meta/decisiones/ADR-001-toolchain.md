# ADR-001 — Toolchain de compilación

- **Fecha:** 2026-09-14
- **Estado:** ✅ Aceptada e implementada
- **Pregunta origen:** TDD Q1

## Contexto

`heilingbrunner/tiaportal-mcp` (el servidor MCP de mejor calidad, 99 herramientas) no publica
binario en GitHub Releases. La máquina no tenía ni .NET SDK ni Visual Studio.

## Decisión

Instalar el SDK y compilar desde fuente, en vez de extraer el `.exe` de la extensión de VS Code.

Instalado:
- `Microsoft.DotNet.SDK.10` → **10.0.401**
- `Microsoft.DotNet.Framework.DeveloperPack_4` → **4.8.1** (ensamblados de referencia para `net48`)

## Consecuencias

**A favor**
- Control total: podemos parchear el servidor para V19/V20, cosa imposible con un binario.
- **Y ha hecho falta de verdad:** upstream targetea V21 y no compilaba contra Openness V20.
- El SDK 10 es además el requisito de `Czarnak/tia-portal-mcp`, si algún día migras a V21.

**En contra**
- ~250 MB en disco y una dependencia más que mantener.
- Cada `git pull` del upstream obliga a revalidar el parche.

## Detalle técnico que costó encontrar

El paquete `Siemens.Collaboration.Net.TiaPortal.Packages.Openness` **resuelve los ensamblados
desde la instalación local de TIA en tiempo de compilación**. Con la versión 21.0.x del paquete y
sin TIA V21 instalado, no resuelve nada y no avisa: falla con **241 errores `CS0246`** ("no se
encontró el tipo `PlcTag`, `TiaPortal`, `PlcSoftware`...") que parecen un problema de `using`.

Con la versión 20.0.1744190253 del paquete: **1 error**. Ver ADR-002.

Versiones del paquete disponibles en nuget.org, comprobadas: 16, 17, 18, 19.0.1725520202,
20.0.1744190253, 21.0.1765349347.

También hubo que quitar el `HintPath` fijo a
`...\Reference Assemblies\...\v4.8\System.Management.dll`: el Developer Pack instala **v4.8.1**,
no v4.8. Sustituido por `<Reference Include="System.Management" />` a secas, que MSBuild resuelve
solo.
