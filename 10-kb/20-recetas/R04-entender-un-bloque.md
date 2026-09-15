# R04 — Entender qué hace un bloque

**Objetivo.** Coger un bloque que no escribiste y poder explicar qué hace, qué necesita, qué
devuelve y qué pasa si lo cambias — antes de tocarlo.

**Precondiciones.** Proyecto abierto, ruta del bloque sacada de `GetSoftwareTree`.

**Servidor.** `tia-inspect`.

> ✅ **Ejecutada el 2026-09-14** sobre `CylinderControl` de `npatel-sorting-plant`. Corrigió dos
> errores de la versión anterior de esta receta, señalados abajo.

---

## Secuencia

### 1. El fuente

```
GetBlockSource(softwarePath: "Sorting Plant Controller",
               blockPath:    "CylinderControl",
               maxChars:     3000)
```

🔒 **Esta es la llamada principal, también para bloques LAD.**

> ⚠️ **Corrección.** La primera versión de esta receta decía "empieza por `GetBlockInterface`" y
> que el LAD "sale como XML ilegible". **Las dos cosas eran falsas:**
>
> 1. `GetBlockInterface` **solo funciona con bloques de datos**. Sobre un FB devuelve:
>    *"'CylinderControl' is a FB, and Openness exposes an interface only for data blocks.
>    Use 'GetBlockSource' and read its declaration part instead."*
> 2. **El LAD en formato documento SIMATIC SD se lee perfectamente.** No es XML posicional.

### Cómo se lee un LAD en `.s7dcl`

Es texto, y es sorprendentemente claro:

```
{ S7_Language := "LAD"; S7_NetworkTitle := "MLC_U4" }
NETWORK
    RUNG wire#powerrail
        Contact( #"Extend Command" )
        Contact( #"Retract Command" )
        Coil( #Fault )
    END_RUNG
    RUNG wire#powerrail
        Contact( #Fault )
        ReturnCoil( FALSE )
    END_RUNG
END_NETWORK
```

| Elemento | Qué es |
|---|---|
| `NETWORK` | Un segmento. Equivale a un network en el editor gráfico |
| `RUNG wire#powerrail` | Una rama que arranca de la barra de alimentación |
| `Contact( x )` | Contacto normalmente **abierto** |
| `I_Contact( x )` | Contacto **invertido** (normalmente cerrado) |
| `Coil( x )` | Bobina |
| `S_Coil` / `R_Coil` | Set / Reset — **biestable, tiene memoria** |
| `ReturnCoil( FALSE )` | Salida anticipada del bloque |
| Contactos seguidos en el mismo RUNG | **serie = AND** |
| Varios RUNG hacia la misma bobina | **paralelo = OR** |

🔒 **`#` significa ámbito local; las comillas sin `#`, tag global.**
`#Fault` es una variable del bloque. `"pcCylinderHeadExtend_SetActive"` es una tag del PLC.
Confundirlos lleva a conclusiones equivocadas — ver [R02](R02-donde-se-usa.md).

### Los comentarios están en el `.s7res`

El `.s7dcl` trae `S7_NetworkTitle := "MLC_U4"`, que es un **identificador**, no un título. El
texto real está en el fichero acompañante:

```xml
<Comment Id="MLC_U4">
  <MultiLanguageText Lang="en-US">Trigger fault when the cylinder is set to
  extend and retract at the same time</MultiLanguageText>
</Comment>
```

`GetBlockSource` devuelve **los dos ficheros concatenados**, así que lo tienes todo en una
llamada. Empareja cada `Id` con su network.

### 2. La declaración

Va en la cabecera del propio `.s7dcl`:

```
FUNCTION_BLOCK "CylinderControl"
    VAR_INPUT
        "Extend Command" : Bool;
        "Retract Command" : Bool;
        "Limit Switch Not Extended" : Bool;
        "Limit Switch Retracted" : Bool;
    END_VAR
    VAR_OUTPUT
        Fault : Bool;
        "interlock" : Bool;
        "Extend Cylinder" : Bool;
        "Retract Cylinder" : Bool;
    END_VAR
```

| Sección | Qué significa |
|---|---|
| `VAR_INPUT` | Entra y no se modifica |
| `VAR_OUTPUT` | Sale, lo escribe el bloque |
| `VAR_IN_OUT` | ⚠️ **Entra y puede salir modificado.** Aquí están las sorpresas |
| `VAR` (static) | Estado que persiste entre ciclos |
| `VAR_TEMP` | Se pierde cada ciclo |

🔴 **Un FB tiene estado aunque no declare `VAR` static.** Sus **salidas** viven en el DB de
instancia y retienen valor entre ciclos. `CylinderControl` no declara ni una static, pero usa
`S_Coil`/`R_Coil` sobre la salida `"Extend Cylinder"`: es un biestable con memoria. Si solo
miras `VAR`, concluyes que es combinacional y te equivocas.

### 3. Para bloques de datos, sí `GetBlockInterface`

```
GetBlockInterface(softwarePath: "...", blockPath: "Control_HMI")
```

Ahí es donde esa herramienta funciona, y es más cómoda que leer el fuente.

### 4. Quién lo usa

```
GetCrossReferences(softwarePath: "...", objectPath: "CylinderControl", maxDepth: 1)
```

Un FB llamado desde 15 sitios no se toca igual que uno llamado desde uno. Ver
[R02](R02-donde-se-usa.md).

### 5. Sus DB de instancia

Si es un FB, cada llamada tiene su DB de instancia y **ahí está el estado real**. Los valores de
arranque te dicen cómo está parametrizada *esa* instancia: dos cilindros con el mismo FB pueden
tener parámetros distintos.

```
GetBlocks(softwarePath: "...", regexName: ".*_DB")
GetBlockInterface(softwarePath: "...", blockPath: "SortingPlantControl_DB")
```

---

## Ejemplo resuelto: `CylinderControl`

Lo que sale de aplicar la receta:

> Controla un cilindro neumático de doble efecto con dos finales de carrera.
>
> 1. **Fallo**: si se ordena extender y retraer a la vez, activa `Fault` y **sale del bloque**
>    (`ReturnCoil(FALSE)`). Es una guarda: el resto no se ejecuta.
> 2. **Enclavamiento**: `interlock` se activa cuando el cilindro **no** está retraído y no hay
>    fallo. Sirve para parar la cinta mientras el cilindro está fuera.
> 3. **Biestable**: `Extend Cylinder` se **pone** con orden de extender sin retraer, y se
>    **borra** con la contraria. Memoria en el DB de instancia.
> 4. `Retract Cylinder` es simplemente el inverso de `Extend Cylinder`.

**Lo que hay que señalar al usuario:**

🔴 **`"Limit Switch Not Extended"` está declarado como entrada y no se usa en ningún network.**
Parámetro muerto: alguien lo previó y no llegó a cablearlo. Es justo el tipo de cosa que se
encuentra leyendo el fuente y no mirando el diagrama.

⚠️ Nombres con **espacios entre comillas** (`"Extend Command"`). Legal en TIA, pero va contra
[`naming.md`](../../20-standards/naming.md) y obliga a entrecomillar en todas partes.

⚠️ `"interlock"` en minúscula mientras el resto es Title Case, y un typo (`inerlock`) en un
comentario.

---

## Las preguntas que hay que poder responder

- [ ] ¿Qué hace, en una frase?
- [ ] ¿Tiene estado? *(ojo: las salidas de un FB también son estado)*
- [ ] ¿Qué pasa en el primer ciclo tras un arranque en frío?
- [ ] ¿Qué pasa si se pierde una entrada a mitad de operación?
- [ ] ¿Cómo sale de un estado de fallo? ¿Hace falta rearme?
- [ ] ¿Hay `VAR_IN_OUT`? ¿Qué modifica?
- [ ] ¿Hay parámetros declarados y no usados?
- [ ] ¿Cuántos sitios lo llaman?

🔴 **Las preguntas 3, 4 y 5 distinguen entender un bloque de haberlo leído.** El camino feliz lo
entiende cualquiera; el comportamiento ante fallo es donde vive el riesgo.

> En `CylinderControl`, la 5 tiene una respuesta incómoda: **`Fault` no se borra nunca.** No hay
> rearme. Una vez activo, el bloque sale por `ReturnCoil` en cada ciclo y el cilindro se queda
> como esté hasta que se reinicie el PLC. Eso hay que decirlo.

---

## Si falla

| Síntoma | Causa | Arreglo |
|---|---|---|
| `GetBlockInterface` da error en un FB/FC | Solo vale para bloques de datos | Usa `GetBlockSource`. El propio error te lo dice |
| No se puede leer el fuente | **Know-how protection** | No hay forma por API. El usuario debe quitarla en TIA. **Dilo, no lo rodees** |
| `NotFound` | Ruta inventada | `GetSoftwareTree` |
| Es un bloque F | Programa de seguridad | Léelo, pero **no lo edites** (`AGENTS.md` §3.3) |
| El fuente sale cortado | `maxChars` | Súbelo, o pide el bloque por partes |

---

## Antes de modificarlo

🔒 De `AGENTS.md` §3.2, aquí en concreto:

1. Lee el bloque **entero**. No parchees lo que no has leído
2. Mira quién lo llama: un cambio en un FB usado 15 veces cambia 15 comportamientos
3. Backup del `.ap20`
4. Cambio mínimo
5. Compila → 0 errores
6. Exporta a `src/` y commit ([R03](R03-exportar-a-git.md))
