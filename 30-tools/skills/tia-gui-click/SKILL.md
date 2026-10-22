---
name: tia-gui-click
description: Realiza interacciones seguras con la interfaz gráfica de TIA Portal o PLCSIM mediante el candado de clic con hit-test de PID, topmost y evidencia. Usar cuando haya qué pulsar algo en la GUI (menús contextuales, diálogos, botones de simulación, aceptar certificados), para diagnosticar qué hay en un punto de la pantalla, o cualquier paso que el playbook GUI catalogue como nivel 2.
---

# tia-gui-click — operaciones GUI con candado (nivel 2 del playbook)

> **Estado: BORRADOR REFERENCIA.** El candado `Invoke-TiaGuiClick.ps1` está probado en
> sus dos ramas (OK y MISMATCH) el 2026-10-23. Esta skill fija cuándo y cómo se usa,
> no sustituye al playbook.

## Cuándo usarlo

- El pasoreso requiere un clic humano-simulado: menú contextual del árbol, botones que
  Openness no expone, diálogos de sesión y confirmación.
- Diagnóstico: "¿qué hay en este punto de la pantalla?" (sin pulsar).
- Nunca para mutar el modelo de ingeniería si existe herramienta MCP equivalente: eso
  es nivel 1 (MCP/Openness) y siempre va primero.

## Reglas firmes

1. Punto = PID: sin embargo el hit-test bine, el clic NO sale salvo `-ForceAtPoint`
   con razón explícita registrada (y nunca en el primer intento).
2. `SendInput` solamente; nada de `mouse_event` ni de `SendKeys` a ciegas.
3. TIA/PLCSIM en el escritorio virtual activo y primer plano; **nunca cambiar de
   escritorio virtual** (bug de fondo negro medido en 50-errores).
4. Si hay ventanas del usuario delante del objetivo: parar y consultar.
5. Coordenadas de la sesión, recalculadas y guardadas con su evidencia.

## Pasos

1. [⭐] Medir proceso/ventana objetivo (PID, rec, título) + captura de confirmación.
2. [⭐] `.\Invoke-TiaGuiClick.ps1 -X <x> -Y <y> -ExpectedPid <pid> -InspectOnly`:
   debe salir OK; si MISMATCH se resuelve la disposición.
3. [⭐] Clic con `-RaiseTopmost -EvidencePath 70-runs/<tarea>/ui/click-<paso>.json
   -AfterShot …png`; un clic; `Right` sólo para menús contextuales.
4. [⭐] Verificar efecto (captura + estado MCP cuando aplique), y solo entonces el
   siguiente paso.
5. [⭐] Cierre: tal estaba el estado de ventanas; topmost devuelto si se usó en ventanas
   ajenas.

## Verificación

- Cada clic deja el JSON de evidencia y la captura; sin evidencia, no pasó.
- El resumen al usuario cuenta paso a paso qué se esperaba y qué se vio.

## Si falla

| Fallo | Acción |
|---|---|
| MISMATCH repetido | revisar el layout: ¿la ventana se movió? ¿hay otra app delante? |
| El clic no produce el efecto esperado | captura del estado; no reintentar a oscuras; re-medir |
| TIA no repinta | espera 1-2 s; TIA tarda; no empujar | 
| Se abre un diálogo no deseado | cancelar correctamente siguiendo su propio flujo.Nunca dejarlo a medias |

## Referencias

- Playbook: `10-kb/00-fundamentos/playbook-gui-tia.md` (ritual completo y anclajes)
- Candado: `30-tools/tia-ui/Invoke-TiaGuiClick.ps1`


## Encadenamiento

Si aparece cualquier fallo no cubierto arriba — o si un fallo conocido reaparece en un contexto distinto — cargar la skill [`tia-error-triage](../tia-error-triage/SKILL.md) antes de reintentar nada. Las skills no se disparan solas: el disparo depende de que el agente lea la descripcion; este encadenamiento lo hace explicito en el propio runbook, que es la unica palanca real que tenemos.
