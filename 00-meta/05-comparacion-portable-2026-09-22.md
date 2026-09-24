# Comparación de las dos copias de `TIA-Claude_Portable` — 2026-09-22

Al terminar la copia entre equipos quedaron dos carpetas con el mismo nombre:

| Alias | Ruta |
|---|---|
| **INTERNA** | `C:\Users\Dpto. Técnico\Documents\TIA-Claude\TIA-Claude_Portable` |
| **SUELTA** | `C:\Users\Dpto. Técnico\Documents\TIA-Claude_Portable` |

## Veredicto

**Manda la INTERNA.** Es el *build-input template* del empaquetador portable y vive dentro del repo
git principal (`T-IA-Portal-RocaRoibas`). La SUELTA es una **salida generada el 2026-09-15** que
además arrastra una copia obsoleta del workspace.

Lo dicen sus propios manifiestos:

| `manifests/package-info.json` | INTERNA | SUELTA |
|---|---|---|
| `metadataRole` | `"build-input-template"` | *(ausente)* |
| `generatedUtc` | `null` (es plantilla) | `"2026-09-15T13:03:57Z"` |
| `tiaInspect.sha256` | `null` | hash real de un binario de hace una semana |
| `distribution.core.files` | `null` | `280` |
| `legacyMonolithicWorkspace` | *(ausente)* | `"workspace/"` ← **se autodeclara legacy** |

## Diferencias fichero a fichero

La INTERNA es más nueva en todo lo que difiere:

| Fichero | SUELTA | INTERNA | |
|---|---|---|---|
| `build/Build-PortablePackage.ps1` | 6 656 B | **8 487 B** | INTERNA |
| `tests/Test-PortablePackage.ps1` | 605 B | **3 274 B** | INTERNA |
| `tests/Test-PortablePackageContent.ps1` | 4 611 B | **6 076 B** | INTERNA |
| `tests/Test-PortableInstallRelocation.ps1` | 2 681 B | 2 581 B | difieren |
| `README-INSTALL.md` | 3 402 B (15-sep) | **3 680 B (22-sep)** | INTERNA |
| `docs/arquitectura.md` | 1 418 B | **1 784 B** | INTERNA |
| `docs/funcionamiento.md` | 2 961 B | **3 310 B** | INTERNA |
| `docs/NOTICE-THIRD-PARTY.md` | 685 B | **836 B** | INTERNA |
| `docs/harnesses.md` · `docs/prompt-claude-code.md` · los 4 `install/*.ps1` · `manifests/repositories.json` · `manifests/sha256.json` | idénticos | idénticos | — |

## Lo que solo existe en la SUELTA

1. **`workspace/_ref/`** — clones locales de los siete repositorios de referencia:
   `PLC_Projects`, `TIA_Portal_Openness_MCP`, `tia-integration-ai`, `tia-portal-mcp`,
   `tia-portal-openness-code-snippets`, `tiaportal-mcp`, `TIAPortalGames`.
   **No existen en el repo principal. Es lo único con valor real que hay que rescatar.**
2. **`Prompt.txt`** — el encargo original que originó el proyecto. Vale como registro histórico.
3. `.git` propio — **sin remoto configurado**, solo identidad local
   (`anton.bellas@rocaroibas.com`). Es un repo de scratch, no hay historia upstream que perder.
4. `.mcp.json` y `CLAUDE.md` propios del paquete portable, apuntando a
   `...\TIA-Claude_Portable\workspace\30-tools\mcp\tia-inspect\bin\v20\TiaMcpServer.exe`.
   Misma trampa de V20 que el resto (ver ADR-015).
5. `workspace/` completo — **obsoleto**: su `AGENTS.md` son 10 281 B frente a los 15 942 B del vivo,
   y su `README.md` 8 258 B frente a 9 132 B. No debe sobrescribir nada.

## Acción acordada

1. Mover `TIA-Claude_Portable\workspace\_ref\` → `TIA-Claude\_ref\` (o a `50-examples/_ref/` si se
   prefiere mantenerlo junto a los ejemplos). Confirmar que `.gitignore` lo excluye: son clones de
   terceros y no deben versionarse en el repo propio.
2. Mover `TIA-Claude_Portable\Prompt.txt` → `TIA-Claude\00-meta\encargo-original.txt`.
3. Una vez confirmados 1 y 2, la carpeta SUELTA es descartable por completo. **No la borra el
   agente**: se deja marcada y la borra el usuario, o se mueve a `_to_delete/` para revisión.
4. No copiar nada de `TIA-Claude_Portable\workspace\` al repo vivo. Es una regresión.
