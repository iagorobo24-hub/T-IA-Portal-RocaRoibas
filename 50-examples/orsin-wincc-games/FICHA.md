# WinCC Games — los límites de WinCC

- **Autor:** [RobertOrsin](https://github.com/RobertOrsin/TIAPortalGames)
- **TIA:** V16 + STEP 7 Professional + **WinCC Advanced** · **Lenguaje:** VBScript
- **Proyecto:** `tia/GamesCollection.ap16` — 38 MB, un solo proyecto con todos los juegos

## Qué es

Juegos escritos en VBScript sobre WinCC Advanced, para paneles HMI de Siemens:

| Juego | Estado según el autor |
|---|---|
| **Snake** | Funciona. La serpiente no se come a sí misma; acaba a las 30 manzanas |
| **TicTacToe Extreme** | Nueve partidas combinadas; dónde juegas determina dónde juega el rival |
| **Viergewinnt** (4 en raya) | Coloca fichas, sin detección de ganador |
| **Gameboy Zelda** | El más complejo: 13 niveles, empujar estatuas, espada, bombas, jefe final |
| **Gameboy RPG (Pokémon)** | Mapa con scroll, combates, cálculo de daño, inventario de 6 |
| **Tetris** | A medias |

## ⚠️ Esto NO es un estándar de nada

El propio autor lo dice: los comentarios son escasos, no hubo intención de compartirlo, y nada
está hecho para quedar bonito ni completo. **Va en contra de todo lo de
[`20-standards/`](../../20-standards/)**, y a propósito.

No copies de aquí ni la estructura, ni la nomenclatura, ni la forma de organizar.

## Entonces, ¿para qué lo quieres?

Porque es **el mejor material que existe para ver hasta dónde llega WinCC de verdad**. Alguien
dedicó meses a empujar el entorno hasta romperlo, y documentó dónde están las paredes:

- **VBScript al límite**: máquinas de estado, gestión de mapas, IA de enemigos
- **Listas gráficas** usadas como sprites y tilesets
- **Animación por frames** en un entorno que no está pensado para animar
- 🥇 **Rendimiento real frente a simulación** — lo más útil de todo

Sobre esto último, el autor documenta que necesita valores de espera **hasta 24 veces mayores**
en el panel físico que en el PC:

| Temporizador | PC | HMI física |
|---|---:|---:|
| Detonación de bomba | 400 | **8000** |
| Reposo de enemigo | 120 | **600** |
| Comando de enemigo | 600 | **3600** |
| Retardo de jugador | 5 | **120** |

Esa tabla vale más que el juego: es una medida real de la diferencia entre simular y ejecutar en
un panel, y explica por qué una pantalla que va fina en el PC se arrastra en planta.

## Migración: ✅ viable, verificado

Esto es **WinCC Advanced con VBScript**. WinCC **Unified** usa JavaScript y **no migra** el
VBScript — no es una conversión, es reescribir. Así que todo dependía de tener el ES de
Comfort/Advanced.

**Lo tienes.** Comprobado en el registro de instalación:

| Producto | V19 | V20 |
|---|:---:|:---:|
| WinCC **CA ES** (Comfort / Advanced Engineering) | ✅ | ✅ |
| WinCC Unified ES | ✅ | ✅ |
| WinCC Basic ES | ✅ | ✅ |
| WinCC **Runtime Advanced** (para simular en PC) | V17.0 UPD8 | ídem |

Así que el proyecto **debería migrar y funcionar tal cual**, sin reescribir nada a JavaScript.

> ⚠️ El único punto dudoso: el Runtime Advanced instalado es **V17**, y el proyecto migrado será
> V20. Para *simular* en el PC puede pedirte el runtime de la versión correspondiente. La
> ingeniería (abrir, editar, compilar) no se ve afectada.

Aun así, déjalo **para el final** de la lista: es el más grande y el que más piezas tiene.

## Contenido

| | |
|---|---|
| `tia/` | Proyecto V16 completo — venía sin comprimir en el repo, copiado tal cual |
| — | El autor mantiene una [wiki](https://github.com/RobertOrsin/TIAPortalGames/wiki) con más detalle |

---

## Contenido real ✅ *migrado y verificado visualmente en TIA V20 el 2026-09-14*

**Dispositivo único: `HMI_1 [TP1200 Comfort]`. 🔴 No hay PLC. Ninguno.**

Tiene sentido —los juegos son VBScript puro sobre WinCC— pero conviene saberlo antes de buscar
bloques que no existen.

**Consecuencia práctica: `tia-inspect` casi no sirve aquí.** Sus 59 herramientas son de PLC.
Sobre un proyecto solo-HMI devuelven vacío, y no porque fallen. Esto se mira **abriendo TIA**.

### 🎉 El VBScript sobrevivió entero

Era la gran duda de la migración V16 → V20, y la respuesta es **sí**. Bajo
`HMI_1 → Scripts → VB scripts` hay **8 carpetas**, todas con su código intacto y resaltado:

| | |
|---|---|
| `Snake` · `tetris` · `Viergewinnt` · `TikTakToeExtreme` | los clásicos |
| `gameboy_zelda` · `gameboy_rpg` | los complejos |
| **`2DFighter`** | 🆕 **no aparece en el README del autor** — un juego extra |
| `FileSystem` | librería de utilidades, no un juego |

### Lo que se ve abriendo `Snake`

```vb
Sub snake()
Dim start, start2, wait, i, grow, nomove
wait = 400
...
snake_length = 4
SmartTags("snake_length") = snake_length
SmartTags("snake_body_pos_grid_x_0") = 8
For i = 4 To 29
    SmartTags("snake_body_pos_grid_x_" & i) = -1
```

Dos cosas que valen la pena:

1. **`wait = 400`** — justo el valor que el autor documenta como dependiente del hardware. En un
   panel real hay que subirlo mucho. Confirma la tabla de tiempos de más arriba.
2. **`SmartTags("nombre_" & i)`** — acceso a tags de HMI desde VBScript **construyendo el nombre
   por concatenación**. Así es como simula un array de 30 segmentos de serpiente sobre tags
   planas de WinCC. Es la técnica reutilizable de verdad que hay aquí.

---

## Estado

- [x] Copiado y verificado
- [x] **WinCC Comfort/Advanced ES confirmado instalado en V19 y V20** → migración viable
- [x] **Migrado a V20** por Openness, sin errores
- [x] Confirmado que **no contiene PLC**: solo `HMI_1 [TP1200 Comfort]`
- [x] **Verificado en TIA: el VBScript sobrevivió** — 8 carpetas de scripts, código intacto
- [ ] Revisar las pantallas una a una (los juegos son pop-ups, no pantallas normales)
- [ ] Comprobar si el Runtime Advanced V17 sirve para simular un proyecto V20
