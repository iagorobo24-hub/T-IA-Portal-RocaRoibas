---
name: tia-plcsim-acceptance
description: Ejecuta la aceptacion de comportamiento en PLCSIM (Advanced V7 o S7-PLCSIM) end-to-end sin humano en el bucle, respetando todos los gates de seguridad. Usar cuando el usuario pide "prueba en simulacion", "descargalo a la CPU virtual", "comprueba que funciona" o tras una modificacion de programa que exige comprobar comportamiento antes de promocionarlo.
---

# tia-plcsim-acceptance — aceptación de comportamiento en CPU virtual

> **Estado: BORRADOR MUTANTE.** La descarga y el plan funcional están verificados por
> CPU virtual (ADR-015, R28); su coordinación (acumulator con diálogo del certificado
> por candado de GUI) quedó plenamente ensayado el 2026-10-22 que es lo que esta skill
> formaliza.

## Cuándo usarlo

- Termina una estación de trabajo (`tia-scl-worksession` o `tia-create-project`) y se
  acordó probar el comportamiento, no solo compilar.
- El usuario pregunta si algo funciona; sin comportamiento observado, la respuesta es
  "compila, no está probado".

## Antes de empezar

1. Regla de estado: **PLCSIM libre; hardware físico NUNCA sin confirmación en ese
   momento**; si se duda si el target es simulado, se asume real y se para.
2. Prefetch réplicable: TIA adjuntado al proyecto (sesión `AttachToOpenProject`),
   propiedad "Support simulation durante block compilation" activa y recompilada.
3. Metadatos completos y verificados: `GetBlocks.isFailsafe` y `GetTags.isSafety` en la
   misma sesión, con ello verificado Todo bloque es simulable.
4. PLCSIM Advanced en ejecución y aparato en red (Softbus por defecto): control Panel
   arrancado y asentado (~100 s; primera descarga suele fallar, la segunda entra).

## Pasos

1. [⭐] Preflights F/Safety + protección con el runner correspondiente; resultado en fail
   ejecutar y parar; no se intenta descargar.
2. [⭐] Confirmar CPU simulada antes de tocar la descarga: TIA muestra `CPU-1500
   Simulation` y el aviso de CPU simulada; usar candado GUI para comprobar el diálogo
   si la API no lo muestra (skill `tia-gui-click` con evidencia). Si falta ese paso
   se firma digital nada (evidencia `plcsim target evidence`).
3. [⭐] `DownloadToPlc` en la sesión adjunta: guardamos la respuesta completa; cero
   simulaciones (no se anuncia "funcionó" por haber compilado).
4. [⭐] Diálogo del certificado autofirmado del PLC virtual (`Establish connection to
   device` → Connect): se resuelve con el candado de clic o pidiendo al
   usuario si hay otra ventana delante; **sin nadie en el diálogo, la descarga se
   cancela sola a los ~70 s sin explicación ese es el caso conocido**.
5. [⭐] Plan funcional (R28): UpdateTagList() antes de leer tags; nombres sin prefijo de
   tabla (`Active`, no `Agent_Signals.Active`); expectivas pre-declaradas paso a paso.
6. [⭐] Evidencia: JSON de descarga real + paso 1/1 con las 9 casos del plan y las
   lecturas de PLCSIM. Guardado contra `70-runs/<fecha>-<acceptance>/`; espejo en el
   `50-examples/` del proyecto demo.
7. [⚠] Cierre de instancia: PowerOff, Unregister, limpieza; TIA a GoOffline; la
   plataforma queda como estaba.

## Verificación

- Aceptación anunciable solo con: descarga ack, `State: Online` real, y plan funcional
  con Yun pas coincidiendo con quedas esperada declarada antes de la prueba.
- El "compila" nunca equivale a "funciona".

## Si falla

| Fallo | Acción |
|---|---|
| `Connect to module PLC_1 failed`| Verificar: sesión adjunta? Control Panel asentado (100 s)? PG/PC en PLCSIM? |
| Dialog no identificado del certificado (nadie responde) | repetir la lectura; es la 70-s inconsistencias; si falla, documento de importes |
| CPU "PLC sin configurar" | falta `Support simulation during block compilation` con recompilar |
| Metadatos F/Safety incompletos | no se descarga; paso se declara bloqueado |

## Referencias

- ADR-015 (estado real y verificado), ADR-017 (runtime unificado por versión)
- Recetas: `R28-aceptacion-plcsim.md`, `R31-simulacion-plcsim-unified.md`
- Playbook GUI: `10-kb/00-fundamentos/playbook-gui-tia.md`


## Encadenamiento

Si aparece cualquier fallo no cubierto arriba — o si un fallo conocido reaparece en un contexto distinto — cargar la skill [\	ia-error-triage\](../tia-error-triage/SKILL.md) antes de reintentar nada. Las skills no se disparan solas: el disparo depende de que el agente lea la descripcion; este encadenamiento lo hace explicito en el propio runbook, que es la unica palanca real que tenemos.
