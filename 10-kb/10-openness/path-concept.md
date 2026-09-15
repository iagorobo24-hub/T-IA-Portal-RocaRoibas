# El concepto de path — lo primero que hay que entender

> Si solo lees un documento de toda la base de conocimiento, que sea este.
> Fuente: snippets oficiales de Siemens `PathConcept_FirstIntroduction` y
> `PathConcept_GetEngineeringObjectWithIdentifier`, y el código de los servidores MCP.

## El problema

Openness **no busca por nombre**. Navega por una jerarquía de objetos de ingeniería, y cada
objeto se identifica por su posición en esa jerarquía.

Un LLM, ante "edita el bloque `FB_Motor`", tiende a construir una ruta que *parece* razonable:

```
Program blocks/FB_Motor          ← mal
PLC_1/Program blocks/FB_Motor    ← mal
Main/FB_Motor                    ← mal
```

Y falla. A veces con un error claro, a veces devolviendo vacío, que es peor.

🔒 **Regla dura (`AGENTS.md` §2): una ruta que no has leído de `GetProjectTree` o
`GetSoftwareTree` no existe.** No la construyas. No la deduzcas. No la "corrijas".

---

## La jerarquía real

✅ *Verificado leyendo `Portal.Tree.cs` y `Portal.Resolve.cs` del servidor `tia-inspect`.*

```
TiaPortal                            la aplicación
└── Project                          el .ap20 abierto
    └── Devices                      lo que ves en el árbol del proyecto
        └── DeviceItems              CPU, módulos, interfaces... anidados
            └── SoftwareContainer    el "contenedor" de software de un DeviceItem
                └── PlcSoftware      ← aquí empieza lo que te interesa
                    ├── BlockGroup            "Program blocks"      (grupo de sistema)
                    │   ├── Blocks            OB / FB / FC / DB
                    │   └── Groups            subcarpetas de usuario
                    ├── TypeGroup             "PLC data types"      (grupo de sistema)
                    ├── TagTableGroup         "PLC tags"            (grupo de sistema)
                    ├── WatchAndForceTableGroup  "Watch and force tables"
                    └── ExternalSourceGroup   "External source files"
```

Dos niveles de path, y **se comportan distinto**:

### 1. `softwarePath` — cómo llegar al PLC

Identifica un `PlcSoftware` dentro del proyecto.

| Caso | `softwarePath` |
|---|---|
| PLC hardware normal | `PLC_1` |
| PLC de software en un PC station | `PC-System_1/Software PLC_1` |
| PLC dentro de un grupo de dispositivos | `Grupo/PLC_1` |
| HMI Unified | `HMI_RT_1` |

✅ Sale de `GetProjectTree`.

> 📄 El servidor `tia-create` (bulaofen) tolera espacios y mayúsculas, y en un proyecto con un
> solo PLC acepta `PLC` y resuelve a `PLC_1`. **No te apoyes en eso**: `tia-inspect` no lo hace,
> y en un proyecto con dos PLCs te resuelve al que no querías o falla.

### 2. Path de objeto — cómo llegar al bloque dentro del PLC

Y aquí está la trampa que más cuesta:

🔒 **Los paths de objeto son relativos a la raíz del grupo de sistema, y NO incluyen su nombre.**

```
✅ bien:  1_Tests/FC_Block_1
❌ mal:   Program blocks/1_Tests/FC_Block_1
```

✅ *Verificado: está escrito explícitamente en el README de `tia-inspect` —
"Paths used by these tools are root-relative: `1_Tests/FC_Block_1`, not
`Program blocks/1_Tests/FC_Block_1`".*

Un bloque en la raíz es simplemente `FB_Motor`. Uno dentro de dos carpetas es
`40_Devices/Motores/FB_Motor`.

> ⚠️ **Excepción que confunde:** en las operaciones de **exportar e importar como documentos**
> con `preservePath`, el árbol exportado **sí** incluye la carpeta de sistema (`Program blocks/…`)
> porque refleja la estructura en disco. Y `ImportTypeFromDocuments` acepta ese nombre de vuelta
> como primer segmento de `groupPath`. Es decir: lo que exportas se puede volver a importar tal
> cual, pero ese formato **no** es el que usan las demás herramientas.

---

## El flujo correcto, siempre

```
1. GetProjectTree                  → qué dispositivos hay, y sus softwarePath
2. GetSoftwareTree(softwarePath)   → qué bloques, tipos, tags hay y en qué grupos
3. ...ahora ya tienes rutas reales
```

`GetSoftwareTree` acepta `sections` — cualquier subconjunto de
`blocks,types,tags,watch,sources` — para no traerse un PLC entero cuando solo quieres los
bloques. ✅ *Verificado en el README de `tia-inspect`.* Úsalo: en un PLC grande la diferencia
entre pedir todo y pedir `blocks` es enorme.

Si tienes solo un nombre y no la ruta, existe `ResolveObjectPath`. Y cuando `ExportBlock` falla
porque le diste un nombre pelado en vez de una ruta completa, el error **te sugiere las rutas
probables**. 📄 Léelo en vez de reintentar a ciegas.

---

## Nombres de los grupos de sistema

🔒 **Dependen del idioma de la interfaz de TIA.** No están fijados por la API.

| Interfaz en inglés ✅ *(tu V20)* | En español |
|---|---|
| `Program blocks` | `Bloques de programa` |
| `PLC data types` | `Tipos de datos PLC` |
| `PLC tags` | `Variables PLC` |
| `Watch and force tables` | `Tablas de observación y forzado` |
| `External source files` | `Fuentes externas` |

Tu TIA V20 está **solo en inglés** ✅ *verificado*, así que coincide con toda la documentación y
con los valores por defecto de los servidores. Tu V19 tiene español instalado: si algún día
trabajas ahí, esto se rompe.

---

## Cosas que sorprenden y conviene saber de antemano

📄 **Los nombres de los tipos de datos PLC son únicos en todo el PLC**, no dentro de su grupo.
Importar un `UDT_Motor` en un grupo distinto de donde ya existe falla con *"an object with the
name ... already exists in the plc"*, incluso con `importOption: Override`. La solución es
apuntar `groupPath` al grupo donde el tipo ya vive.

📄 **Los grupos de sistema no se pueden renombrar ni borrar.** Ni la tabla de tags por defecto.
Ni la tabla de forzado, que el sistema crea una por PLC. Intentarlo devuelve `NotSupported`.

✅ **Openness no es thread-safe.** El servidor `tia-inspect` serializa todas las llamadas tras un
lock global precisamente por esto — el SDK de MCP puede despachar llamadas concurrentes y, con
escritura activada, una carrera corrompería el proyecto en vez de devolver datos viejos.
No intentes paralelizar operaciones de Openness.
