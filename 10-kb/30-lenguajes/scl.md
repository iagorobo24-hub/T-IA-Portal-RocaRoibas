# SCL — guía de lenguaje

> **Estado: validado contra el compilador.** SCL es el lenguaje por defecto para lógica
> ([ADR-003](../../00-meta/decisiones/ADR-003-lenguajes.md)); esto fija cómo se escribe aquí.
>
> ✅ Las reglas marcadas *Verificado* salieron de compilar de verdad los cinco bloques de
> [`60-library/blocks/`](../../60-library/blocks/) en TIA V20 — todos con 0 errores y 0
> advertencias. No son preferencias: son lo que el compilador acepta y lo que rechaza.
>
> Esta página es la guía completa. [`20-standards/estilo-scl.md`](../../20-standards/estilo-scl.md)
> es la referencia corta citable en revisión — si difieren, esta manda porque es la más reciente.

## Estructura de un bloque

```pascal
FUNCTION_BLOCK "FB_Motor"
{ S7_Optimized_Access := 'TRUE' }
VERSION : 0.1
AUTHOR : JMellid
FAMILY : Drives
//==============================================================================
// Control de un motor de marcha/paro con confirmacion y deteccion de fallo.
//
// Arranca con CmdStart si no hay enclavamiento activo. Si no llega la
// confirmacion Feedback antes de StartTimeout, levanta Fault y para la salida.
// El fallo es enclavado: solo se borra con CmdReset.
//==============================================================================
   VAR_INPUT
      CmdStart     : Bool;   // Orden de marcha (flanco o mantenida)
      CmdStop      : Bool;   // Orden de paro
      CmdReset     : Bool;   // Rearme de fallo
      Interlock    : Bool;   // TRUE = permitido arrancar
      Feedback     : Bool;   // Confirmacion de marcha desde el campo
      StartTimeout : Time := T#3s;  // Espera maxima de confirmacion
   END_VAR

   VAR_OUTPUT
      Run          : Bool;   // Salida al contactor
      Running      : Bool;   // Marcha confirmada
      Fault        : Bool;   // Fallo enclavado
      FaultCode    : Int;    // 0 = sin fallo, ver DB_Alarms
   END_VAR

   VAR
      tonStart { InstructionName := 'TON_TIME' } : TON_TIME;
      statRunLatch : Bool;
   END_VAR

BEGIN
   //---------------------------------------------------------------------------
   // 1. Rearme de fallo
   //---------------------------------------------------------------------------
   IF #CmdReset THEN
      #Fault     := FALSE;
      #FaultCode := 0;
   END_IF;

   //---------------------------------------------------------------------------
   // 2. Enclavamiento de marcha
   //    El paro y el fallo mandan siempre sobre la orden de marcha.
   //---------------------------------------------------------------------------
   IF #CmdStop OR #Fault OR NOT #Interlock THEN
      #statRunLatch := FALSE;
   ELSIF #CmdStart THEN
      #statRunLatch := TRUE;
   END_IF;

   #Run := #statRunLatch;

   //---------------------------------------------------------------------------
   // 3. Vigilancia de la confirmacion
   //---------------------------------------------------------------------------
   #tonStart(IN := #Run AND NOT #Feedback,
             PT := #StartTimeout);

   IF #tonStart.Q THEN
      #Fault     := TRUE;
      #FaultCode := 101;      // 101 = sin confirmacion de marcha
      #statRunLatch := FALSE;
   END_IF;

   #Running := #Run AND #Feedback;
END_FUNCTION_BLOCK
```

## Reglas

### Formato

- **Sangría de 3 espacios**, que es lo que usa el editor de TIA. No tabuladores.
- **Una instrucción por línea.** Nada de `IF x THEN y := 1; END_IF;` en una sola.
- Palabras clave en **MAYÚSCULAS** (`IF`, `THEN`, `CASE`, `FOR`), identificadores como estén
  declarados.

🔒 **Usa `REGION` / `END_REGION`, no comentarios de separación.**

```pascal
REGION 2 - Memoria de marcha
   IF #CmdStop OR #statFault THEN
      #statRunLatch := FALSE;
   END_IF;
END_REGION
```

✅ *Verificado compilando en TIA V20.* Son el equivalente real de los networks de LAD: el editor
las **pliega y despliega**, cosa que un `//-----` no hace. Numéralas, porque el orden de las
regiones suele ser la lógica del bloque.

### Contenido

🔒 **Nada de números mágicos.** Un `3` suelto en el código no se puede buscar ni entender.
Constante de usuario o parámetro de entrada con valor por defecto.

```pascal
// mal
IF #Counter > 25 THEN

// bien
IF #Counter > "C_MAX_RETRIES" THEN
```

🔒 **Una salida se escribe en un solo sitio, y NUNCA se lee.**

Esto no es estilo: **lo exige el compilador**. ✅ *Verificado.* Leer una `VAR_OUTPUT` dentro de la
lógica produce:

```
The parameter '#Fault' might not be initialized.
```

El estado vive en variables `stat`; las salidas solo lo **publican**, al final del bloque:

```pascal
// mal — la salida se usa como memoria
IF #CmdStop OR #Fault THEN ...
#Fault := TRUE;

// bien — el estado es stat, la salida se publica
IF #CmdStop OR #statFault THEN ...
...
REGION 4 - Salidas
   #Fault     := #statFault;
   #FaultCode := #statFaultCode;
END_REGION
```

Además de callar al compilador, hace cierta la regla de "una salida, un sitio": si `#Run` se
asigna en tres ramas distintas, no hay forma de saber cuál manda.

🔒 **El paro y el fallo mandan sobre la marcha, siempre.** En cualquier bloque de dispositivo,
la rama que desactiva va primero en el `IF`. Es lo que hace que la lógica falle en el lado
seguro.

🔸 **Prefiere `CASE` a cadenas de `ELSIF`** para máquinas de estado. Y numera los estados de 10
en 10 para poder intercalar.

```pascal
CASE #statStep OF
   0:    // Reposo
      ;
   10:   // Llenado
      ;
   20:   // Mezcla
      ;
   999:  // Fallo
      ;
END_CASE;
```

### Comentarios

- **En español.** Explican *por qué*, no *qué*. `// incrementa contador` sobra;
  `// el sensor rebota, por eso los 200 ms` vale oro.
- Cabecera obligatoria en todo bloque: qué hace, cómo se comporta ante fallo, qué supone.
- Cada miembro de `VAR_INPUT` / `VAR_OUTPUT`, comentado en su línea.

### Lo que no se hace

- ❌ Acceso absoluto (`%MW100`, `%DB10.DBW4`) dentro de SCL. Siempre simbólico.
- ❌ `GOTO`.
- ❌ Bucles sin cota superior conocida. En un PLC, un bucle largo es un watchdog.
- ❌ Bloques de más de ~200 líneas. Si crece, se parte.

---

## Antipatrones

> Cada uno de estos es un error real que ya se cometió y se corrigió en `60-library/`, no una
> lista teórica. Ver [`patrones-por-bloque.md`](patrones-por-bloque.md) para la versión correcta
> de cada uno.

### ❌ Calcular el enclavamiento dentro del FB

```pascal
// mal — FB_Motor decidiendo por su cuenta si el permiso de marcha existe
IF #Sensor01 AND #Sensor02 AND NOT #Jam THEN
   #statInterlockOk := TRUE;
END_IF;
```

`Interlock` **entra** como parámetro; el FB nunca calcula las condiciones de permiso. Si lo
hiciera, el mantenedor tendría que abrir el SCL para entender por qué la máquina no arranca, en
vez de mirar el network LAD donde se llama al bloque. Ver
[patrón 1](patrones-por-bloque.md#1-el-enclavamiento-entra-por-parámetro-nunca-se-calcula-dentro).

### ❌ Escribir una salida en más de un sitio

```pascal
// mal — #Fault se escribe en dos regiones distintas del mismo bloque
REGION 1
   IF #CmdReset THEN #Fault := FALSE; END_IF;
END_REGION
REGION 3
   IF #tonStart.Q THEN #Fault := TRUE; END_IF;
END_REGION
```

✅ *Verificado compilando*: esto produce `The parameter '#Fault' might not be initialized.` — el
compilador lo rechaza, no es solo una preferencia. La corrección real que se aplicó a
`FB_Motor`/`FB_ValveOnOff`: todo el estado vive en una variable `stat`, la salida se publica una
única vez en la última región.

### ❌ Mezclar rangos de `FaultCode` entre familias

```pascal
// mal — un codigo de motor (1xx) puesto en un bloque de valvula
#FaultCode := 101;   // dentro de FB_ValveOnOff
```

El rango dice de qué familia es el fallo sin tener que abrir el bloque
(`patrones-por-bloque.md` #4). Un `FaultCode` de válvula fuera del rango `2xx` rompe esa
convención para quien lea el HMI o el histórico de alarmas.

### ❌ Cuatro `IF` sueltos para precedencias en vez de un único `IF/ELSIF`

```pascal
// mal — las cuatro condiciones pueden ser TRUE a la vez, gana la ultima que se evalua
IF #CmdAuto THEN #statMode := #MODE_AUTO; END_IF;
IF #CmdManual THEN #statMode := #MODE_MANUAL; END_IF;
IF #CmdStop THEN #statMode := #MODE_STOPPED; END_IF;
IF #statEmergency THEN #statMode := #MODE_STOPPED; END_IF;
```

Con `IF` independientes, el resultado depende del orden de las líneas, no de una precedencia
declarada — y ese orden es fácil de alterar sin darse cuenta en una edición futura. Un único
`IF/ELSIF` (como en `FB_ModeManager`) hace la precedencia explícita e imposible de romper por
accidente.

---

## Tipos de datos / UDTs

⚠️ **Por confirmar.** Hoy no hay ningún UDT propio verificado en `60-library/` — los cinco
bloques usan tipos elementales (`Bool`, `Int`, `Time`) y su propio DB de instancia, sin ningún
`TYPE ... END_TYPE` compartido. El patrón previsto para cuando haga falta un UDT (por ejemplo,
una interfaz HMI por dispositivo — ver "Lo que falta" en
[`60-library/blocks/README.md`](../../60-library/blocks/README.md)) es documentarlo aquí con el
mismo nivel de evidencia que el resto de esta página: código real, compilado, con la fecha y el
resultado de la compilación. No hay que inventar un UDT de ejemplo solo para rellenar esta
sección.

---

## Cómo llega el SCL al proyecto

Dos caminos, ambos válidos:

| Camino | Cuándo | Cómo |
|---|---|---|
| **Fuente externa** | SCL complejo, con `FOR`, `CASE`, expresiones largas | `ImportPlcExternalSource` → `GenerateBlocksFromExternalSource` |
| **Documento SIMATIC SD** | Edición de un bloque existente, flujo de git | `.s7dcl` ↔ `GetBlockSource` / `ImportFromDocuments` |

🔒 **El segundo es el que hace que git sirva.** Un `.s7dcl` es texto: se lee, se revisa en un
diff y se devuelve a TIA. Requiere TIA V20+ (ADR-002).
