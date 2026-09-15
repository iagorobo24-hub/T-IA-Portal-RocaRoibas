# ADR-006 — Límite de seguridad del agente

- **Fecha:** 2026-09-14
- **Estado:** ✅ Aceptada, escrita como regla dura en `AGENTS.md` §3.1
- **Pregunta origen:** TDD Q23 — respuesta: *PLCSIM libre, hardware con confirmación*

## Decisión

| Destino | Permiso |
|---|---|
| **PLCSIM** | Libre. El agente descarga, arranca, fuerza y prueba sin pedir permiso |
| **PLC físico** | **Confirmación explícita del usuario en ese momento.** Sin excepciones |

## Precisiones que no estaban en la pregunta pero hacen falta

Una respuesta de una línea no cubre los casos límite, así que los fijo aquí:

1. **"En ese momento" significa en ese momento.** Una autorización de hace diez mensajes no
   sirve. Una autorización para el PLC_1 no autoriza el PLC_2. Una autorización para descargar
   un bloque no autoriza descargar el hardware.
2. **Si no se puede distinguir con certeza si un target es simulado o real: se asume real.**
   Un `192.168.0.1` puede ser cualquiera de los dos. Ante la duda, se pregunta.
3. **Antes de proponer una descarga a hardware, el agente dice tres cosas:** qué PLC, qué se
   descarga, y **qué pasa si la máquina está en marcha**. Una descarga que exige STOP de la CPU
   no es lo mismo que una descarga en RUN.
4. **Ir online en modo lectura (monitorizar, leer valores) es libre** en ambos. Lo que se
   restringe es **escribir**: descargar, forzar, cambiar el modo de la CPU.
5. **Forzar variables en un PLC físico cuenta como escribir.** Requiere confirmación.

## Por qué esto se escribe y no se deja al criterio del modelo

Porque el fallo aquí no es un test rojo: es maquinaria moviéndose cuando alguien tiene la mano
dentro. El coste de pedir confirmación de más es unos segundos. El coste de no pedirla una vez
no se puede deshacer.

## Lo que NO restringe esta decisión

El agente **sí** puede, sin preguntar: leer todo, compilar, editar bloques en el proyecto
(con backup previo), exportar, importar, crear proyectos, y descargar a PLCSIM. La fricción está
puesta exactamente donde hay riesgo físico, y en ningún otro sitio.
