---
name: tia-scl-worksession
description: Abre una sesión de programación funcional de bloques SCL en TIA Portal con el ciclo completo backup-lee-propone-preview-compila-guarda-exporta-commitea. Usar cuando el usuario pide sesiones de programación, "vamos a tocar el motor", "añade una función", "arregla este bloque" o cualquier edición de lógica estándar. Respeta el bloqueo de aplicación vigente: el paso de aplicar propuestas solo corre si existe importador acotado verificado.
---

# tia-scl-worksession — sesión de programación funcional

> **Estado: BORRADOR MUTANTE.** Es la skill más regulada: hereda todas las compuertas de
> `AGENTS.md` §6. La *propuesta* está verificada; la *aplicación* está `BLOCKED` por
> diseño hasta que el perfil registre un importador acotado probado.

## Cuándo usarlo

- "Vamos a programar el ciclo del motor", "añade una maniobra nueva", "haz esta función".
- El usuario define qué quiere conseguir y acepta el ciclo con compilación 0/0 como
  requisito de "terminado".
- Si el bloque objetivo es know-how protection o F/Safety: **esta skill no es la que
  toca**; se informa y se para.

## Antes de empezar

1. `AGENTS.md` §6 leído y reproducido en la conversación de apertura: los pasos no son
   opcionales.
2. Backup del `.ap20` antes de la primera escritura (real, con copia, no confiar en
   "ya está bien": verificar la copia).
3. Proyecto y bloque objetivo leídos por completo antes de proponer cambios.
4. Decidir la hoja de ruta con el usuario: bloques afectados, esperado del cambio y cómo
   se prueba (simulación PLCSIM si toca, con la skill `tia-plcsim-acceptance`).

## Pasos

1. [⭐] Esqueleto igual que `tia-analyze-project` (1-5): tree, software, seguridad, CPU.
2. [⭐] ¿Existe ya en `60-library/`? ¿lo cubre una receta? Antes de escribir bloque nuevo:
   mirar las dos cosas (60-library y recetas).
3. [⚠] Propuesta con `New-TiaSclProposal.ps1` o `Invoke-TiaWorkflow.ps1 -Workflow propose`
   (verificado en acciones fuera mutación).
4. [⚠] Preview local sin conexión: el preview nunca se presenta como cambio aplicado.
5. [⚠] Intento de aplicación con `Invoke-TiaSclProposalApply.ps1 -Apply`: hoy termina
   `BLOCKED` (sin importador acotado en el inventario V20); ESO ES UN RESULTADO VÁLIDO:
   se declara así y se elabora la propuesta igualmente.
6. [⭐] Compilación en fixture aislado (o proyecto propio) con 0 errores y 0 advertencias;
   si falla, se revierte o se arregla y nunca se guarda con errores.
7. [⭐] `SaveProject`/`Save: guardar` fuera de la transacción de la mutación (SaveGuarded).
8. [⚠] Exportar a `src/` y hacer el commit funcional con "QUÉ cambió", no "update".
9. [⚠] Cierre: estado final verificable, pendiente declarado, sesión limpia.

## Verificación

- Cada cambio que afirma la skill tiene readback (`GetBlockSource` tras escribir) y el
  estado de compilación en la conversación con números.
- Bloque marcado como terminado solo si: compila 0/0, exporta, commitea y (si se acordó)
  pasa en PLCSIM el plan funcional.

## Si falla

- Compilación ≠ 0 → se arregla o se revierte; nunca se guarda a medias.
- `BLOCKED` en aplicar → se deja propuesta preparada y se expone el próximo paso real.
- Duda de permisos de escritura, protección o versiones → para y pregunta; no improvisar.

## Referencias

- Contrato: `AGENTS.md` §6 (ciclo), §3.3 (bloques protegidos)
- Recetas: `R28-aceptacion-plcsim.md`, `R30-crear-proyecto-desde-spec.md`
- ADR-002 (lenguajes) y la receta R30 si la sesion crea bloques nuevos


## Encadenamiento

Si aparece cualquier fallo no cubierto arriba — o si un fallo conocido reaparece en un contexto distinto — cargar la skill [`tia-error-triage](../tia-error-triage/SKILL.md) antes de reintentar nada. Las skills no se disparan solas: el disparo depende de que el agente lea la descripcion; este encadenamiento lo hace explicito en el propio runbook, que es la unica palanca real que tenemos.
