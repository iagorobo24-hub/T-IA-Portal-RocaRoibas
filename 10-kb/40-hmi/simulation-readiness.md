# Preflight de simulación

`Write-TiaSimulationReadiness.ps1` genera un informe de solo lectura antes de tocar TIA, PLCSIM
o Runtime. No abre programas, no descarga y no cierra procesos.

El informe separa cuatro hechos que no deben mezclarse:

- **Toolchain PLC:** TIA/Openness V20, `tia-inspect` y PLCSIM Advanced instalados.
- **Runtime HMI:** existe una instalación real y compatible de WinCC Runtime Advanced V20. Un
  driver V20 o un Runtime V17 no pasan esta puerta.
- **Comportamiento:** hay una evidencia `sorting-plant-acceptance.json` con `status: verified`.
  Compilar no cuenta como prueba de comportamiento.
- **Seguridad de sesión:** no hay una instancia visible de TIA que pueda ser reemplazada por el
  runner de scaffold.

Ejecutar:

```powershell
.\30-tools\scripts\Write-TiaSimulationReadiness.ps1
```

Estados:

- `READY`: todas las puertas y evidencias están verificadas.
- `READY_WITH_BLOCKERS`: el camino PLC está preparado, pero queda alguna dependencia o prueba.
- `NOT_READY`: falta una pieza básica del toolchain.

En esta máquina el resultado esperado es `READY_WITH_BLOCKERS`: PLCSIM Advanced V6.0 está
instalado, pero Runtime Advanced V20 compatible y la prueba conductual aún no están verificados.
