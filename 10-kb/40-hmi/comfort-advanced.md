# WinCC Comfort / Advanced y Runtime Advanced

Esta ruta aplica a HMI clásicas Comfort/Basic y a proyectos que se ejecutan con WinCC Runtime
Advanced. El agente debe comprobar el dispositivo concreto, la versión del proyecto y la versión
del Runtime Advanced.

## Flujo seguro

1. Obtener el árbol real del proyecto y localizar el HMI; no asumir `HMI_1`.
2. Leer tipo de dispositivo, conexiones al PLC, pantallas, tags y alarmas.
3. Confirmar que el runtime instalado puede compilar y ejecutar ese dispositivo.
4. Compilar la HMI y conservar el diagnóstico completo.
5. Iniciar Runtime Advanced solo con un proyecto de prueba o una copia.
6. Verificar al menos conexión PLC, navegación, una orden y una alarma.

El Runtime Advanced V17.0 HF8 instalado aquí no es evidencia de compatibilidad con un dispositivo
V20. La prueba de los juegos produjo el error de dispositivo no soportado; hasta disponer del
runtime compatible, el resultado correcto es **bloqueado por prerequisito**, no “simulado”.
