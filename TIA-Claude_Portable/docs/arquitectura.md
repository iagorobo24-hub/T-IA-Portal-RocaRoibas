# Arquitectura del paquete portable

```text
Claude Code / Codex / OpenCode / Antigravity / Cursor
                 |
       AGENTS.md + 10-kb + 20-standards
                 |
       configuracion generada por maquina
                 |
      tia-inspect (read/write) / tia-create (create)
                 |
       Siemens TIA Openness API V20
                 |
          TIA Portal + PLCSIM/WinCC
```

La fuente de verdad es Markdown y scripts portables. Las configuraciones de cada harness se generan localmente porque los ejecutables y las rutas cambian entre ordenadores.

## Perfiles

- `read`: inspección, análisis, compilación y exportación; sin escrituras de proyecto.
- `write`: modificación explícita mediante propuestas, backup, preview, compilación y guardado.
- `create`: creación de proyectos/hardware/HMI mediante `tia-create` en perfil lite.
- `full`: combinación explícita de `write` y `create`; todos los perfiles no-`read` requieren
  reconocimiento.

V20 es la versión canónica porque permite exportar documentos SIMATIC SD. V19 puede usarse como compatibilidad limitada, pero no debe considerarse equivalente.

## Separación de datos

El workspace puede ser público. Los proyectos de cliente deben estar en repositorios privados o en una carpeta privada separada. Los binarios de TIA no son la verdad revisable: `src/` contiene el export textual que debe revisarse y versionarse.
