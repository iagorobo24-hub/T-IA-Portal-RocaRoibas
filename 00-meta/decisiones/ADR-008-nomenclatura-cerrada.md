# ADR-008 — Las 5 dudas de nomenclatura, cerradas

- **Fecha:** 2026-09-14
- **Estado:** ✅ Aceptada
- **Pregunta origen:** las 5 dudas abiertas de `20-standards/naming.md` (N1-N5)
- **Decidido por:** yo, a petición del usuario ("responde tú, lo que recomiendes")

## Contexto

La propuesta de nomenclatura de [ADR-007](ADR-007-estandares.md) dejó cinco puntos sin cerrar
porque eran cuestión de gusto. Entre medias se migraron, inventariaron y exportaron los **7
proyectos de `50-examples/`**, así que las decisiones ya no se toman en abstracto: hay evidencia
de qué hace gente real en proyectos reales.

## Decisiones

| # | Duda | Decisión | ¿Coincide con los ejemplos? |
|---|---|---|---|
| N1 | Notación húngara | **No.** Prefijo por rol (`DI_`, `AO_`), no por tipo | ✅ 0 de 7 la usan |
| N2 | DBs de instancia | **`iDB_<Equipo>`** | ❌ **6 de 6 usan `<FB>_DB`** |
| N3 | Prefijo de área | Solo en bloques de proceso; organizar con **grupos** | ✅ los IoT usan carpetas |
| N4 | Idioma de comentarios | **Español**, con `en-US` añadible después | ❌ todos en inglés |
| N5 | Author / Family / Version | **Obligatorio en librería**, opcional en proceso | ❌ ninguno los rellena |

## La única decisión que contradice la evidencia unánime: N2

Los seis proyectos con FBs usan `<NombreFB>_DB` — que es además lo que **TIA propone solo**.
Aun así se decide lo contrario, y conviene dejar escrito el porqué para poder revisarlo:

🔴 **Los siete proyectos tienen UNA instancia por FB.** Con una sola instancia, `<FB>_DB` es
perfecto. Con veinte motores, TIA genera `FB_Motor_DB`, `FB_Motor_DB_1`… `FB_Motor_DB_19`, y el
número **no identifica el equipo**: hay que abrir el Main y buscar la llamada.

`iDB_M01` lleva dentro el código ISA del equipo, el mismo que está en el P&ID y en el esquema
eléctrico.

**Coste:** renombrar lo que TIA propone, cada vez. Tres segundos.
**Excepción:** un FB del que solo habrá una instancia (coordinador, gestor de modos) puede
quedarse con `<FB>_DB`.

> Si al aplicarlo en un proyecto real resulta que renombrar cansa más de lo que aporta, esta es
> la decisión a revisar primero.

## Hallazgos técnicos que sustentan N4 y N1

**N4 — los comentarios de TIA son multi-idioma.** Verificado en un `.s7res` exportado:

```xml
<Comment Id="MLC_U4">
  <MultiLanguageText Lang="en-US">Trigger fault when the cylinder is set
  to extend and retract at the same time</MultiLanguageText>
</Comment>
```

Cada comentario se almacena **por idioma**. Escribir en español ahora no cierra la puerta: añadir
`en-US` después es traducir, no reescribir código. Eso convierte N4 en una decisión reversible y
por tanto barata.

**N1 — el prefijo bueno es el de rol.** El sorting plant prefija por **origen físico**
(`cs` sensor de cinta, `os` salida de simulación, `pc` cilindro de empuje), no por tipo de dato.
Un prefijo de rol no caduca; uno de tipo miente en cuanto cambias `Int` por `DInt`.

## Consecuencias

- `20-standards/naming.md` queda **cerrado a falta de usarlo**.
- Se desbloquea la tanda 3 de recetas (motores, válvulas, secuencias), que dependía de esto.
- Lo que falta ya no es decidir: es **aplicarlo a un proyecto propio** y ver qué chirría.
