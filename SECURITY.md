# Seguridad y confidencialidad

Este repositorio contiene herramientas y conocimiento genérico para TIA Portal. Se considera
público. Los proyectos de cliente, `.ap20`, documentación eléctrica, contraseñas, safety y
know-how protegido deben permanecer fuera del repositorio y en un repositorio privado separado.

Antes de publicar o compartir un paquete:

1. Ejecuta `30-tools/scripts/Audit-PublicBoundary.ps1`.
2. Comprueba que no hay archivos prohibidos rastreados por Git.
3. Revisa manualmente los nombres y comentarios de ejemplos para eliminar datos de cliente.
4. No incluyas credenciales, passwords de Openness, licencias ni configuraciones de red reales.

Un agente puede leer y modificar proyectos dentro del alcance del usuario, pero no debe copiar
automáticamente contenido de `40-projects/` a la base de conocimiento, librería o paquete público.
