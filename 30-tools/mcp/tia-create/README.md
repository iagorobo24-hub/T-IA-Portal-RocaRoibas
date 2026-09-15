# tia-create V20

Estado actual: **no instalado**.

El manifest central (`30-tools/mcp/servers.json`) conserva la ruta prevista y el motivo del
bloqueo, pero ningún perfil la expone todavía. No se debe inventar un ejecutable ni sustituirlo
por otro servidor con una API diferente.

Para activar esta entrada hacen falta un runtime identificable y verificable, compatible con
Openness V20, y una prueba de arranque que publique las herramientas de creación esperadas. La
prueba de disponibilidad es `30-tools/tests/Test-TiaCreateAvailability.ps1`.

Mientras tanto, la creación se limita a las operaciones de escritura de `tia-inspect`, con backup,
preview, compilación y guardado bajo el contrato de `AGENTS.md`.
