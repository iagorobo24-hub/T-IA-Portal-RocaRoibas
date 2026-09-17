# LAD — solo por receta, nunca a mano

> Es la carpeta que [ADR-003](../../../00-meta/decisiones/ADR-003-lenguajes.md) y `AGENTS.md` §4
> citan como origen de las recetas parametrizadas de LAD. El agente **nunca** escribe LAD a mano.

## Por qué

LAD es XML SimaticML **posicional**: generar un network a pelo es frágil y falla de formas que no
dan error hasta la compilación, o peor, que compilan y hacen algo distinto de lo previsto
([ADR-003](../../../00-meta/decisiones/ADR-003-lenguajes.md)). El agente **solo** produce LAD a
partir de:

1. Las recetas parametrizadas de esta carpeta.
2. Bloques ya probados de [`60-library/`](../../../60-library/).

Si dudas entre SCL y LAD para algo nuevo: **elige SCL y dilo.** Convertir SCL→LAD a mano son 10
minutos; depurar LAD mal generado son horas.

## Cómo se genera LAD de verdad

No existe un "escribir LAD" — solo importación:

| Camino | Cuándo |
|---|---|
| `ImportPlcExternalSource` → `GenerateBlocksFromExternalSource` | Fuente externa (poco habitual para LAD) |
| Documento SIMATIC SD (`.s7dcl`/`.s7res`) ↔ `GetBlockSource`/`ImportFromDocuments` | Edición de un network existente, flujo de git (requiere V20+) |

Detalle completo de estas dos vías, y de lo que Openness no permite en absoluto para bloques
(crear, copiar, mover): [`10-kb/10-openness/limites.md`](../../10-openness/limites.md).

## ⚠️ Riesgo sin confirmar: etiquetas en-US en el `.s7res`

📄 **Documentado, no probado en esta máquina.** Importar bloques LAD desde documentos SIMATIC SD
exige que el `.s7res` acompañante lleve etiquetas **en-US** para todos los ítems, o la
importación falla — es un bug de Openness, no del servidor MCP
([ADR-003](../../../00-meta/decisiones/ADR-003-lenguajes.md)). Antes de dar por bueno un flujo
"editar LAD en git y devolverlo a TIA", hay que probarlo con un bloque LAD real y actualizar esta
marca a ✅ o ❌ según el resultado.

## Receta: enclavamiento de permisos de marcha

Es el caso real que ya usan `FB_Motor` y `FB_ValveOnOff` — el enclavamiento entra por parámetro
([`patrones-por-bloque.md` #1](../patrones-por-bloque.md#1-el-enclavamiento-entra-por-parámetro-nunca-se-calcula-dentro)),
y la cadena de condiciones que explica *por qué* algo no arranca se dibuja en LAD, en el network
donde se llama al bloque. Detalle completo del razonamiento:
[R08 §2](../../20-recetas/R08-bloque-motor.md#2-el-enclavamiento-se-calcula-fuera-en-lad).

**Entradas del network** (contactos en serie, todos deben cerrar para dar `Interlock = TRUE`):

| Contacto | Qué representa |
|---|---|
| Seta/parada de emergencia liberada | Contacto NC del circuito de seguridad |
| Guardamotor/térmico OK | Confirmación de protección eléctrica |
| Modo automático activo (o el modo que corresponda) | Viene de `FB_ModeManager` — ver [R11](../../20-recetas/R11-modos-manual-auto.md) |
| NOT atasco/condición de bloqueo mecánico | Sensor específico del equipo |

**Salida del network:** un único bit, cableado a la entrada `Interlock` del `FB_Motor` o
`FB_ValveOnOff` correspondiente.

```
Network: "M01 Cinta de entrada - permisos de marcha"

"DI_ES01_Ok" ─┤├─ "DI_QM01_Ok" ─┤├─ "M_Sys_AutoMode" ─┤├─ NOT "DI_S05_Jam" ─┤/├─┐
                                                                                 │
                                                    ┌────────────────────────────┘
                                                    │  ┌──────────────────┐
                                                    └──┤ Interlock        │
                                                       │  "FB_Motor"      │
                                                       │  iDB_M01         │
```

**Por qué así y no calculado en SCL:** cuando una máquina no arranca, el mantenedor no abre el
FB — abre este network y busca qué contacto está abierto. Si esa cadena estuviera dentro del FB
en SCL, tendría que leer código en vez de ver de un vistazo que falta la seta, o que hay atasco.

**Verificación al aplicar esta receta:**
- [ ] `Interlock` viene de una cadena LAD real, nunca de un `TRUE` fijo.
- [ ] El network tiene título y se entiende sin abrir el FB.
- [ ] Se importó desde documento SD o fuente externa, nunca escrito a mano en el XML.
