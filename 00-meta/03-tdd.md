# TDD — Decisiones a cerrar

> Cada pregunta lleva **mi recomendación** marcada con ⭐. Si algo te da igual, responde
> "recomendación" y seguimos. Lo que de verdad necesito de ti es el **bloque C**: esa
> información no está en ningún repo, solo la tienes tú.
>
> Formato de respuesta cómodo: `Q1: b · Q2: ⭐ · Q3: V20 · ...`

---

## Bloque A — Entorno y alcance técnico

### Q1. Toolchain de compilación
`tia-inspect` (heilingbrunner) no tiene binario publicado. Hoy no tienes .NET SDK ni Visual Studio.

- **a)** Instalar .NET SDK 9/10 (≈250 MB, sin permisos de admin con el instalador de usuario) y compilar
- **b)** ⭐ Instalar la extensión de VS Code *TIA-Portal MCP-Server* solo para extraer el `.exe` ya compilado, sin SDK
- **c)** Renunciar a heilingbrunner y trabajar solo con bulaofen
- **d)** Instalar Visual Studio Community completo

> **Por qué (b):** te da el binario en 2 minutos sin instalar un SDK, y la extensión trae el
> `.exe` en `~/.vscode/extensions/`. El coste es que quedas atado a la versión que publiquen.
> Si prevés modificar el servidor, entonces (a).
>
> ⚠️ **Riesgo real de (b):** desconozco si la extensión publicada incluye ya las 99 herramientas
> del `main` que hemos leído. Lo verificaría en M0 antes de comprometernos.

### Q2. ¿Qué harnesses tienen que funcionar de verdad?
Marca todos los que uses. Cada uno son ~30 líneas de adaptador, pero probarlos de verdad cuesta.

`[ ] Claude Code  [ ] Codex  [ ] OpenCode  [ ] Antigravity  [ ] Cursor  [ ] VS Code+Copilot  [ ] otro: ___`

> ⭐ Recomiendo **priorizar dos** para M2 y dejar el resto como "el adaptador existe pero no está
> probado". Probar 6 harnesses multiplica el trabajo de verificación sin aportar capacidad nueva.

### Q3. Versión de TIA objetivo
Tienes V19 y V20. El export textual `.s7dcl` (la pieza que hace que git sirva) **requiere V20+**.

- **a)** ⭐ **V20 fija.** Todo el workspace asume V20
- **b)** V19 fija (pierdes export textual → git deja de tener sentido real)
- **c)** Ambas, con perfiles conmutables (más complejidad desde el día 1)

### Q4. ¿Tienes o vas a tener V21?
Cambia bastante: V21 desbloquea el Version Control Interface completo y el servidor de Czarnak
(el de mejor arquitectura de escritura, con tokens preview/apply y auditoría).

`[ ] Sí, ya  [ ] Sí, en los próximos meses  [ ] No previsto`

### Q5. Hardware físico
¿El agente va a trabajar contra PLCs reales o solo simulación?

- **a)** ⭐ Solo offline + PLCSIM al principio; hardware más adelante con protocolo explícito
- **b)** Hardware desde el principio (necesitamos definir el protocolo de seguridad ya)
- **c)** Solo offline, nunca online

> Tienes **PLCSIM V19** instalado, pero **no PLCSIM Advanced**. Con V20 como objetivo (Q3=a)
> hay que comprobar si tienes PLCSIM V20; si no, la validación en runtime se queda coja y eso
> afecta al criterio de aceptación de PA-1.

### Q6. ¿Trabajas con Safety (F-CPU) o Startdrive/SINAMICS?
Cambia el alcance de la base de conocimiento de forma importante — los snippets de Siemens
dedican un tercio a Startdrive/DCC y a Safety Integrated.

`[ ] Safety  [ ] Startdrive/accionamientos  [ ] Technology Objects (ejes)  [ ] Ninguno  [ ] Otro: ___`

---

## Bloque B — Arquitectura del workspace

### Q7. Perfil de servidores MCP
- **a)** ⭐ Los dos siempre activos: `tia-inspect` (lectura) + `tia-create` (lite)
- **b)** Solo `tia-inspect` por defecto; `tia-create` se activa a mano cuando toca crear
- **c)** Perfiles: `read` / `build` / `full`, conmutables con un script

### Q8. ¿Empaquetar como plugin de Claude Code?
bulaofen ya trae `.claude-plugin/plugin.json`. Podríamos hacer lo mismo con nuestro workspace:
`/plugin install` y listo en cualquier máquina.

- **a)** ⭐ Sí, pero **al final** (M6+). Primero que funcione, luego que se empaquete
- **b)** Sí, desde el principio
- **c)** No, con la carpeta clonada basta

### Q9. Git — esto importa y es irreversible si se hace mal
- **a)** ⭐ Repo **privado** único para todo el workspace. `tia/` ignorado, `src/` versionado
- **b)** Repo local sin remoto (solo historial, nada sale de la máquina)
- **c)** Workspace público (conocimiento + herramientas) y proyectos en repos privados aparte
- **d)** Sin git

> **Pregunta crítica dentro de esta:** ¿hay proyectos de **cliente** aquí? Si sí, la opción por
> defecto tiene que ser restrictiva y decidir qué se publica caso por caso, no al revés.

### Q10. Nombres de carpeta
- **a)** ⭐ Prefijos numéricos: `10-kb/`, `20-standards/`, `40-projects/`...
- **b)** Nombres planos: `kb/`, `standards/`, `projects/`...
- **c)** En español: `10-conocimiento/`, `20-estandares/`, `40-proyectos/`...

### Q11. Idioma
- **a)** ⭐ Docs y estándares en **español**; código, nombres de bloques y tags en **inglés**
- **b)** Todo en español
- **c)** Todo en inglés
- **d)** Docs en español, y además una versión en inglés de `10-kb/`

> (a) es lo habitual en automatización industrial: la documentación se lee en tu idioma, pero
> `Motor_Start` viaja mejor que `Motor_Marcha` cuando el proyecto cambia de manos.

---

## Bloque C — Tus estándares ⚠️ *esto solo lo sabes tú*

Esta es la parte que ningún repo puede darme. Si puedes **enseñarme 1-2 proyectos tuyos reales**
(aunque sea solo el árbol del proyecto y un par de bloques exportados), extraigo el 80% de este
bloque yo solo y solo te pregunto lo dudoso. **Es con diferencia la vía más rápida.**

### Q12. Nomenclatura de bloques
¿Cómo nombras OBs, FBs, FCs, DBs? Ejemplos reales tuyos, por favor.

```
FB:  ______________________   p.ej. FB_Motor / FB100_Motor / Motor_Ctrl
FC:  ______________________
DB de instancia: ___________   p.ej. iDB_Motor01 / DB_Motor01_Inst
DB global:       ___________
UDT:             ___________   p.ej. UDT_Motor / typeMotor
OB:              ___________
```

### Q13. Nomenclatura de tags
```
Entrada digital:  ____________   p.ej. DI_Cinta01_Marcha / xCinta01Marcha
Salida digital:   ____________
Entrada analóg.:  ____________
Marca interna:    ____________
Constante:        ____________
```
¿Usas notación húngara (`xBool`, `iInt`, `rReal`)? `[ ] Sí  [ ] No`
¿Idioma de los nombres de tag? `[ ] ES  [ ] EN`

### Q14. Estructura de un proyecto tuyo terminado
¿Cómo organizas los grupos dentro de *Program blocks*? Ejemplo de lo que busco:

```
Program blocks/
├── 00_Main/           OB1, OB100, OBs de error
├── 10_Safety/
├── 20_Modos/          Manual/Auto/Emergencia
├── 30_Secuencias/
├── 40_Accionamientos/ motores, válvulas
├── 50_Comunicaciones/
├── 80_Diagnostico/
└── 90_Librería/       bloques reutilizables
```

Tu estructura real: _______________________________________

### Q15. Lenguaje por defecto
- ¿En qué escribes la lógica principal? `[ ] LAD  [ ] SCL  [ ] FBD  [ ] STL  [ ] GRAPH`
- ¿Cuándo usas SCL y cuándo LAD? _______________________
- ¿Hay algo que **nunca** quieras que use el agente? _______________________

> Esto es crítico: LAD es mucho más difícil de generar bien por IA (es XML posicional), SCL es
> texto. Si aceptas SCL donde la lógica es cálculo/secuencia y reservas LAD para lo que va a
> leer un mantenedor en planta, la tasa de acierto sube mucho.

### Q16. Comentarios y documentación en el código
- ¿Comentario obligatorio en cada network / cada bloque? _______________
- ¿Idioma de los comentarios? `[ ] ES  [ ] EN  [ ] Ambos`
- ¿Usas los campos Title / Author / Family / Version de las propiedades del bloque?
  Si sí, ¿con qué valores? _______________

### Q17. Qué documentos entrega un proyecto terminado
Marca lo que siempre acompaña a un proyecto tuyo:

`[ ] Lista de E/S  [ ] Descripción funcional  [ ] Manual de operación  [ ] Esquema eléctrico`
`[ ] Matriz de alarmas  [ ] Diagrama GRAFCET/secuencias  [ ] Acta de pruebas FAT/SAT`
`[ ] Capturas de pantallas HMI  [ ] Otro: ___________`

¿Formato? `[ ] Word  [ ] PDF  [ ] Markdown  [ ] Excel  [ ] Otro: _____`

### Q18. Definition of Done
Completa la frase: *"Un proyecto está terminado cuando..."*

```
1. compila con 0 errores y 0 advertencias
2. ___________________________________
3. ___________________________________
4. ___________________________________
```

### Q19. Familias de CPU y HMI habituales
```
CPUs:  [ ] S7-1200  [ ] S7-1500  [ ] S7-1500 Safety  [ ] ET200SP  [ ] S7-300/400  [ ] Otro
HMI:   [ ] WinCC Unified  [ ] WinCC Comfort/Advanced  [ ] WinCC Professional  [ ] Sin HMI
Red:   [ ] PROFINET  [ ] PROFIBUS  [ ] AS-i  [ ] IO-Link  [ ] Modbus  [ ] OPC-UA
```

### Q20. ¿Tienes ya una librería de bloques propia?
Si existe, es el punto de partida de `60-library/` y cambia bastante el plan.

`[ ] Sí, en: ______________  [ ] No, la construimos desde cero  [ ] Parcial`

---

## Bloque D — Seguridad y límites del agente

### Q21. Escrituras en proyecto
- **a)** ⭐ El agente propone, tú confirmas cada operación destructiva
- **b)** Libre en `40-projects/`, confirmación fuera de ahí
- **c)** Libertad total (rápido, y un día te borra un bloque bueno)

### Q22. Backup antes de escribir
- **a)** ⭐ Automático: copia del `.ap20` antes de cualquier sesión de escritura
- **b)** Manual, tú decides
- **c)** Confío en git y en TIA

### Q23. Descarga a PLC
- **a)** ⭐ **Nunca** de forma autónoma. Ni a PLCSIM sin avisar, ni a hardware jamás sin tu OK explícito en el momento
- **b)** PLCSIM libre, hardware con confirmación
- **c)** Ambos con confirmación

> Mi posición: esto no es una preferencia, es un límite de seguridad. Un PLC mal descargado
> mueve maquinaria. Lo voy a escribir como regla dura en `AGENTS.md` salvo que me digas lo
> contrario, y aun así (a) o (b) son las únicas que puedo recomendar.

### Q24. Proyectos de cliente
¿Hay información confidencial (nombres de cliente, recetas de producto, know-how) que no deba
salir nunca de esta máquina ni aparecer en prompts a APIs en la nube?

`[ ] Sí → hay que definir qué se anonimiza  [ ] No  [ ] Depende del proyecto`

---

## Bloque E — Flujo de trabajo

### Q25. ¿Cómo empieza un proyecto nuevo tuyo hoy?
- **a)** Desde cero, TIA en blanco
- **b)** Copiando un proyecto anterior parecido
- **c)** Desde una plantilla propia
- **d)** Desde una plantilla de cliente/corporativa

> Si es (b) o (c), esa plantilla es exactamente lo que hay que convertir en
> `40-projects/_template/` y en un blueprint de `ScaffoldProject`.

### Q26. ¿Qué tarea te come más tiempo hoy y te gustaría delegar primero?
Ordena 1-5 (1 = más urgente):

```
___ Crear la estructura inicial de un proyecto
___ Escribir lógica repetitiva (motores, válvulas, secuencias)
___ Tablas de tags y direccionamiento
___ Pantallas HMI
___ Documentación
___ Migrar/adaptar proyectos antiguos
___ Buscar cosas en proyectos ajenos ("¿dónde está esto?")
___ Otro: ________________
```

> Esto decide qué recetas de `10-kb/20-recetas/` escribo primero. Sin esto, escribo por orden
> alfabético y te sirve la mitad.

### Q27. ¿Trabajas solo o en equipo sobre los mismos proyectos?
`[ ] Solo  [ ] Equipo  [ ] Equipo con Multiuser Server de TIA`

> Si hay Multiuser, cambia el manejo de sesiones: heilingbrunner distingue `SaveProject` de
> `SaveSession` y hay que respetarlo.

### Q28. Formato de los ejemplos migrados
Los 5 ejemplos son V16. Migrar es irreversible sobre el fichero.

- **a)** ⭐ Migrar copias a V20 y conservar los originales V16 en `_ref/`
- **b)** Dejarlos en V16 y solo documentarlos (no se pueden abrir ni inspeccionar)
- **c)** Migrar solo los que de verdad interesen (¿cuáles? ________)

---

## Preguntas que tengo yo para ti, fuera de guion

1. **¿Qué te ha llevado a montar esto ahora?** ¿Un proyecto concreto en marcha, o construir la
   capacidad? Si hay un proyecto real con fecha, el plan se reordena para servirlo a él.
2. **¿Cuánto tiempo tienes?** M3+M4 son ~15 h de trabajo mío pero necesitan input tuyo a ratos.
3. **¿Qué es lo que más miedo te da** de que una IA toque tus proyectos? Eso se convierte
   directamente en reglas duras de `AGENTS.md`.
