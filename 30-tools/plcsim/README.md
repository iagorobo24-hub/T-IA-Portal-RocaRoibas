# PLCSIM Advanced runtime probe

Este componente comprueba la presencia y la inicialización de la API nativa de
PLCSIM Advanced. Es deliberadamente de solo lectura: no registra instancias, no
enciende controladores virtuales y no descarga ningún programa.

La API V6.0 instalada expone:

- `Siemens.Simatic.Simulation.Runtime.Api.x64.dll`
- `SimulationRuntimeApi.h`
- entry points `RuntimeApiEntry_Initialize` y `RuntimeApiEntry_DestroyInterface`

El probe valida esos dos entry points, puede consultar el número de instancias
registradas y libera inmediatamente el manager. La automatización de instancias
se añadirá solo después de tener una prueba aislada de registro, apagado y
limpieza.

```powershell
dotnet run --project .\30-tools\plcsim\TiaClaude.PlcSimProbe.csproj -- --json
```

Para incluir la consulta del contador del Runtime Manager:

```powershell
dotnet run --project .\30-tools\plcsim\TiaClaude.PlcSimProbe.csproj -- --json --manager-count
```

La ubicación por defecto es la instalación V6.0 de Siemens. Para probar otra,
se puede pasar `--api-dll <ruta-completa>`.
