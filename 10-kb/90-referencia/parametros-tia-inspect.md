# Parámetros reales de las herramientas de `tia-inspect`

> ✅ **Extraído del `tools/list` del servidor en marcha**, 2026-09-14. No de la documentación:
> del esquema que el servidor publica.
>
> `*` = obligatorio.

## Por qué existe este documento

Porque me equivoqué. Escribí las recetas usando `projectPath` para `OpenProject`, tomándolo de
los *prompts* del servidor (`McpPrompts.cs`), donde efectivamente se llama así. Pero **el
parámetro de la herramienta se llama `path`**, y la llamada falló con:

```
System.ArgumentException: The arguments dictionary is missing a value
for the required parameter 'path'.
```

🔒 **Lección: los nombres de parámetro salen de `tools/list`, no de la documentación ni de los
prompts.** Si dudas, píde el esquema.

---

## Conexión y proyecto

| Herramienta | Parámetros |
|---|---|
| `Doctor` | *(ninguno)* |
| `Connect` | *(ninguno)* |
| `Disconnect` | *(ninguno)* |
| `GetState` | *(ninguno)* |
| `OpenProject` | **`path`\*** ← no `projectPath` |
| `SaveProject` | *(ninguno)* |
| `CloseProject` | *(ninguno)* |
| `GetProjectTree` | *(ninguno)* |

## PLC y bloques

| Herramienta | Parámetros |
|---|---|
| `GetPlcSummary` | `softwarePath`\* |
| `GetSoftwareTree` | `softwarePath`\* · `sections` — `blocks,types,tags,watch,sources` |
| `GetBlocks` | `softwarePath`\* · `regexName` |
| `GetBlockSource` | `softwarePath`\* · `blockPath`\* · `format` · `maxChars` |
| `GetBlockInterface` | `softwarePath`\* · `blockPath`\* |
| `CompileSoftware` | `softwarePath`\* · `password` |

## Búsqueda y referencias

| Herramienta | Parámetros |
|---|---|
| `GetCrossReferences` | `softwarePath`\* · `objectPath` · `objectKind` · `filter` · `maxDepth` |
| `WhereUsed` | `softwarePath`\* · **`name`\*** · `kind` ← busca por **nombre**, no por ruta |
| `FindInCode` | `softwarePath`\* · `pattern`\* · `nameFilter` · `maxResults` |

⚠️ **`WhereUsed` toma un nombre, `GetCrossReferences` toma una ruta.** Son distintas y se
confunden con facilidad.

⚠️ En `GetCrossReferences`, **`objectPath` es opcional**: sin él analiza todo el PLC, lo que en
un PLC grande devuelve una respuesta enorme. Pásalo casi siempre.

## Exportación

| Herramienta | Parámetros |
|---|---|
| `ExportPlcAsSourceTree` | `softwarePath`\* · `exportPath`\* |

---

## Cómo consultar el esquema tú mismo

```powershell
# Todas las herramientas y sus parámetros
$exe = "30-tools\mcp\tia-inspect\bin\v20\TiaMcpServer.exe"
# ...ver Invoke-TiaMcp.ps1 para el handshake completo; el método es tools/list
```

O más fácil, desde un cliente MCP: las herramientas y sus esquemas aparecen solas.

---

## Convenciones que se repiten

| Parámetro | Significa |
|---|---|
| `softwarePath` | Ruta al PLC: `PLC_1`, `PC-System_1/Software PLC_1`. De `GetProjectTree` |
| `blockPath` / `objectPath` | Ruta **relativa a la raíz**, sin el grupo de sistema: `40_Devices/FB_Motor` |
| `path` | Ruta de **fichero en disco** (solo `OpenProject`) |
| `exportPath` / `importPath` | Carpeta del sistema de ficheros |

El detalle de los dos tipos de ruta está en
[`10-openness/path-concept.md`](../10-openness/path-concept.md).
