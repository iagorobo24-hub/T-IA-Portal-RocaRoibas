# R14 — Validar el binding HMI–PLC

## Objetivo

Demostrar que las tags de pantalla apuntan a señales reales del PLC y que el comportamiento no
depende de una dirección inventada o de una tabla de tags por defecto.

## Secuencia

1. Leer la configuración HMI y localizar la conexión PLC real.
2. Obtener las tags del PLC y sus rutas desde MCP.
3. Comparar nombre, tipo de dato, dirección simbólica y dirección física cuando exista.
4. En PLCSIM, cambiar una señal de prueba y observar la pantalla.
5. Escribir una orden desde la pantalla y verificar el efecto en el PLC simulado.
6. Provocar una alarma y verificar activación, texto, prioridad y rearme.

Un PLC compilado o una pantalla abierta no prueban el binding. Si la HMI y el PLC son de familias
o versiones incompatibles, el resultado queda bloqueado con el diagnóstico exacto.
