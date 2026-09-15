# WinCC Unified

Unified tiene un runtime y un modelo de pantallas distintos de WinCC Comfort/Advanced. No se debe
intentar abrir un proyecto Unified V20 con Runtime Advanced clásico V17 ni interpretar un driver
instalado como si fuera el runtime Unified.

## Precondiciones

- dispositivo HMI identificado desde el árbol del proyecto;
- WinCC Unified Runtime/Simulator compatible con la versión de ingeniería;
- licencia o modo de evaluación disponible;
- conexión PLC configurada y comprobable;
- proyecto copiado antes de cualquier prueba de ejecución.

## Criterio de éxito

La pantalla arranca sin error, el runtime establece la conexión prevista, una tag cambia en ambos
sentidos, una navegación funciona y una alarma se dispara y se reconoce. Cada resultado debe
quedar en `70-runs/simulation/`; compilar no basta.
