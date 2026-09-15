# ADR-012 — `Connect` no se considera `Attach`

**Fecha:** 2026-09-15  
**Estado:** aceptada  
**Ámbito:** sesiones MCP y TIA Portal V20

## Decisión

El agente no tratará un `Connect` exitoso como prueba de que está conectado a la ventana visible
del usuario. Antes de escribir necesita un proyecto inequívocamente identificado por el árbol
real. Si existe una ventana visible y el servidor no ofrece `Attach`, la sesión queda bloqueada
para escrituras y el agente debe usar una interfaz gráfica disponible o pedir al usuario que
libere/confirme la instancia.

## Evidencia

- El roster de `tia-inspect` V20 contiene `Connect`, pero no `Attach`.
- En la sesión de comprobación, `Connect` devolvió éxito, pero `GetProjectTree` falló con
  `Failed retrieving project tree` porque la conexión no tenía proyecto.
- El proceso visible de TIA se mantuvo separado de esa conexión.

La evidencia operativa se puede repetir con el smoke del servidor y la cadena de lectura de
`30-tools/scripts/Invoke-TiaMcp.ps1`. Esto no prueba que todos los servidores MCP ni todos los
harnesses carezcan de `Attach`; solo fija el comportamiento del servidor instalado aquí.

## Consecuencia

Los runners de creación mantienen su guardia contra una instancia visible. Un agente puede
seguir haciendo diagnóstico read-only, pero no debe abrir un proyecto paralelo, asumir el destino
por nombre de ventana o presentar la sesión headless como si fuera la sesión del usuario.
