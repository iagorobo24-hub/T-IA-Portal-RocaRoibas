# Definition of Done

> **Estado: PROPUESTA.** Ver [`README.md`](README.md).
> Un proyecto no está "casi terminado". O pasa esta lista, o no está terminado.

## Nivel 1 — Compila y está ordenado

- [ ] Compila con **0 errores**
- [ ] **0 advertencias**, o cada advertencia que queda está justificada por escrito en el README
- [ ] Sin bloques huérfanos: todo lo que existe se llama desde algún sitio *(verificable con cross-references)*
- [ ] Sin tags declaradas y no usadas
- [ ] Nada en la `Default tag table`
- [ ] Nombres conformes a [`naming.md`](naming.md)
- [ ] Bloques en el grupo que les toca según [`estructura-proyecto.md`](estructura-proyecto.md)

## Nivel 2 — Se entiende

- [ ] Cada bloque tiene comentario de cabecera: **qué hace y por qué existe**
- [ ] Cada network de LAD y cada región de SCL, comentada
- [ ] Propiedades del bloque rellenas: `Author`, `Family`, `Version`
- [ ] UDTs agrupados por rol y comentados miembro a miembro
- [ ] `README.md` del proyecto al día, incluida la sección de decisiones raras

## Nivel 3 — Es recuperable

- [ ] Exportado a `src/` y commiteado
- [ ] El último commit describe **qué cambió funcionalmente**
- [ ] Copia del `.ap20` en sitio seguro
- [ ] Lista de E/S actualizada y coincidente con las tags reales

## Nivel 4 — Está probado

- [ ] Probado en **PLCSIM**, no solo compilado
- [ ] Secuencias recorridas de principio a fin, incluidos los caminos de fallo
- [ ] Enclavamientos verificados **provocando la condición**, no leyendo el código
- [ ] Comportamiento comprobado ante: paro de emergencia, corte de alimentación, pérdida de
      comunicación con el HMI
- [ ] Alarmas: cada una se dispara cuando debe y se borra cuando debe

## Nivel 5 — Se puede entregar

- [ ] Descripción funcional escrita
- [ ] Matriz de alarmas con causa y acción para cada una
- [ ] Manual de operación, aunque sea una página
- [ ] Acta de pruebas FAT firmada
- [ ] Backup del proyecto entregado al cliente

---

## Qué puede verificar el agente y qué no

| Nivel | ¿Lo verifica el agente? |
|---|---|
| 1 — compila y ordenado | ✅ **Sí, entero.** Compilación, cross-references, nombres, grupos |
| 2 — se entiende | ⚠️ Parcial. Detecta comentarios ausentes; no juzga si son útiles |
| 3 — recuperable | ✅ Sí |
| 4 — probado | ❌ **No.** Puede preparar y ejecutar casos en PLCSIM, pero **quien decide que una máquina es segura eres tú** |
| 5 — entregable | ⚠️ Redacta borradores; el contenido lo validas tú |

🔒 **El nivel 4 no se delega.** El agente puede hacer todo el trabajo mecánico de las pruebas,
pero la firma de que una máquina se comporta bien es tuya, con tu nombre y tu responsabilidad.
Está escrito así en `AGENTS.md` y no es negociable por conversación.
