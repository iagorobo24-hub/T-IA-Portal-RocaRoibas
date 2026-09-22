# R01 — Inventariar un proyecto que no conoces

**Objetivo.** Abrir un proyecto ajeno y saber en 5 minutos qué hay dentro: dispositivos, PLCs,
bloques, tipos, tags, y por dónde empezar a mirar.

**Precondiciones**
- `Doctor` en verde, con `User in 'Siemens TIA Openness' user group: True`
- Ruta exacta del `.ap20`; trabajar desde copia si el proyecto es antiguo o TIA puede actualizarlo
- Saber si TIA Portal ya está abierto y qué proyecto muestra

**Servidor.** `tia-inspect` perfil `read`. Este perfil oculta herramientas de escritura, pero abrir o
actualizar un proyecto y compilar pueden guardar estado interno; usa una copia.

---

## Secuencia

### 1. Entrar

1. Ejecuta `Doctor` y revisa grupo Openness, versión activa, modo del server y estado de conexión.
2. Si una ventana de TIA está abierta, identifica visualmente su proyecto mediante Computer Use
   cuando esa capacidad esté disponible. Si no puedes identificar la ventana/proyecto, para: no
   intentes `Connect`, `OpenProject`, cerrar ni sustituir la instancia.
3. Comprueba el schema del servidor/perfil concreto. `tia-inspect` read no expone
   `AttachToOpenProject`; que aparezca en un schema guardado de `tia-create full` no la habilita en
   `tia-inspect read`. Usa Attach sólo si el server activo lo publica y el proyecto visible ya se
   identificó como el objetivo solicitado.
   Si el perfil activo no ofrece Attach, limita la revisión a la interfaz visible en modo lectura
   o detente y pide que liberen/confirmen la instancia; no uses `Connect`/`OpenProject` como
   sustituto del Attach.
4. Si no hay proceso TIA, inicia `Connect`, ejecuta `GetState` y confirma que no hay otro proyecto
   abierto. Sólo entonces abre la ruta exacta pedida. Si `GetState` devuelve otro proyecto, para sin
   cerrarlo ni sustituirlo.

```text
Doctor → identificar instancia/target → verificar Attach en el perfil → Connect/Attach
→ GetState → OpenProject sólo si no hay proyecto abierto y el target es exacto
```

🔒 `Connect` no significa que la ventana visible esté adjunta. Si TIA muestra otro proyecto o no
puedes distinguir la instancia, detente. Para proyectos V16/V17, primero copia la carpeta completa
en `90-tmp/`: TIA V20 puede convertir el proyecto.

### 2. El mapa de arriba

```
GetProjectTree
```

Devuelve dispositivos, device items, grupos y el software de cada PLC/HMI.

🔒 **De aquí salen los `softwarePath` reales.** `PLC_1`, `PC-System_1/Software PLC_1`,
`HMI_RT_1`… Todo lo demás depende de esto. No inventes ninguno.

### 3. El resumen del PLC

```
GetPlcSummary(softwarePath: "PLC_1")
```

La forma más rápida de saber el tamaño de lo que tienes delante: cuántos bloques, de qué tipos,
cuántas tags. **Hazlo antes de pedir el árbol completo**, porque te dice si te lo puedes permitir.

### 4. El árbol del software, por partes

```
GetSoftwareTree(softwarePath: "PLC_1", sections: "blocks")
GetSoftwareTree(softwarePath: "PLC_1", sections: "types,tags")
```

🔒 **Usa `sections`.** Acepta cualquier subconjunto de `blocks,types,tags,watch,sources`; por
defecto trae todo. En un PLC grande, pedirlo entero llena la respuesta de ruido y puede cortarse.

Aquí es donde aparecen las **rutas reales de los bloques**, relativas a la raíz:
`40_Devices/FB_Motor`, no `Program blocks/40_Devices/FB_Motor`.

### 5. La foto del hardware

```
GetDevices
GetDeviceInfo(...)      ← para cada dispositivo que importe
```

Qué CPU, qué módulos, qué interfaces. Si necesitas direcciones de E/S y canales, eso está en
`tia-create` → `read_hardware_config` con `includeIoDetails`.

### 6. Por dónde empezar a leer el programa

El orden de lectura que más rápido da sentido a un programa ajeno:

```
1. OB1 / Main                   → GetBlockSource
2. lo que OB1 llama, en orden   → GetBlocksWithHierarchy
3. los DB globales              → GetBlockInterface
4. las tablas de tags           → GetPlcTagTables → GetTags o ExportPlcTagTable vía FindTools/CallTool
```

`GetBlocksWithHierarchy` es la clave: te da el árbol de llamadas, no una lista plana. Un programa
se entiende siguiendo el flujo desde OB1, no leyendo bloques por orden alfabético.

---

## Verificación

Has terminado cuando puedes responder, sin volver a mirar:

- [ ] ¿Cuántos PLCs y HMIs hay, y cómo se llaman exactamente?
- [ ] ¿Qué CPU es y qué módulos tiene?
- [ ] ¿Cuántos bloques, y cómo están agrupados?
- [ ] ¿Qué llama OB1, y en qué orden?
- [ ] ¿Dónde están las tags de E/S físicas?

---

## Si falla

| Síntoma | Causa | Arreglo |
|---|---|---|
| `InvalidState` | No hay conexión o proyecto abierto | Sólo con target confirmado: `Connect` → `GetState` → `OpenProject` |
| `NotFound` en un `softwarePath` | Te lo inventaste o lo escribiste mal | Vuelve a `GetProjectTree` y **copia** el valor |
| La respuesta viene cortada | El PLC es grande | Usa `sections` y pide por partes |
| Tarda muchísimo | TIA está arrancando en frío | Es normal: el primer arranque tarda minutos. Los siguientes, segundos |
| `User in ... group: False` | El bloqueo de siempre | [`50-errores`](../50-errores/README.md#-user-in-siemens-tia-openness-user-group-false) |

---

## Pruébalo aquí

✅ **Esta receta se ejecutó entera sobre `50-examples/npatel-basement-light/` el 2026-09-14** y
funcionó. Resultado: S7-1200, 4 bloques, 0 inconsistentes — está en su
[`FICHA.md`](../../50-examples/npatel-basement-light/FICHA.md).

```
50-examples/npatel-basement-light/   ← el más pequeño, empieza por este ✅ hecho
50-examples/npatel-traffic-light/
50-examples/npatel-iot/03_OPCUA_Project/
```

Están en **V16**. El `OpenWithUpgrade` de Openness V20 documenta la actualización desde la versión
inmediatamente anterior y advierte que una versión más antigua puede devolver una excepción. En
este workspace se abrió una copia V16 concreta (`npatel-basement-light`) con éxito en 125 s; es
evidencia de ese proyecto, no garantía para los demás. Abre siempre una copia desechable, nunca el
original, y conserva el log/backup. Detalle y límites en
[`MIGRACION-V16-a-V20.md`](../../50-examples/MIGRACION-V16-a-V20.md).

**Cuando termines, rellena el `FICHA.md` del ejemplo** con lo que encuentres. Eso es lo que
convierte la carpeta de ejemplos en algo consultable sin abrir TIA.

🔴 `Disconnect` no cierra TIA. No cierres una instancia del usuario; sólo detén una instancia propia
cuando puedas demostrar que el runner la inició y que no contiene trabajo ajeno. No uses
`Stop-TiaPortal.ps1` como limpieza indiscriminada.
