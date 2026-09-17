# FBD — no es el lenguaje elegido aquí

## Decisión

[ADR-003](../../00-meta/decisiones/ADR-003-lenguajes.md) reparte la lógica en dos lenguajes:
**SCL** para cálculo/secuencias/modos (texto plano, diffea en git) y **LAD** para lo que un
mantenedor mira y fuerza delante de la máquina (enclavamientos, mandos de motor/válvula). FBD no
aparece en esa tabla porque no cubre un caso de uso que los otros dos no cubran ya en este
workspace:

- Para cálculo y máquinas de estado, SCL es más compacto y versionable que una red de bloques
  funcionales.
- Para lo que un mantenedor necesita mirar delante de la máquina, LAD (contactos) es la
  convención del sector, no bloques FBD.

## Estado

⬜ **No usado, sin contenido propio.** No hay ningún bloque FBD en `60-library/` ni receta que lo
use. Si en el futuro aparece un caso donde FBD sí aporte algo que SCL/LAD no cubran (por ejemplo,
lógica combinacional pura que un electricista de mantenimiento lea mejor en puertas lógicas que
en contactos), esta página es donde documentarlo — con el mismo nivel de evidencia que el resto
de `10-kb/`: código real compilado, no un ejemplo inventado.

## Limitación de exportación

⚠️ **Por confirmar en esta máquina.** No hay evidencia propia registrada sobre qué acepta
exactamente `GenerateBlockSource`/`GetBlockSource` de `tia-inspect` como lenguaje de fuente para
FBD. Antes de asumir que FBD se puede tratar como texto exportable igual que SCL, hay que
comprobarlo con un bloque FBD real y anotar el resultado aquí con marca ✅ o ❌ — no se afirma sin
esa comprobación (ver la disciplina de evidencia de [`10-kb/README.md`](../README.md)).
