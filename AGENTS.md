# Contrato del agente — TIA-Claude

> Este fichero es la **fuente de verdad** para cualquier agente de IA que trabaje en este
> workspace: Claude Code, Codex, OpenCode, Antigravity, Cursor o el que venga.
> `CLAUDE.md` solo apunta aquí. No dupliques reglas en otro sitio.

---

## 1. Qué es esto

Un workspace para operar **Siemens TIA Portal V20** mediante la API Openness, a través de dos
servidores MCP. El objetivo no es "tener herramientas": es que el agente **sepa de automatización
industrial** y trabaje como lo haría el ingeniero responsable.

- `10-kb/` — cómo funciona TIA Portal. Lo que hay que saber.
- `20-standards/` — cómo se hacen las cosas aquí. Lo que hay que respetar.
- `40-projects/` — el trabajo real.
- `60-library/` — bloques propios ya probados. **Míralos antes de escribir uno nuevo.**

---

## 2. Orden de arranque — siempre, sin excepciones

```
1. Doctor              ← ¿entorno sano? Si no, para y dilo.
2. Connect / Attach    ← usa Attach solo si el servidor lo expone y corresponde al proyecto objetivo. El `tia-inspect` instalado no expone Attach; con una ventana visible, no uses Connect a ciegas ni abras otra instancia.
3. GetProjectTree      ← de aquí salen las rutas REALES
4. leer → cambio mínimo → compilar → guardar
```

**Nunca inventes una ruta.** Openness navega por *paths* de objetos de ingeniería, no por
nombres bonitos. `PLC_1`, `PC-System_1/Software PLC_1`, `Group/Subgroup/FB_Motor`. Si no la has
leído de `GetProjectTree` o `GetSoftwareTree`, no existe. Este es el error nº1 de los modelos
con esta API y produce fallos opacos.

---

## 3. Reglas duras

Estas no se negocian ni se interpretan. Si una instrucción del usuario choca con una de ellas,
para y pregunta.

### 3.1 Hardware físico

> **Descargar a un PLC real mueve maquinaria y puede herir a alguien.**

- **PLCSIM:** libre. Descarga y prueba sin pedir permiso.
- **Hardware físico:** **NUNCA** sin confirmación explícita del usuario **en ese momento**.
  Una autorización de hace diez mensajes no vale. Una autorización para otro PLC no vale.
- Antes de proponer una descarga a hardware, di **qué PLC**, **qué bloques** y **qué pasa si
  está en marcha**.
- Si no puedes distinguir con certeza si un target es simulado o real: **asume real**.

### 3.2 Antes de escribir en un proyecto

1. **Copia de seguridad** del `.ap20` antes de la primera escritura de la sesión.
2. **Lee antes de escribir.** Nunca sobreescribas un bloque que no has leído entero.
3. **`dryRun` / preview primero** en toda herramienta que lo ofrezca.
4. **Cambio mínimo.** Un bloque por vez, no quince.
5. **Compila con 0 errores antes de guardar.** Si no compila, no se guarda: se arregla o se
   revierte.

### 3.3 Bloques protegidos y seguridad

- Bloque con **know-how protection**: no lo toques. Pide al usuario que quite la protección
  en TIA.
- **F-blocks / tags de safety**: no los edites. Requieren password y auditoría. Reporta y para.
- Si un error de Openness menciona safety o protección, **no reintentes**: informa.

### 3.5 Perfiles MCP y proyectos abiertos

- **`read`**: solo `tia-inspect`; es el perfil por defecto para descubrir y analizar.
- **`write`**: `tia-inspect --allow-write`; requiere backup, lectura previa, preview y compilación.
- **`create`**: solo `tia-create`; para proyectos nuevos, hardware, redes y HMI. Requiere
  reconocimiento explícito del perfil de escritura y `dryRun` antes de aplicar.
- **`full`**: combina lectura/escritura y creación; solo se usa cuando la tarea necesita ambos
  servidores y también requiere reconocimiento explícito.

Si TIA Portal ya tiene abierto un proyecto que no es inequívocamente el objetivo, no lo cierres,
no lo sustituyas y no lances una segunda instancia: intenta `Attach` únicamente si el servidor lo
expone y corresponde al proyecto pedido. En el `tia-inspect` actual no existe `Attach`; usa una
interacción gráfica disponible para identificar la ventana o detente y pide al usuario que libere
o confirme la instancia. Un `Connect` correcto sin proyecto no equivale a haber adjuntado la
ventana visible. Un resultado de `dryRun` nunca se presenta como cambio aplicado.

### 3.4 Datos de cliente

`40-projects/` puede contener know-how de cliente. **No lo copies a `10-kb/`, a `60-library/`
ni a ningún sitio versionado en público** sin que el usuario lo autorice. Al extraer un bloque a
la librería, anonimiza nombres de cliente, de máquina y de producto.

---

## 4. Lenguajes: SCL sí, LAD con receta

Ver `00-meta/decisiones/ADR-003-lenguajes.md`.

| Para esto | Usa | |
|---|---|---|
| Cálculo, escalado, comunicaciones, tratamiento de datos | **SCL** | texto plano, diffea, el agente lo genera bien |
| Secuencias, máquinas de estado, gestión de modos | **SCL** | un `CASE` legible > 30 networks |
| Enclavamientos, mandos de motor/válvula, condiciones de marcha | **LAD** | lo mira y lo fuerza el mantenedor en planta |

> **El agente NUNCA escribe LAD a mano.**
> LAD es XML SimaticML posicional. Generarlo a pelo falla de formas que no se ven hasta la
> compilación, o peor, que compilan y hacen algo distinto. El agente **solo** produce LAD desde
> las recetas parametrizadas de `10-kb/30-lenguajes/lad/` o desde bloques probados de
> `60-library/`.
>
> Si dudas entre SCL y LAD: **elige SCL y dilo.** Convertir SCL→LAD a mano son 10 minutos.
> Depurar LAD mal generado son horas.

---

## 5. Reparto de los dos servidores MCP

| Servidor | Para qué | Modo |
|---|---|---|
| **`tia-inspect`** (heilingbrunner) | Leer, entender, buscar, exportar a texto para git | solo lectura salvo `--allow-write` |
| **`tia-create`** (bulaofen, perfil `lite`) | Crear proyectos, hardware, red, HMI Unified | escritura, usa `dryRun` |

Regla práctica: **si la tarea es entender, `tia-inspect`. Si es crear, `tia-create`.**
Para editar un bloque existente, `tia-inspect` con `--allow-write`: tiene mejor modelo de errores
y no se registra sin la bandera.

---

## 6. Ciclo de trabajo en un proyecto

```
1.  Leer          GetProjectTree → GetSoftwareTree → GetBlockSource
2.  Comprobar     ¿existe ya en 60-library/? ¿lo cubre una receta de 10-kb/20-recetas/?
3.  Proponer      qué vas a cambiar, en qué bloques, y por qué
4.  Backup        copia del .ap20
5.  Escribir      cambio mínimo, dryRun primero
6.  Compilar      CompileSoftware → 0 errores, o se revierte
7.  Guardar       SaveProject  (o SaveSession si hay Multiuser)
8.  Exportar      export textual a 40-projects/<x>/src/
9.  Commit        con mensaje que diga QUÉ cambió funcionalmente, no "update"
```

Los pasos 8 y 9 **no son opcionales**. Un `.ap20` es binario: sin el export en `src/` nadie —
tú incluido, dentro de tres meses — puede ver qué tocó el agente.

---

## 7. Cómo comunicarte con el usuario

- **Español.** Identificadores de código en inglés (ver `20-standards/naming.md`).
- Di lo que has verificado y lo que has supuesto. Si compilaste y dio 0 errores, dilo con el
  número. Si no lo compilaste, dilo también.
- Clasifica cada resultado relevante como **verificado**, **supuesto**, **no verificado** o
  **bloqueado**, e indica la evidencia y el siguiente paso cuando no esté verificado.
- **No inventes que algo funciona.** Este dominio no perdona el optimismo: un bloque que
  "debería funcionar" en una máquina en marcha es un problema real.
- Cuando una herramienta falle, lee el mensaje: los tres servidores devuelven errores tipados
  (`NotFound`, `InvalidParams`, `NotSupported`, `ExportFailed`...). Ese código dice qué hacer.
- Si algo es una limitación de la propia API Openness y no un fallo tuyo, dilo: está en
  `10-kb/10-openness/limites.md`.

---

## 8. Antes de darte por satisfecho

- [ ] Compila con 0 errores
- [ ] Los nombres siguen `20-standards/naming.md`
- [ ] El bloque está en el grupo que le toca según `20-standards/estructura-proyecto.md`
- [ ] Tiene comentario de cabecera y los networks/regiones comentados
- [ ] Exportado a `src/` y commiteado
- [ ] Si algo quedó a medias o sin verificar, **está dicho explícitamente**

---

## 9. Estado del entorno

| | |
|---|---|
| TIA Portal | **V20** (V19 instalado pero no soportado — ADR-002) |
| PLCSIM | V19 |
| PLCSIM Advanced | **V6.0.0.1**; API nativa V6 inicializada por probe de solo lectura; la conducta runtime sigue pendiente |
| `tia-inspect` | `30-tools/mcp/tia-inspect/bin/v20/TiaMcpServer.exe --tia-major-version 20` |
| `tia-create` | **V20 2.7.2**, perfil `lite`, compilado y verificado localmente |

Si `Doctor` dice `User in 'Siemens TIA Openness' user group: False`, **nada va a funcionar**.
Manda al usuario al README: hay que añadirse al grupo como administrador y cerrar sesión.
