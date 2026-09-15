# Migrar los ejemplos de TIA V16 a V20

> ✅ **Probado de verdad el 2026-09-14** sobre `npatel-basement-light`. Lo que sigue son
> resultados medidos, no teoría.

---

## La buena noticia: se migra solo

**Openness migra el proyecto automáticamente.** `OpenProject` llama por debajo a
`Projects.OpenWithUpgrade()`, así que abrir un `.ap16` con un servidor ligado a V20 **hace el
upgrade sin intervención**.

```powershell
30-tools\scripts\Invoke-TiaMcp.ps1 -TimeoutSeconds 600 -Calls @(
    @{ name='Connect' },
    @{ name='OpenProject'; args=@{ path='...\BasementLightControl\BasementLightControl.ap16' } },
    @{ name='GetPlcSummary'; args=@{ softwarePath='PLC_1' } }
)
```

> ⚠️ **Corrección.** Una versión anterior de este documento decía que Openness no podía migrar y
> que había que hacerlo a mano desde TIA. **Era falso.** Se corrigió al probarlo.

### Qué pasa exactamente

Medido sobre `BasementLightControl.ap16` (V16, 8 KB de `.ap` + ~4 MB de proyecto):

| | |
|---|---|
| Tiempo de `OpenProject` con upgrade | **125 s** |
| Original `.ap16` | **intacto**, no se toca |
| Se crea | `<carpeta>_V20\<carpeta>_V20.ap20` |
| Se crea también | `<carpeta>_V20.backup\` |
| Resultado | Proyecto abierto y utilizable: 4 bloques, 0 inconsistentes |

🔒 **El nombre del proyecto migrado sale del nombre de la CARPETA, no del `.ap16`.**

Por eso cada proyecto vive en una carpeta con su nombre real:

```
npatel-basement-light/
├── BasementLightControl/              ← la carpeta se llama como el proyecto
│   └── BasementLightControl.ap16
└── BasementLightControl_V20/          ← lo que crea el upgrade
    └── BasementLightControl_V20.ap20
```

Si la carpeta se llamara `tia`, el proyecto migrado se llamaría `tia_V20`. Los siete se
llamarían igual y no sabrías cuál es cuál. *(Sí: es exactamente el error que cometí al montarlo
la primera vez.)*

---

## Lo que sigue siendo de un solo sentido

El `.ap16` original **no se modifica** — el upgrade crea un proyecto nuevo al lado. Aun así:

🔒 **`original-v16/` no se toca nunca.** Es el `.zap16` comprimido y pristino. Si el proyecto
migrado se corrompe o quieres volver a empezar, sale de ahí.

---

## Riesgos reales de saltar cuatro versiones

Verificado sobre el más simple; los demás pueden dar más guerra.

| Qué | Riesgo | Estado |
|---|---|---|
| Lógica LAD / FBD / SCL | 🟢 Bajo | ✅ `basement-light` migró con 0 bloques inconsistentes |
| Configuración hardware | 🟠 Módulos descatalogados pueden no tener equivalente | ✅ S7-1200 migró bien |
| **WinCC Advanced → Unified** | 🔴 **No es migración, es reescritura** | Irrelevante aquí: tienes **WinCC Comfort/Advanced ES** instalado, así que se queda en Advanced |
| VBScript de HMI | 🔴 Unified usa JavaScript | Igual: se queda en Advanced, no se convierte |
| Bloques de biblioteca antiguos | 🟠 Pueden pedir actualizar la versión de instrucción | ⬜ por ver |

---

## Procedimiento recomendado

### Opción A — por Openness (rápida, automatizable)

Como el ejemplo de arriba. Ventaja: es un comando, y al terminar ya tienes el proyecto abierto
para inventariarlo.

⚠️ **Dale margen de tiempo.** 125 s en el proyecto más pequeño. Los grandes tardarán más: usa
`-TimeoutSeconds 900` para `sorting-plant` y `wincc-games`.

⚠️ **`OpenProject` no dice nada del log de migración.** Devuelve "opened" y ya. Para ver qué
degradó el upgrade hay que abrir el proyecto en la interfaz de TIA.

### Opción B — desde la interfaz de TIA (cuando quieres ver el log)

1. TIA Portal V20 → `Proyecto → Abrir` → el `.ap16`
2. Acepta actualizar
3. **Lee el log de migración.** No lo cierres sin leerlo
4. Compila (`Ctrl+B`)

Usa esta cuando el proyecto sea grande o complejo, o cuando la opción A dé problemas.

---

## Después de migrar, siempre

```powershell
30-tools\scripts\Invoke-TiaMcp.ps1 -Calls @(
    @{ name='Connect' },
    @{ name='OpenProject';     args=@{ path='...\<Proyecto>_V20\<Proyecto>_V20.ap20' } },
    @{ name='CompileSoftware'; args=@{ softwarePath='PLC_1' } },
    @{ name='GetPlcSummary';   args=@{ softwarePath='PLC_1' } }
)
```

🔒 **Una migración que no compila no está terminada.** Y `GetPlcSummary` devuelve
`inconsistentObjects` y `knowHowProtectedObjects`: míralos.

Luego actualiza el `FICHA.md` del ejemplo con lo encontrado.

---

## 🔴 Cierra TIA al acabar

✅ **Verificado:** `Disconnect` **no** cierra TIA Portal, y cada `OpenProject` con upgrade puede
dejar una instancia nueva. En una sola sesión de pruebas se acumularon **2 instancias × 1,3 GB**.

```powershell
30-tools\scripts\Stop-TiaPortal.ps1
```

Detalle en [`10-kb/10-openness/conexion-y-sesiones.md`](../10-kb/10-openness/conexion-y-sesiones.md).

---

## Orden recomendado

De menos a más riesgo, para que si algo falla sepas si es el entorno o el proyecto.

| # | Ejemplo | Estado |
|---|---|---|
| 1 | `npatel-basement-light` | ✅ **migrado y verificado** |
| 2 | `npatel-traffic-light` | ⬜ |
| 3 | `npatel-iot/02_S7_Project` | ⬜ |
| 4 | `npatel-iot/03_OPCUA_Project` | ⬜ ojo a los certificados OPC-UA |
| 5 | `npatel-iot/04_MQTT_Project` | ⬜ |
| 6 | `npatel-sorting-plant` | ⬜ grande, usa timeout largo |
| 7 | `orsin-wincc-games` | ⬜ 38 MB, el que más piezas tiene |
