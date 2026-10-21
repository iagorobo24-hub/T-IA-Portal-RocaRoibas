# Recetas â€” runbooks accionables

> Cada receta responde a *"cÃ³mo hago X"* con la secuencia exacta de llamadas, quÃ© verificar, y
> quÃ© hacer cuando falla. No son tutoriales: son procedimientos.

## Formato de una receta

```
Objetivo        una frase
Precondiciones  quÃ© tiene que ser cierto antes
Servidor        tia-inspect | tia-create
Secuencia       las llamadas, en orden, con los parÃ¡metros que importan
VerificaciÃ³n    cÃ³mo sabes que saliÃ³ bien
Si falla        los modos de fallo conocidos y su arreglo
```

## Ãndice

### Tanda 1 â€” leer y entender âœ… *sirve desde el dÃ­a 1, no depende de los estÃ¡ndares*

| # | Receta | Estado |
|---|---|---|
| [R01](R01-inventariar-proyecto.md) | Inventariar un proyecto que no conoces | âœ… |
| [R02](R02-donde-se-usa.md) | DÃ³nde se usa una tag, quÃ© la escribe, quÃ© la lee | âœ… |
| [R03](R03-exportar-a-git.md) | Exportar un proyecto a texto y meterlo en git | âœ… |
| [R04](R04-entender-un-bloque.md) | Entender quÃ© hace un bloque | âœ… |

> âœ… **Las cuatro ejecutadas contra proyectos reales el 2026-09-14** (`npatel-basement-light`,
> `npatel-sorting-plant`, y los 7 en lote para R03).
>
> La pasada real corrigiÃ³ **cuatro errores** de la versiÃ³n escrita a partir del cÃ³digo:
>
> | DecÃ­a | Es |
> |---|---|
> | `OpenProject(projectPath:)` | **`path`** |
> | "Openness no migra proyectos, hay que hacerlo a mano" | **Migra solo**, vÃ­a `OpenWithUpgrade` |
> | "Empieza por `GetBlockInterface`" | Solo vale para **bloques de datos**; para FB/FC, `GetBlockSource` |
> | "El LAD sale como XML ilegible" | El LAD en `.s7dcl` **se lee perfectamente** |
>
> Los parÃ¡metros verificados estÃ¡n en
> [`90-referencia/parametros-tia-inspect.md`](../90-referencia/parametros-tia-inspect.md).

### Tanda 2 â€” esqueleto y tags

| # | Receta | Estado |
|---|---|---|
| [R05](R05-proyecto-nuevo.md) | Proyecto nuevo desde cero | ðŸ“„ documentada; scaffold V20 verificado en fixture |
| [R06](R06-tags-io.md) | De una lista de E/S a tablas de tags importadas | ðŸ“„ procedimiento documentado |
| [R07](R07-udt-db.md) | UDTs y bloques de datos | ðŸ“„ procedimiento documentado |

### Tanda 3 â€” lÃ³gica âœ…

| # | Receta | Bloque | Estado |
|---|---|---|---|
| [R08](R08-bloque-motor.md) | Bloque de motor | [`FB_Motor`](../../60-library/blocks/FB_Motor.scl) | âœ… |
| [R09](R09-bloque-valvula.md) | Bloque de vÃ¡lvula | [`FB_ValveOnOff`](../../60-library/blocks/FB_ValveOnOff.scl) | âœ… |
| [R10](R10-secuencia.md) | Secuencia / mÃ¡quina de estados | [`FB_SequenceTemplate`](../../60-library/blocks/FB_SequenceTemplate.scl) | âœ… |
| [R11](R11-modos-manual-auto.md) | Modos manual / automÃ¡tico | [`FB_ModeManager`](../../60-library/blocks/FB_ModeManager.scl) | âœ… |
| [R12](R12-alarmas.md) | GestiÃ³n de alarmas | [`FB_AlarmLatch`](../../60-library/blocks/FB_AlarmLatch.scl) | âœ… |

> âœ… **Los cinco bloques compilan en TIA V20 con 0 errores y 0 advertencias.** Se importaron de
> verdad en un proyecto y se compilaron; el cÃ³digo publicado es el que pasÃ³ la prueba.
>
> âš ï¸ **Compilar no es funcionar.** Ninguno se ha ejecutado en PLCSIM todavÃ­a. Cada receta lleva
> su tabla de casos a probar, y esa parte no se delega
> ([`definition-of-done.md`](../../20-standards/definition-of-done.md) nivel 4).

### Tanda 4 â€” HMI y documentaciÃ³n

| # | Receta | Estado |
|---|---|---|
| [R13](R13-pantalla-hmi.md) | Pantalla WinCC Unified | ðŸ“„ documentada, no verificada |
| [R14](R14-binding-hmi-plc.md) | Binding de tags HMI â†” PLC | ðŸ“„ documentada, no verificada |
| [R15](R15-lista-es.md) | Generar la lista de E/S | âœ… herramienta verificada en fixture y contra exportaciÃ³n XML real V20; requiere tags detalladas |
| [R16](R16-descripcion-funcional.md) | Generar la descripciÃ³n funcional | âœ… generada contra ejemplo real; no sustituye validaciÃ³n funcional |
| [R17](R17-aceptacion-plcsim.md) | AceptaciÃ³n conductual en PLCSIM Advanced | ðŸŸ¡ runner y protocolo verificados; comportamiento real pendiente |

### Tanda 5 â€” diagnÃ³stico y aceptaciÃ³n por familia

| # | Receta | Estado |
|---|---|---|
| [R18](R18-medidas-analogicas.md) | Medidas y seÃ±ales analÃ³gicas | ðŸ“„ procedimiento documentado; requiere mÃ³dulo/canal identificados y banco de prueba |
| [R19](R19-diagnostico-comunicaciones.md) | DiagnÃ³stico de comunicaciones | ðŸ“„ procedimiento documentado; handshake solo en endpoint aislado |
| [R20](R20-aceptacion-hmi-por-modelo.md) | AceptaciÃ³n HMI segÃºn modelo y Runtime | ðŸ“„ matriz documentada; Runtime/licencia local pendiente |
| [R21](R21-preflight-offline-release.md) | Preflight de la suite offline de release | âœ… preflight ejecutable; paquete de golden fixtures externo aÃºn bloqueado |

### Tanda 6 â€” ciclos PLC offline aceptados

| # | Receta | Estado |
|---|---|---|
| [R22](R22-tablas-watch.md) | Tabla Watch vacÃ­a: crear, exportar, compilar, guardar, borrar y leer | âœ… ciclo V20 verificado en fixture aislado; online/force excluidos |
| [R23](R23-instance-db.md) | Instance DB de un FB estÃ¡ndar: crear, compilar, exportar, guardar, borrar y leer | âœ… ciclo V20 verificado con nÃºmero explÃ­cito; `autoNumber=true`/DB0 bloqueado |
| [R24](R24-tabla-tags-offline.md) | Tabla de tags PLC vacÃ­a: crear, exportar, compilar, guardar, borrar y leer | âœ… ciclo V20 verificado en fixture aislado; importaciÃ³n y tags Safety excluidos |
| [R25](R25-grupo-bloques-offline.md) | Grupo vacÃ­o de bloques PLC: crear, borrar, compilar, guardar y leer | âœ… ciclo V20 verificado en fixture aislado; grupos con bloques excluidos |
| [R26](R26-importar-tabla-tags.md) | Importar una tabla PLC vacÃ­a o con dos tags Bool estÃ¡ndar, compilar, guardar, leer y restaurar carpeta | âœ… `tia-create/full` V20; tabla vacÃ­a y dos tags no Safety verificados; Safety y hardware excluidos |
| [R27](R27-automatizacion-ui-tia.md) | Automatizar la interfaz de TIA Portal: UIA donde TIA se expone, OCR de Windows donde no, entrada sintetica para el resto | ? motor 30-tools/tia-ui/Invoke-TiaUi.ps1 verificado abriendo un proyecto de principio a fin; el clic derecho sobre un item del arbol queda como clic humano |
| [R28](R28-aceptacion-plcsim.md) | Aceptacion de comportamiento en PLCSIM sin humano en el bucle: sesion adjunta, margen del Control Panel, UpdateTagList() y nombres de tag sin prefijo | ? verificado 2026-10-21 con FB_AlarmLatch: descarga 0/0 y plan de 65 pasos 65/65 |
| [R29](R29-portabilidad-powershell.md) | Portabilidad de los scripts de PowerShell y de los arneses de prueba: 5.1 frente a 7, mojibake que rompe el parser, gates antes del toolchain y evidencia de destino simulado | ? verificado 2026-10-21: los dos tests que tenian el CI en rojo, en verde con el job completo en local |

El orden y su porquÃ© estÃ¡n en [ADR-004](../../00-meta/decisiones/ADR-004-prioridades.md).

## DÃ³nde probar todo esto

En [`50-examples/`](../../50-examples/) hay **siete proyectos TIA reales** desempaquetados y
listos. No son de nadie: si se rompen, no pasa nada. Empieza por
`npatel-basement-light`, que es el mÃ¡s pequeÃ±o.


