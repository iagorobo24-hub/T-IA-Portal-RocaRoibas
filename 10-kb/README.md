# Base de conocimiento — TIA Portal y Openness

> Esto es lo que el agente tiene que **saber** para trabajar en TIA Portal.
> `20-standards/` es lo que tiene que **respetar**. Son cosas distintas.

## Si solo vas a leer tres cosas

1. **[`10-openness/path-concept.md`](10-openness/path-concept.md)** — Openness navega por *paths*
   de objetos de ingeniería, no por nombres. Es el error nº1 de cualquier LLM con esta API.
2. **[`10-openness/limites.md`](10-openness/limites.md)** — lo que la API sencillamente **no
   puede hacer**. Ahorra horas de intentar algo imposible y culpar al servidor MCP.
3. **[`50-errores/README.md`](50-errores/README.md)** — catálogo síntoma → causa → arreglo.

## Mapa

| Carpeta | Contenido | Estado |
|---|---|---|
| [`00-fundamentos/`](00-fundamentos/) | [Interfaz de TIA y computer use](00-fundamentos/tia-interfaz-y-computer-use.md) ✅ · versiones, licencias ⬜ | 🟡 |
| [`10-openness/`](10-openness/) | [Concepto de path](10-openness/path-concept.md) ✅ · [Límites duros](10-openness/limites.md) ✅ · [Conexión y sesiones](10-openness/conexion-y-sesiones.md) ✅ | 🟢 núcleo listo |
| [`20-recetas/`](20-recetas/) | **Runbooks**: R01-R04 ✅ · R05-R07 📄/fixture · R08-R12 ✅ · R13-R14 📄 no verificadas · R15-R16 ✅ · R17 🟡 runner verificado, runtime pendiente | 🟡 |
| `30-lenguajes/` | SCL, LAD, FBD, STL, GRAPH: sintaxis, patrones, antipatrones | ⬜ |
| `40-hmi/` | WinCC Unified y Comfort/Advanced | 📄 documentado; runtime V20 pendiente |
| [`50-errores/`](50-errores/) | [Catálogo](50-errores/README.md) síntoma → causa → arreglo ✅ | 🟢 v1 |
| [`90-referencia/`](90-referencia/) | [Parámetros reales de `tia-inspect`](90-referencia/parametros-tia-inspect.md) ✅ · tipos, CPUs, memoria ⬜ | 🟡 |

> ✅ **Openness operativo desde el 2026-09-14.** Las cuatro recetas de la tanda "entender" se han
> ejecutado contra proyectos reales: **7 proyectos migrados de V16 a V20, inventariados y
> exportados a texto**.
>
> La confrontación con la realidad corrigió **cuatro errores** de lo escrito a partir del código
> fuente — están listados en [`20-recetas/README.md`](20-recetas/README.md). Es la razón de que
> aquí todo lleve marca de verificación: lo que no se ha ejecutado, no se sabe.

## Cómo se escribe aquí

**Regla de oro: si no está verificado, se dice.** Este dominio no perdona el optimismo. Cada
afirmación lleva una de estas marcas:

| Marca | Significa |
|---|---|
| ✅ **Verificado** | Comprobado en esta máquina, o leído en el código fuente del servidor MCP / los snippets de Siemens |
| 📄 **Documentado** | Lo dice la documentación oficial o el autor del servidor, pero no lo he ejecutado |
| ⚠️ **Por confirmar** | Razonable, pero sin evidencia. Hay que probarlo |

Nada de "debería funcionar" sin marca.

## Entorno de referencia

Todo lo de aquí asume esta máquina, salvo que se diga lo contrario:

| | |
|---|---|
| TIA Portal | **V20**, interfaz en **inglés** |
| Openness | V20 (`Portal V20\PublicAPI\V20\Siemens.Engineering.dll`) |
| STEP 7 | Professional + Safety |
| WinCC | Comfort/Advanced ES, Unified ES, Basic ES |
| Simulación | PLCSIM Advanced V6.0, PLCSIM V19, PLCSIM V5.4 |

> ⚠️ **El idioma de la interfaz importa más de lo que parece.** Openness devuelve los nombres de
> las carpetas de sistema **en el idioma de la interfaz**: en inglés son `Program blocks`,
> `PLC data types`, `PLC tags`. En un TIA en español serían `Bloques de programa`, etc., y todos
> los ejemplos de la documentación dejarían de casar. Tu V20 está en inglés: bien. Tu V19 tiene
> español instalado: si alguna vez lo usas, cuidado.
