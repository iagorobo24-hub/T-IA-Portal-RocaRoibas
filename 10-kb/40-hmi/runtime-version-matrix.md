# Matriz local de versiones HMI

Esta tabla separa hechos comprobados de condiciones que aún deben probarse. No se debe rellenar
“compatible” por intuición.

| Ingeniería/proyecto | Runtime o simulador | Estado en esta máquina | Evidencia/acción |
|---|---|---|---|
| TIA/WinCC V20, dispositivo Comfort/Advanced V20 | WinCC Runtime Advanced V17.0 HF8 | **No compatible verificado** | La compilación HMI informó que el dispositivo no está soportado |
| TIA/WinCC V20, dispositivo Unified V20 | WinCC Unified Runtime compatible | No verificado | Requiere comprobar instalación, licencia y versión del runtime Unified |
| TIA/WinCC V20, PLC S7 | PLCSIM/PLCSIM Advanced | PLC independiente de la HMI | Compilar y simular el PLC no valida la pantalla |

Inventario local: `70-runs/environment/latest.json`. El ejecutable Runtime Advanced localizado es
`C:\Program Files (x86)\Siemens\Automation\WinCC RT Advanced\HmiRTm.exe`, versión V17.0 HF8; también
aparece un driver con versión 20, pero un driver no equivale al runtime completo.

## Regla operativa

1. Leer el dispositivo HMI y la versión del proyecto.
2. Identificar el runtime exacto que se va a iniciar.
3. Comprobar licencia y compatibilidad antes de compilar la HMI.
4. Registrar el error literal si TIA dice que el dispositivo no está soportado.
5. No declarar simulación exitosa solo porque el PLC compile o porque se abra una ventana.
