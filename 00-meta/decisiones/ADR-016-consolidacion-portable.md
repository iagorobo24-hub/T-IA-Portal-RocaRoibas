# ADR-016 — Una sola `TIA-Claude_Portable`: manda la interna

- **Fecha:** 2026-09-22
- **Estado:** aceptada
- **Evidencia:** `00-meta/05-comparacion-portable-2026-09-22.md`

## Contexto

Tras la copia entre equipos quedaron dos árboles con el mismo nombre: uno dentro del repo
(`TIA-Claude\TIA-Claude_Portable`) y otro suelto en `Documents\TIA-Claude_Portable`.

## Decisión

La copia **interna** es la única fuente de verdad del empaquetador portable. Su
`manifests/package-info.json` se declara `metadataRole: "build-input-template"` con `generatedUtc:
null`, y sus scripts de build y tests son estrictamente más nuevos y más grandes que los de la suelta.

La copia **suelta** es una salida generada el 2026-09-15 que se autodeclara legacy
(`legacyMonolithicWorkspace: "workspace/"`) y arrastra un `workspace/` obsoleto — su `AGENTS.md` es
5,6 KB más corto que el vivo. Nada de ella se promueve al repo.

## Excepciones que se rescatan

1. `workspace/_ref/` — clones locales de los siete repos de referencia. No están en el repo
   principal. Se mueven a `_ref/` en la raíz y se mantienen **fuera de git** vía `.gitignore`: son
   código de terceros con licencias propias y no deben redistribuirse desde nuestro repo.
2. `Prompt.txt` — encargo original. Se conserva como `00-meta/encargo-original.txt`.

## Consecuencias

- Tras rescatar 1 y 2, la carpeta suelta queda descartable. El borrado lo hace el usuario, no el
  agente; si un agente la retira, la mueve a `_to_delete/` y lo reporta.
- El `.mcp.json` de la copia suelta apunta a un binario V20 bajo `...\workspace\30-tools\...`;
  queda invalidado por ADR-015 igual que el del repo.
