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
```

`--register-inspect` crea una instancia temporal, informa de sus propiedades y
la limpia; sirve para comprobar la base de la ruta de simulación.
`--register-disposable` es una prueba de ciclo de vida, no una prueba de
comportamiento del PLC. Las operaciones `PowerOn`, descarga y lectura/escritura
de tags requieren una fase de simulación explícita y sus propios gates de
seguridad.
