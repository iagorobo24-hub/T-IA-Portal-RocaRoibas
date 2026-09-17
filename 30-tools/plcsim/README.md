# PLCSIM Advanced runtime probes

Este componente comprueba la presencia y la inicialización de la API nativa de
PLCSIM Advanced. Incluye dos niveles:

- el probe administrado, que solo inicializa la API y consulta el contador;
- el adaptador C++ nativo, que además registra una CPU virtual temporal y la
  desregistra inmediatamente, sin encenderla ni descargar ningún programa.

La API V6.0 instalada expone:

- `Siemens.Simatic.Simulation.Runtime.Api.x64.dll`
- `SimulationRuntimeApi.h`
- entry points `RuntimeApiEntry_Initialize` y `RuntimeApiEntry_DestroyInterface`

El probe valida esos dos entry points, puede consultar el número de instancias
registradas y libera inmediatamente el manager. El adaptador nativo añade una
prueba aislada de registro y limpieza, manteniendo apagados los controladores.

```powershell
dotnet run --project .\30-tools\plcsim\TiaClaude.PlcSimProbe.csproj -- --json
```

Para incluir la consulta del contador del Runtime Manager:

```powershell
dotnet run --project .\30-tools\plcsim\TiaClaude.PlcSimProbe.csproj -- --json --manager-count
```

La ubicación por defecto es la instalación V6.0 de Siemens. Para probar otra,
se puede pasar `--api-dll <ruta-completa>`.

El adaptador nativo requiere LLVM `clang-cl`, Visual Studio Build Tools con el
Windows SDK y la API instalada por PLCSIM Advanced:

```powershell
.\30-tools\plcsim\Build-PlcSimAdapter.ps1 -Force
.\30-tools\plcsim\bin\v6\tia-claude-plcsim-adapter.exe --inspect
.\30-tools\plcsim\bin\v6\tia-claude-plcsim-adapter.exe --register-inspect
.\30-tools\plcsim\bin\v6\tia-claude-plcsim-adapter.exe --register-disposable
.\30-tools\plcsim\bin\v6\tia-claude-plcsim-adapter.exe --power-on-disposable
```

`--register-inspect` crea una instancia temporal, informa de sus propiedades y
la limpia; sirve para comprobar la base de la ruta de simulación.
`--register-disposable` es una prueba de ciclo de vida, no una prueba de
comportamiento del PLC. `--power-on-disposable` añade un arranque y apagado
controlados de la CPU virtual, pero tampoco descarga un proyecto ni lee/escribe
tags. La descarga y la prueba de comportamiento requieren una fase de
simulación explícita y sus propios gates de seguridad.

## Instancia persistente para aceptación

Cuando el preflight confirme que el adaptador está operativo, se puede registrar una CPU
virtual persistente con el mismo tipo que el proyecto Sorting Plant (`CPU 1516F-3 PN/DP`):

```powershell
.\30-tools\plcsim\bin\v6\tia-claude-plcsim-adapter.exe `
  --register-acceptance `
  --name TIAClaudeAcceptance_1516F `
  --ip 192.168.0.1 `
  --interface "Siemens PLCSIM Virtual Ethernet Adapter"
```

El proceso enumera el adaptador, lo enlaza a `IE1`, configura la IP, aplica el binding de
PLCSIM, enciende la CPU y permanece vivo. Mientras está vivo, TIA puede descargar el proyecto
al target virtual. Para terminarlo se envía `stop` por stdin; entonces apaga, desregistra y
libera la instancia. Si el adaptador no está operativo, el comando termina sin registrar una
CPU y devuelve las interfaces disponibles. No se debe usar este modo con una interfaz física.

⚠️ **Bloqueo conocido, sin resolver (2026-09-17):** con el adaptador `Up` en Windows y el
binario nativo recién reconstruido (`--inspect`/`--register-inspect` en `status: ready`, todos
los códigos `0x0`), este paso concreto (`configure`) falla con `mappingCode: 0xffffffed` /
`ipCode: 0xfffffff2` / `bindingCode: 0xffffffed`. Probado con y sin elevación, y con la UI de
PLCSIM Advanced cerrada: mismo resultado. Son códigos de la API de runtime de PLCSIM Advanced,
sin documentación en este repo — no se ha identificado la causa raíz. Antes de reintentar a
ciegas, consultar documentación oficial de Siemens sobre estos códigos, probar con el perfil de
red del adaptador en Privado, o con una IP distinta de `192.168.0.1`. Evidencia completa del
intento: `70-runs/acceptance/plcsim-ip-binding-20260917.json` (no versionado, local).

Mientras la instancia está viva acepta comandos de stdin, uno por línea, y devuelve un JSON por
línea. Las áreas admitidas son `input`, `output` y `marker`; el offset es un byte:

```text
read-area-size input
write-bit input 0 0 1
read-bit output 0 0
write-byte input 1 255
read-byte output 0
write-bool-tag Control_HMI.fromHMI.resetSimulation 1
read-bool-tag Control_HMI.toHMI.resetStatus
read-uint8-tag Control_HMI.toHMI.numWorkpieces
read-float-tag Control_HMI.fromHMI.longConveyor.varSpeedPercentage
stop
```

Este protocolo permite que una aceptación escriba sensores virtuales y lea salidas sin tocar un
PLC físico. Las operaciones `*-tag` usan los símbolos descargados de la CPU y permiten accionar
controles HMI y observar contadores sin depender de direcciones absolutas. El runner debe comprobar
`status: ok` y registrar cada respuesta; un error de lectura o escritura invalida la evidencia de
comportamiento.
