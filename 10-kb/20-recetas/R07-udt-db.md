# R07 — Crear UDTs y bloques de datos

## Objetivo

Crear tipos de datos y DBs con dependencias explícitas y compilables, manteniendo la separación
entre estructura de datos y lógica SCL.

## Secuencia recomendada

1. Leer el árbol real del PLC y resolver grupos de tipos y bloques.
2. Definir primero el UDT (`kind=udt`) con `members` (`name`, `datatype`, comentario).
3. Ejecutar `PlcBuildAndImport(..., kind="udt", dryRun=true)` y revisar el XML/plan devuelto.
4. Importar el UDT con `dryRun=false`, leerlo de vuelta y compilar.
5. Definir el DB global (`kind=globaldb`) que use el UDT; repetir dry-run, importación, lectura y
   compilación.
6. Guardar solo con 0 errores y 0 avisos, y exportar tipos/DB a `src/`.

El orden de dependencias es **UDT → global DB → bloques que lo usan**. Un FB con algoritmo o
expresiones no se genera con el DSL de `PlcBuildAndImport`: se importa como fuente SCL y después
se compila.

## Límites

No editar F-blocks, DBs de safety ni tipos protegidos. La eliminación o cambio de un UDT requiere
leer referencias cruzadas, porque puede romper interfaces y DBs aunque el error aparezca tarde.
