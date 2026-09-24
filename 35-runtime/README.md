# `35-runtime/` — un subárbol por versión de TIA Portal

Aquí vive **todo lo que depende de la versión de TIA Portal, y solo eso**.

```
35-runtime/
├─ v18/
│  ├─ PERFIL.md              ← qué funciona y qué no en esta versión
│  ├─ bin/tia-inspect/       ← binario compilado contra Openness V18   (no versionado)
│  ├─ tools/fixture-generator/ ← genera proyectos .ap18 desechables
│  ├─ fixtures/              ← proyectos de prueba                     (no versionado)
│  └─ runs/                  ← evidencia de ejecución                  (no versionado)
└─ v20/
   ├─ PERFIL.md
   └─ bin/{tia-inspect,tia-create}/                                    (no versionado)
```

## Qué NO va aquí

El conocimiento de TIA Portal, los estándares, la librería de bloques, los ADRs y los proyectos
**no dependen de la versión de Openness** y siguen compartidos en `10-kb/`, `20-standards/`,
`60-library/`, `00-meta/` y `40-projects/`.

> Un DB optimizado funciona igual en V16 que en V20, y un `FB_Motor.scl` compila en las cuatro.
> Duplicarlos por versión significaría corregir un bug en `v18/` y no en `v20/`, que es la forma
> más rápida de acabar con dos librerías que divergen sin que nadie se entere.

Lo que sí varía de una versión a otra es **la superficie de la API Openness**, y eso se declara en
el `PERFIL.md` de cada una y en `30-tools/mcp/servers.json`.

## Qué se versiona y qué no

| | Versionado |
|---|---|
| `PERFIL.md` de cada versión | **Sí** |
| Código fuente de las herramientas (`tools/*/[Program.cs, *.csproj]`) | **Sí** |
| `bin/` — binarios compilados | No. Se reconstruyen con `build.ps1 -TiaMajor <N>` |
| `fixtures/` — proyectos TIA | No. Son binarios y se regeneran |
| `runs/` — evidencia de ejecución | No. Es local de cada máquina |

## Añadir una versión nueva

1. `30-tools/mcp/tia-inspect/build.ps1` → añadir `<N>` al `ValidateSet` y al mapa de paquetes NuGet.
2. `30-tools/scripts/Sync-HarnessConfigs.ps1` → añadir `<N>` a su `ValidateSet`.
3. `30-tools/mcp/servers.json` → entrada en `servers.tia-inspect.versions.<N>`.
4. `30-tools/scripts/New-TiaFixtureManifest.ps1` → añadir `.ap<N>` a `$allowedFixtureExtensions`.
5. Compilar: `build.ps1 -TiaMajor <N>` deja el binario en `35-runtime/v<N>/bin/tia-inspect/`.
6. Escribir `35-runtime/v<N>/PERFIL.md` con lo que **se ha verificado ejecutando**, no con lo que
   se espera que funcione.
7. `AGENTS.md` §9 → añadir la máquina/versión a la tabla.

El código fuente **no se bifurca**: las diferencias entre versiones van tras `#if`, como
`TIA_V20_PLUS` y `TIA_V21_PLUS`. Ver `00-meta/07-viabilidad-openness-v15-v18.md`.
