---
name: tia-create-project
description: Crea un proyecto TIA Portal completo desde un spec del usuario — proyecto, CPU, HMI, tags, fuentes SCL, pantalla de operación — compilando 0/0 y verificando estándares antes de darlo por terminado. Usar cuando el usuario pide "crea un proyecto", "arranca una maqueta nueva", "planta un proyecto demo" o empieza de cero una máquina o línea. Basado en la receta R30 ya probada con el proyecto DEMO-Cinta01.
---

# tia-create-project — proyecto nuevo desde spec

> **Estado: BORRADOR AVANZADO.** La receta R30 que lo sostiene está verificada de punta
> a punta (DEMO-Cinta01, 2026-10-21, ADR-016). La skill envuelve ese flujo y añade la
> toma de direcciones del usuario.

## Cuándo usarlo

- No hay proyecto: se parte del papel. El usuario cuenta qué máquina o proceso quiere
  probar y con qué elementos (CPU, actuadores, pantallazo, si acaso).
- Reemplaza el intento manual paso a paso: el flujo está verificado y hay que seguirlo
  en pie y no el del proyecto enht presente en memoria.

## Antes de empezar

1. `AGENTS.md` cargado; perfil `tia-create` para la creación (proyectos, hardware, red,
   HMI), y el perfil aislado de escritura del `tia-inspect` cuando toque lógica.
2. **Spec del usuario** recogido y confirmado: dispositivo, modelo (o la decisión de
   usar la CPU del fixture de referencia), señales E/P, HMI mínimo, estándar de calidad
   (`Check-TiaStandards` código 0 como requisito de aceptación).
3. Precauciones de ruta: el proyecto no cabe en ninguna carpeta que proceda de 143+
   caracteres (limitación medida); elegir `40-projects/<nombre>` y confirmar espacio.

## Pasos

1. [⭐] Spec formal y dryRun de la creación con el perfil `create`.
2. [⭐] Proyecto + hardware + red en un solo ciclo: el OB cíclico lo nombra TIA (`Main`,
   no `OB_Main`).
3. [⭐] Tags y fuentes SCL de los bloques con el estándar F libre comprobado (`isFailsafe
   =false` y `isSafety =false` en sesión live antes de importar nada).
4. [⭐] El DB de instancia se declara en la fuente SCL con `DATA_BLOCK`.
5. [⭐] Pantalla HMI desde JSON + contrato de pantalla (como en `tia-hmi-screen`).
6. [⭐] Compilación 0/0, export textual, `Check-TiaStandards.ps1` → código 0.
7. [⭐] Espejo en `50-examples/` y commit con el contenido funcional real.
8. [⚠] Aceptación en PLCSIM si el spec incluye "que funcione": mano a `tia-plcsim-
   acceptance`, no improvisa la descarga.

## Verificación

- El proyecto se declara *creado* al llegar: 0/0 compilación + export completo +
  estándares en 0 + espejo docs/en la lista; y queda trazado qué quedó sin comprobar.

## Si falla

| Fallo | Acción |
|---|---|
| Ruta demasiado larga | mover a 40-projects/<nombre corto>; no seguir a la ciega |
| `OB_Main` al fallar la compilación | el OB del proyecto se llama `Main`: renombramiento explícito en la fórmula (R30) |
| El check de estándares devuelve != 0 | se ajusta el estándar o se revierte; nunca se declara paso 0 sin readback |
| HMI unificada no arranca | runtime incompatible: declarado (R31/ADR-017) |

## Referencias

- Receta: `10-kb/20-recetas/R30-crear-proyecto-desde-spec.md`
- ADR-016 (PA-1 cumplida), ADR-017 (runtime)
