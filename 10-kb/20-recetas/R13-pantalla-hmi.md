# R13 — Validar una pantalla HMI

## Precondiciones

- versión TIA y dispositivo HMI leídos del proyecto;
- runtime correspondiente instalado y compatible;
- copia del proyecto y permiso para iniciar solo simulación;
- PLC real nunca se usa como target por defecto: PLCSIM o confirmación explícita.

## Secuencia

1. Doctor y conexión al proyecto.
2. Obtener árbol real de dispositivos, HMI y software PLC.
3. Documentar dispositivo, runtime, licencia y conexión PLC.
4. Compilar HMI y PLC por separado; registrar todos los diagnósticos.
5. Iniciar el runtime/simulador compatible.
6. Probar navegación, una tag de lectura, una orden de escritura y una alarma.
7. Guardar capturas o resultados en `70-runs/simulation/`.

Si aparece “device is not supported”, se detiene el flujo y se documenta la incompatibilidad.
