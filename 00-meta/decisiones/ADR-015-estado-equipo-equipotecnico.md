# ADR-015 — El estado del entorno es por máquina, y `equipotecnico` no tiene V20

- **Fecha:** 2026-09-22
- **Estado:** abierta — requiere decisión del usuario entre las salidas A, B y C
- **Sustituye parcialmente a:** la sección 9 de `AGENTS.md` ("Estado del entorno")
- **Evidencia:** `70-runs/entorno/20260922-equipotecnico-inventario.md`

## Contexto

El workspace se ha copiado a un segundo equipo (`equipotecnico`, usuario Windows `Dpto. Técnico`).
Al inventariarlo aparece una contradicción con el contrato:

`AGENTS.md` §9 afirma, sin cualificar por máquina, que el entorno tiene TIA Portal **V20**, PLCSIM
**V19**, PLCSIM Advanced **V6.0.0.1** y los dos servidores MCP compilados y verificados.

En `equipotecnico` están instalados **TIA Portal V15.1, V16, V17 y V18**. No hay V19, V20 ni V21.
Los binarios `tia-inspect` y `tia-create` del workspace están compilados contra Openness V20 y no
pueden cargar aquí. El `.mcp.json` y `servers.local.json` apuntan a `C:\Users\jose.mellid\...`.

El `TiaMcpServer.startup.log` presente en el árbol registra arranques correctos con
`Siemens TIA Openness group membership: True`, pero todas sus entradas llevan
`BaseDir: C:\Users\jose.mellid\...`. **Es evidencia del otro equipo que viajó con la copia.**

## Problema de fondo

Un contrato que afirma un estado de entorno global induce al agente a dar por bueno lo que no lo
está. El agente lee `AGENTS.md` §9, concluye que hay V20 y que el grupo de Windows está resuelto, y
opera sobre una premisa falsa. En este dominio esa clase de optimismo es exactamente la que el resto
del contrato existe para impedir.

## Decisión

1. **El estado del entorno deja de ser una afirmación de `AGENTS.md` y pasa a ser un artefacto
   generado por máquina.** `Doctor` escribe `70-runs/doctor/<hostname>.json`; `AGENTS.md` §9 pasa a
   apuntar a ese artefacto y a declarar que, si no existe para el hostname actual, el entorno está
   **no verificado** y el agente debe parar antes de tocar TIA.
2. **Ninguna evidencia heredada de otro equipo vale como verificación local.** Los logs, manifiestos
   y `package-info.json` copiados se tratan como histórico, no como estado. El
   `TiaMcpServer.startup.log` heredado se archiva.
3. **La ruta V18 no se da por viable hasta que se investigue.** No es un cambio de configuración: es
   un port. Ver el apartado siguiente.

## Las tres salidas para este equipo

### A — Instalar TIA V20 (o V21) en `equipotecnico`

Lo ya construido funciona cambiando rutas y regenerando la configuración. Única salida que conserva
SIMATIC Source Documents (texto legible de LAD/FBD desde V20 Upd.4 / V21). Coste: licencia, disco y
tiempo. Comprobar antes si la licencia flotante admite una instalación más.

### B — Portar `tia-inspect` a V18

`30-tools/mcp/tia-inspect/build.ps1` tiene `[ValidateSet(20, 21)]` y documenta que **V19 ya está
descartado** porque la API de documentos SIMATIC SD (`.s7dcl`/`.s7res`) no existe antes de Openness
V20 (ADR-002). Su mapa de paquetes NuGet solo cubre 19, 20 y 21.

Portar a V18 exige: añadir `18` al `ValidateSet`, localizar el paquete
`Siemens.Collaboration.Net.TiaPortal.Packages.Openness` `18.0.x`, bajar el suelo de detección de
`Diagnostics.cs`, y compilar fuera toda la funcionalidad de documentos SIMATIC SD más lo que aparezca
por el camino. Al terminar se habría perdido justo lo que hace legible el LAD.

Solo tiene sentido si el parque de clientes es mayoritariamente ≤ V18 y la decisión es estratégica.

### C — `equipotecnico` como máquina de auditoría legacy y capa de reglas

La tarea de revisión contra el *Programming Styleguide for S7-1200/1500* (entry **109478084**) y las
*Top 20 Secure PLC Coding Practices* es **nivel N0**: trabaja sobre los `.scl` ya exportados y **no
necesita TIA Portal ni Openness**. Igual que buena parte de la documentación automática y de la
detección de anomalías sobre fuentes exportadas.

Además, tener V15.1, V16, V17 y V18 en una misma máquina es precisamente lo que hace falta para
auditar el parque legacy de clientes, que es donde está el volumen.

## Recomendación

**C ahora, A en paralelo.** C no depende de ninguna licencia, no bloquea nada, empieza a producir de
inmediato, y construye la única pieza que ningún proyecto del ecosistema open source ofrece. Si más
adelante se instala V20 aquí, C sigue siendo válida entera.

B queda como opción estratégica, no de conveniencia, y no se acomete sin un estudio previo de
viabilidad que reporte antes de tocar código.

## Consecuencias

- `AGENTS.md` §9 debe reescribirse. Mientras no se haga, **su contenido no aplica a `equipotecnico`**.
- El fixture `TestProject1.zap20` no sirve aquí; hace falta uno de la versión que se acabe usando.
- Cualquier sesión de agente en este equipo debe empezar por `Doctor` y parar si no hay artefacto de
  entorno local.
