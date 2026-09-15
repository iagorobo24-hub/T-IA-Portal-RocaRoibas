# IoT Project — el PLC dentro de un sistema

- **Autor:** [npatel221](https://github.com/npatel221/PLC_Projects) · **Licencia:** ver repo original
- **TIA:** V16 → migrar a V20 · **Pasarela:** SIMATIC **IOT2050** (Linux) · **Node-RED**

## Por qué este es el más valioso de la colección

Es el único que **no trata el PLC como una isla**. Aquí el PLC es una pieza de una cadena que
llega hasta un dashboard y hasta la nube. Y todo lo de fuera de TIA es **texto legible**, así que
ya está analizado — a diferencia de los `.ap16`, que siguen siendo cajas negras hasta que
Openness funcione.

## Contiene tres proyectos TIA distintos

| Carpeta | Proyecto | Protocolo |
|---|---|---|
| `02_S7_Project/` | `IOT2050_S7_CompleteProject.ap16` | S7 nativo |
| `03_OPCUA_Project/` | `IOT2050_OPCUA_CompleteProject.ap16` | OPC-UA |
| `04_MQTT_Project/` | `IOT2050_MQTT_CompleteProject.ap16` | MQTT |

Cada uno con su `tia/` y su `original-v16/`.

## Los siete flujos de Node-RED — analizados

Verificado leyendo los nodos de cada JSON:

| Flujo | Cómo habla con el PLC | Interés |
|---|---|---|
| `01_getTime` | ninguno (`inject` + `function`) | El hola-mundo de Node-RED |
| `02_S7Communication` | 4 nodos `s7 in` + gráficas y gauges | Protocolo S7 directo, sin servidor intermedio |
| `03_OPCUACommunication` | `OpcUa-Client` ×2 + 7 `OpcUa-Item` + slider | 🥇 **El camino estándar y el que yo usaría** |
| `04_MQTTCommunication` | `mqtt-broker`, botones y gráfica | Publicación a broker |
| `05_Pythonflow` | nodos `exec` → scripts Python | Ejecutar código en la pasarela |
| `06_CPPflow` | function + dashboard | Calculadora de **OEE** |
| `07_MindSphereflow` | `s7 in` → cloud de Siemens | ⚠️ obsoleto, ver abajo |

## El código de apoyo

**`code/05_setLEDcolor.py` y `05_LED_sequence.py`** — no son para el PLC. Escriben en
`/sys/class/leds/user-led0-green/brightness`: son para los **LEDs de la pasarela IOT2050**, que
es un equipo Linux. Útil solo si alguna vez montas una.

**`code/06_oeecalculator.cpp`** — calculadora de **OEE** (*Overall Equipment Effectiveness*)
siguiendo la definición de oee.com. Recibe 5 argumentos —tiempo de producción planificado,
tiempo de parada, tiempo de ciclo ideal, piezas buenas, piezas totales— y devuelve
Disponibilidad, Rendimiento, Calidad y OEE.

🥇 **Esto sí es reutilizable tal cual.** La fórmula de OEE es la misma en cualquier planta, y
tenerla ya escrita y comentada ahorra la discusión de siempre sobre qué cuenta como parada.

## Qué reutilizar y qué no

| | |
|---|---|
| 🥇 **Reutiliza** | El patrón OPC-UA (`03_`) y el cálculo de OEE (`06_`) |
| 👍 Estudia | El patrón MQTT si vas a hacer telemetría |
| ⚠️ **Ignora** | `07_MindSphereflow` — MindSphere ya no existe como tal, Siemens lo sustituyó por **Insights Hub**. El patrón (leer por S7 y empujar a la nube) sigue valiendo; el destino no |

---

## Contenido real de los proyectos TIA ✅ *migrados e inventariados el 2026-09-14*

Los tres compilan con **0 errores y 0 advertencias**, y **ninguno tiene tags simbólicas**:
direccionan absoluto. No los uses para practicar búsquedas por símbolo.

### `02_S7_Project` — 8 bloques

```
Program blocks
├── Main                          [OB1]
├── motorControl  + motorControl_DB
└── 01_S7/
    ├── Cyclic interrupt          [OB de interrupción cíclica]
    ├── S7_Data                   [DB — lo que Node-RED lee por S7]
    └── motorControl
```

🥇 **El más instructivo de los tres.** `S7_Data` es el DB de intercambio que leen los nodos
`s7 in` de Node-RED: el patrón "un DB como contrato con el mundo exterior". Y usa una
**interrupción cíclica**, no solo OB1.

### `03_OPCUA_Project` — 4 bloques

```
Program blocks
├── Main
├── Temperature Control_DB
└── 02_OPCUA/OPC_UA_DB
```

Mismo patrón, un DB dedicado como superficie OPC-UA.

### `04_MQTT_Project` — 6 bloques y **6 tipos de datos**

```
PLC data types/02_Types/S7-1500/
├── LMQTT_typeConnectFlags        LMQTT_typeParamData
├── LMQTT_typePublishData         LMQTT_typeSubscribeData
├── LMQTT_typeSubscriptionData    LMQTT_typeTcpConnParamData
Program blocks
├── LMQTTClient/InstLMQTT_Client
├── MQTTdata
└── PressControl_DB
```

🥇 **Usa la librería oficial LMQTT de Siemens**, no un cliente casero. Es la referencia buena si
alguna vez montas MQTT sobre S7-1500: los UDTs `LMQTT_type*` son el contrato de esa librería.

> 🔴 **Confirmación de un límite documentado:** los 6 UDTs se exportan como **`.xml`**, no como
> `.s7dcl`. Los documentos SIMATIC SD para tipos de datos PLC **requieren TIA V21**; en V20 solo
> los bloques tienen formato documento. Se ve en el export: 3 `.s7dcl` frente a 7 `.xml`.
> Ver [`10-openness/limites.md`](../../10-kb/10-openness/limites.md).

---

## Estado

- [x] Desempaquetados y verificados los 3 proyectos
- [x] **Node-RED, Python y C++ analizados**
- [x] **Migrados a V20** por Openness
- [x] **Compilados:** los tres 0 errores, 0 advertencias
- [x] **Inventariados** — 8 / 4 / 6 bloques
- [x] **Exportados a `src/`** — ojo: los UDTs de MQTT salen en XML, no en `.s7dcl`
