# Siemens Openness Code Snippets

- **Fuente:** [siemens/tia-portal-openness-code-snippets](https://github.com/siemens/tia-portal-openness-code-snippets)
- **Licencia:** *Royalty-free Software provided by Siemens* — ver `LICENSE.md` del repo original
- **Ubicación local:** `_ref/tia-portal-openness-code-snippets/` (clon, no versionado aquí)

## Qué es

**No es un proyecto TIA.** Son **91 snippets en C#** que demuestran cómo hacer cada cosa con la
API Openness V20, escritos por Siemens. Están montados como métodos de test para poder
ejecutarlos de uno en uno desde el Test Explorer de Visual Studio.

Es la **materia prima de [`10-kb/`](../../10-kb/)**: cuando la base de conocimiento diga "para
hacer X, llama a Y", la evidencia sale de aquí.

## Qué cubre, por área

| Área | Snippets representativos |
|---|---|
| Proceso TIA | `GetAllInstalledTiaVersions`, `GetTiaPortalProcesses`, `ExitAndCloseTiaPortal`, `ExclusiveAccess` |
| **Concepto de paths** | `PathConcept_FirstIntroduction`, `PathConcept_GetEngineeringObjectWithIdentifier` |
| Catálogo hardware | `HardwareCatalog_AllEntries`, `ChangeTypeIdentifier_*` |
| Red | `ProfinetConfigurations`, `PLC_Et200Connection`, `IpAddressAndOnlineConfig` |
| Online | `GoOnline`, `GoOfflineAllDevices`, `Download`, `OnlineProvider_CurrentOnlineState` |
| Bloques | `ExportProgramBlock`, `ImportProgramBlockComposition`, `SclExportTest`, `ProtectPlcBlock` |
| Tags | `GetAllPlcTags`, `EditExistingTags`, `EditExistingTagsViaExportImport` |
| Bloques de datos | `GetDbInterfaceMembers`, `GetCrossReferencesForDb` |
| Seguridad | `CreateProjectRoles`, `SetPasswordProtectionTest`, `IsProjectProtected` |
| Safety | `ReadoutSafetyAdministration`, `SafetyIntegrated*_ActivateSTO` |
| Objetos tecnológicos | `CreateTechnologyObject`, `SetTechnologyObjectHwLimits` |
| Librerías | `CreateGlobalLibrary`, `CreateMasterCopy` |
| Startdrive / DCC | S120, G115D, S210, telegramas, DriveCliq |

## Lo más importante que sale de aquí

🔒 **El concepto de path.** `PathConcept_FirstIntroduction` es el snippet que hay que leer
primero. Openness **no navega por nombres**: navega por *paths* de objetos de ingeniería. Es el
error número uno de cualquier LLM con esta API — inventa una ruta plausible y falla de forma
opaca.

Está recogido como regla dura en [`AGENTS.md`](../../AGENTS.md) §2.

## Dos avisos

**Los snippets no son tests de verdad:** no tienen asserts. Siemens usa el framework de test
solo como forma de poder ejecutar cada método por separado. No los tomes como referencia de cómo
escribir tests.

**Un tercio del repo es Startdrive y DCC** (accionamientos SINAMICS: S120, G115D, S210,
telegramas, DriveCliq). Si no trabajas con variadores, esa parte se ignora y el volumen a
analizar se reduce casi a la mitad.
