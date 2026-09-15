# Funcionamiento operativo

## Arranque obligatorio

1. Ejecutar `Doctor`.
2. Conectar o adjuntarse a la instancia existente de TIA Portal.
3. Ejecutar `GetProjectTree`.
4. Obtener las rutas reales con `GetSoftwareTree`.
5. Leer antes de escribir.
6. Hacer backup.
7. Usar preview/dryRun.
8. Cambiar un bloque cada vez.
9. Compilar con cero errores antes de guardar.
10. Exportar a `src/` y registrar la evidencia.

## Limitaciones deliberadas

- Openness utiliza rutas de ingeniería, no nombres inventados.
- Openness no es thread-safe.
- Los bloques protegidos y F-blocks no se editan.
- El agente no genera LAD XML a mano.
- El servidor MCP no sustituye al Runtime HMI ni a la validación visual de una pantalla.
- La descarga a un PLC físico siempre requiere confirmación puntual del usuario.
