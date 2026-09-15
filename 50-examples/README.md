# Ejemplos — proyectos TIA listos para abrir y modificar

Siete proyectos TIA Portal reales, **desempaquetados y preparados para editar**.
No son referencias teóricas: se abren, se tocan y se rompen sin miedo.

Doble función:

1. **Material propio reutilizable** — código, patrones y pantallas que puedes copiar o adaptar.
2. **Banco de pruebas del workspace** — son los proyectos sobre los que validamos que la
   conexión LLM ↔ TIA Portal funciona de verdad, sin arriesgar nada de un cliente.

---

## Índice

| Carpeta | Qué es | Enseña | Tamaño | V |
|---|---|---|---|---|
| [`npatel-basement-light`](npatel-basement-light/) | Control de luz de sótano con dos conmutadores | Lógica combinacional pura (XOR de 3 vías), LAD + HMI básico | 8,9 MB | V16 |
| [`npatel-traffic-light`](npatel-traffic-light/) | Semáforo | Secuencia temporizada, temporizadores, máquina de estados | 19 MB | V16 |
| [`npatel-sorting-plant`](npatel-sorting-plant/) | Planta clasificadora con **gemelo digital** | Virtual commissioning, SIL, TDD sobre PLC, PLCSIM Advanced + NX MCD | 25 MB | V16 |
| [`npatel-iot`](npatel-iot/) | **Tres** proyectos: S7, OPC-UA, MQTT + Node-RED | El PLC como parte de un sistema: pasarela IOT2050, cloud, dashboards | 20 MB | V16 |
| [`orsin-wincc-games`](orsin-wincc-games/) | Juegos en WinCC + VBScript | Hasta dónde llega WinCC: scripting, listas gráficas, animación, rendimiento | 38 MB | V16 |
| [`siemens-snippets`](siemens-snippets/) | 91 snippets de la API Openness | No es un proyecto TIA: es código C# de referencia | — | V20 |

**Todos son TIA V16**, pero eso no es un obstáculo: ✅ **Openness los migra solo** al abrirlos
(`OpenWithUpgrade`). Probado sobre `npatel-basement-light`: 125 s y listo, sin tocar TIA a mano.
Detalle en **[`MIGRACION-V16-a-V20.md`](MIGRACION-V16-a-V20.md)**.

---

## Estructura de cada carpeta

```
<ejemplo>/
├── FICHA.md              ← qué es, qué enseña, qué reutilizar, qué NO copiar
├── <Proyecto>/           ← proyecto V16 desempaquetado, intacto
├── <Proyecto>_V20/       ← el migrado, lo crea Openness al abrirlo
├── original-v16/         ← el .zap16 intacto, red de seguridad
└── docs/                 ← PDFs de capturas, documentación del autor
```

🔒 **La carpeta se llama como el proyecto, y eso importa.** `OpenWithUpgrade` nombra el proyecto
migrado a partir del **nombre de la carpeta**, no del `.ap16`. Si todas se llamaran `tia`, los
siete proyectos migrados se llamarían `tia_V20`.

🔒 **`original-v16/` no se toca nunca.** Es la copia comprimida y pristina.

---

## Qué reutilizar de cada uno

Mi valoración tras analizar el contenido. Está marcado lo que es opinión y lo que está verificado.

### 🥇 `npatel-iot` — el más valioso con diferencia

Es el único que trata el PLC como **parte de un sistema**, no como isla. Tres proyectos TIA
distintos (`IOT2050_S7_*`, `IOT2050_OPCUA_*`, `IOT2050_MQTT_*`) más siete flujos de Node-RED,
código Python y una calculadora de OEE en C++.

Verificado leyendo los flujos:

| Flujo | Cómo habla con el PLC |
|---|---|
| `02_S7Communication` | Nodos `s7 in` — protocolo S7 nativo, 4 lecturas + dashboard |
| `03_OPCUACommunication` | `OpcUa-Client` + 7 `OpcUa-Item` — el camino estándar y el que yo usaría |
| `04_MQTTCommunication` | `mqtt-broker` — publicación a broker |
| `05_Pythonflow` | Nodos `exec` que llaman scripts Python en la pasarela |
| `06_CPPflow` | Calculadora de OEE en C++ (disponibilidad × rendimiento × calidad) |
| `07_MindSphereflow` | Nodos `s7 in` → cloud de Siemens |

El Python es para la **SIMATIC IOT2050** (escribe en `/sys/class/leds/user-led0-green/brightness`):
es una pasarela Linux, no el PLC. Útil si alguna vez montas una.

**Reutiliza:** el patrón OPC-UA y el cálculo de OEE. **Ignora:** MindSphere — el servicio ya no
existe como tal, Siemens lo reemplazó por Insights Hub.

### 🥈 `npatel-sorting-plant` — el más completo como ingeniería

Trae la **documentación oficial SCE de Siemens** sobre gemelo digital (`SCE-150-002`, 2,2 MB de
PDF + el .docx editable). El proyecto hace *virtual commissioning*: PLC virtual + HMI simulado +
modelo mecatrónico en NX MCD, todo unido por PLCSIM Advanced.

✅ **Sí puedes ejecutar la parte importante.** Tienes **PLCSIM Advanced V6.0** instalado, así que
el software-in-the-loop (PLC virtual + HMI simulado) es viable. Lo único que falta es **NX con
opción MCD**, es decir, el modelo 3D — la parte visual del gemelo, no el método.

**Reutiliza:** la estructura del programa y el enfoque TDD sobre PLC — es de lo poco que hay
publicado sobre eso. **Y el documento SCE**, que es material formativo de Siemens de verdad.

### 🥉 `orsin-wincc-games` — el más raro y el más instructivo sobre WinCC

Snake, TicTacToe Extreme, 4 en raya, un RPG estilo Game Boy con empujar estatuas y peleas, y un
Tetris a medias. Todo en **VBScript sobre WinCC Advanced**, un solo proyecto de 38 MB.

No es un estándar de nada — el propio autor lo dice: *"nothing is done to be pretty (or even
complete)"*. Su valor es otro: **es el mejor material que existe para ver los límites reales de
WinCC**. Scripting, listas gráficas, animación por sprites, gestión de estado, y sobre todo
**rendimiento en HMI física frente a simulación** — el autor documenta que necesita valores de
`Sleep` 20 veces mayores en el panel real que en el PC (bomba: 400 en PC, 8000 en HMI).

✅ **Migra sin problema:** tienes **WinCC Comfort/Advanced ES** instalado en V19 y V20, que era la
duda. No hay que reescribir el VBScript a JavaScript.

**Reutiliza:** las técnicas de scripting y las listas gráficas. **No copies:** la estructura ni
la nomenclatura. Va contra todo lo de `20-standards/`, y a propósito.

### `npatel-traffic-light` y `npatel-basement-light` — los de aprender

Pequeños y limpios. El de la luz de sótano es lógica combinacional pura: dos conmutadores que
controlan una luz, la tabla de verdad es un XOR.

> ⚠️ **Errata del autor, verificada:** la tabla de verdad de su README tiene la fila
> `OFF | ON` repetida y le falta `ON | OFF`. La lógica correcta es XOR: la luz se enciende
> cuando los conmutadores están en posiciones **distintas**.

El semáforo añade temporización y secuencia. Su `README.md` original está vacío — todo lo que
documentó está en el PDF de capturas.

**Son los candidatos ideales para la primera prueba del MCP:** pequeños, sin dependencias raras,
y si se rompen no pasa nada.

---

## Estado del análisis — sé honesto con esto

| Qué | Estado |
|---|---|
| Proyectos desempaquetados y verificados | ✅ los 7 tienen su `.ap16` en sitio y estructura correcta |
| Node-RED, Python, C++ del proyecto IoT | ✅ analizados leyendo el código |
| Documentación de los autores | ✅ leída |
| **Los 7 migrados a V20 e inventariados** | ✅ **hecho el 2026-09-14** |
| Export a texto para git | ✅ 5 de 7 — ver tabla |

## Inventario verificado

| Proyecto | Bloques | Tipos | Tags | Compila | Export `src/` |
|---|---:|---:|---:|---|---|
| `BasementLightControl` | 4 | 0 | 0 | ✅ 0/0 | ⚠️ bloqueado * |
| `TrafficLight` | 7 | 0 | **31** | ⚠️ 0 err, **1 aviso** | 7 `.s7dcl` |
| `IOT2050_S7` | 8 | 0 | 0 | ✅ 0/0 | 5 `.s7dcl` |
| `IOT2050_OPCUA` | 4 | 0 | 0 | ✅ 0/0 | 3 `.s7dcl` |
| `IOT2050_MQTT` | 6 | **6** | 0 | ✅ 0/0 | 3 `.s7dcl` + **7 `.xml`** † |
| `Sorting Plant Controller` | 7 | 0 | **37** | ✅ 0/0 | 7 `.s7dcl` |
| `GamesCollection` | — | — | — | **sin PLC** ‡ | — |

\* El export falló porque el proyecto estaba abierto en una instancia de TIA **con ventana**.
Openness no puede abrir un proyecto que otro proceso tiene bloqueado. Ciérralo y reejecuta
`30-tools\scripts\Export-Sources.ps1`.

† Los 6 UDTs salen en **XML**, no en `.s7dcl`: los documentos SIMATIC SD para tipos de datos PLC
**requieren V21**. Confirmación real de un [límite documentado](../10-kb/10-openness/limites.md).

‡ Solo contiene `HMI_RT_1`. Es un proyecto de HMI puro, sin PLC — `tia-inspect` no tiene nada
que inventariar ahí.

### Dos patrones que salen del inventario

**Hay dos escuelas entre estos proyectos.** Los que tienen **tags simbólicas comentadas**
(sorting-plant 37, traffic-light 31) y los que tienen **cero** y direccionan absoluto
(basement-light, los tres IoT). Para practicar búsquedas por símbolo —receta
[R02](../10-kb/20-recetas/R02-donde-se-usa.md)— solo sirven los dos primeros.

**Todos usan la `Default tag table`**, que es justo lo que
[`estructura-proyecto.md`](../20-standards/estructura-proyecto.md) desaconseja.
