# R18 — Medidas y señales analógicas

## Objetivo

Diseñar y aceptar una cadena de medida analógica que conserva por separado el valor bruto,
la magnitud en unidades de ingeniería y la calidad del dato. Esta receta cubre entradas y,
con las mismas comprobaciones de rango, salidas analógicas. No considera un valor convertido
como medida válida si el canal informa diagnóstico de cable, subrango, sobrerango o fallo.

## Estado en este workspace

- **Verificado en el repositorio:** el estándar contempla `AI_`/`AO_`, `50_Analog/` y tipos de
  dato de instrumentos; la librería enumera cinco bloques probados y deja
  `FB_AnalogInput (escalado, límites, filtro)` como pendiente. No hay un bloque de medida
  analógica aceptado localmente.
- **Verificado como guía oficial V20:** `NORM_X` calcula `(VALUE - MIN) / (MAX - MIN)` y
  `SCALE_X` transforma el resultado normalizado a la escala de ingeniería. El diseño de esta
  receta invalida por defecto una medida raw que exceda sus límites nominales.
- **Pendiente local:** no se ha probado una cadena completa con módulo, canal, instrumento,
  PLCSIM ni simulador de señal. La receta es operativa para preparar la prueba, pero no declara
  una medida de campo ya validada.
- **Superficie agente:** MCP/API sirven para leer el proyecto, tags, código y compilar cuando
  la herramienta y su esquema lo exponen. No se ha verificado que el perfil instalado exponga
  todos los parámetros del canal analógico. Si no se pueden leer, inspeccionarlos en TIA GUI;
  no deducir rango, unidad ni dirección del nombre de una tag. Solo se marca una inspección GUI
  como ejecutada por el agente después de consultar el plugin nativo `computer-use` mediante
  `node_repl` + `@oai/sky`, seleccionar una ventana devuelta y comprobar su estado/título. La
  superficie `mcp__cua_repl` es de navegador: `apps=[]` ahí no indica si las ventanas Windows
  están disponibles. Si el plugin nativo no está habilitado o el objetivo no se identifica sin
  ambigüedad, dejar la inspección GUI pendiente y usar una API que exponga esos datos.

## Precondiciones

1. Ejecutar Doctor. Si hay una ventana TIA visible, identificarla primero con Computer Use nativo
   (`node_repl` + `@oai/sky`) y confirmar título, proyecto y versión antes de cualquier `Connect`.
   Si no se puede identificar sin ambigüedad, detenerse y no abrir ni conectar otra instancia.
   Después, usar `Attach` solo si el perfil MCP real lo expone y corresponde al proyecto; `Connect`
   no adjunta por sí solo la ventana visible. Leer `GetProjectTree` y `GetSoftwareTree` y conservar
   literalmente las rutas devueltas.
2. Identificar el PLC, CPU, módulo y número de canal exactos: referencia de catálogo, firmware,
   tipo de señal, rango medible, conexión de 2/3/4 hilos, diagnóstico de rotura de hilo,
   representación digital, valores de subrango/sobrerango y filtros del módulo. Contrastar
   con el manual Siemens del **módulo concreto** y su parametrización en el proyecto.
3. Definir por escrito instrumento, unidades, extremos bruto y de ingeniería, resolución,
   frecuencia de muestreo, filtro, umbrales de proceso, política de calidad y comportamiento
   ante pérdida/recuperación de señal. Confirmar qué estado debe llegar al HMI.
4. Para cualquier edición de PLC, usar un proyecto de prueba/fixture desechable, comprobar que
   se puede hacer backup y leer el bloque entero antes de escribir. La puerta independiente
   exige `GetBlocks.isFailsafe=false`, `programmingLanguage=SCL`, bloque no protegido y cero tags
   Safety según el contrato local. Si no se puede clasificar, parar. No usar el nombre del bloque,
   grupo o tag para clasificar Safety; no editar bloques F ni tags Safety aunque estén en
   `50_Analog/` o se llamen `AI_...`/`AO_...`.
5. Revisar primero `60-library/`; no presentar el pendiente `FB_AnalogInput` como si ya fuese
   un bloque validado. Respetar `20-standards/naming.md` y
   `20-standards/estructura-proyecto.md`: identificadores en inglés, comentarios en español,
   tags `AI_<Equipo>_<Magnitud>`/`AO_<Equipo>_<Magnitud>`, lógica de medida en `50_Analog/`,
   cabecera de bloque y comentarios de regiones/redes. Para cambios de lógica, preferir SCL
   conforme a ADR-003.

## Secuencia

### A. Leer la configuración existente

1. Leer el árbol del proyecto, la configuración del dispositivo y el PLC. Obtener tags por
   `GetTags` o por exportación de tabla e inventario normalizado; conservar símbolo, tipo,
   dirección y comentario.
2. Abrir en TIA la vista de configuración de dispositivo y leer la parametrización **del canal**.
   La dirección simbólica o `%IW` por sí sola no demuestra el rango, el modo eléctrico ni la
   detección de cable roto. Si el API no devuelve esos atributos, anotar «no leído por API» y
   usar GUI/manual Siemens.
3. Consultar la representación del valor bruto del módulo exacto. No generalizar `0..27648`:
   existen rangos de corriente/tensión, valores bipolares y códigos de diagnóstico distintos.
   Por ejemplo, algunos canales 4–20 mA usan `0..27648` para el nominal, mientras que el
   diagnóstico de rotura puede producir otro código. Solo el manual de esa referencia resuelve
   el caso.
4. Trazar dónde se escala el raw, quién consume las unidades, qué bloque filtra y cómo se
   genera el estado de calidad. Si no hay un camino inequívoco, todavía no se edita.

### B. Especificar el cálculo y los estados

1. Mantener tags/miembros distintos, por ejemplo `RawValue`, `ValueEU`, `QualityValid`,
   `ChannelFault`. `RawValue` no se sustituye por el valor escalado ni se usa como HMI.
2. Para un canal válido, definir `RawMin < RawMax` y las unidades de ingeniería explícitas.
   En SCL, la conversión típica es:

   ```scl
   Normalized := NORM_X(MIN := RawMin, VALUE := RawValue, MAX := RawMax);
   ValueEU := SCALE_X(MIN := EuMin, VALUE := Normalized, MAX := EuMax);
   ```

   Asegurar que `MIN`, `VALUE` y `MAX` de `NORM_X` tienen el mismo tipo, y que los parámetros
   de `SCALE_X` respetan sus tipos. Validar el intervalo y `MAX > MIN` antes de ejecutar el
   cálculo; tratar NaN/Inf si los tipos de la cadena lo permiten.
3. La comprobación de diagnóstico/calidad precede al escalado. Distinguir una medida nominal
   baja de una rotura de hilo: en un lazo 4–20 mA, 4 mA puede representar el 0 % de proceso y
   el umbral de cable roto depende del módulo. No transformar un código de diagnóstico en una
   temperatura/presión plausible.
4. Decidir qué se presenta cuando el canal es inválido: conservar último valor válido con marca
   de dato obsoleto o publicar un estado claramente inválido. Como política predeterminada,
   cualquier `RawValue < RawMin` o `RawValue > RawMax` invalida `QualityValid` y el valor EU no
   se presenta como válido; `NORM_X`/`SCALE_X` puede extrapolar fuera del intervalo y no debe
   interpretarse como saturación ni como validación. Una política distinta (por ejemplo, tolerancia
   o clamp) requiere requisito funcional, diagnóstico separado y revisión explícita; nunca se
   fija a cero ni se limita silenciosamente.
5. Definir filtro y alarma por separado. El filtro modifica la respuesta temporal; una alarma
   de proceso evalúa unidades de ingeniería y calidad. Documentar histéresis, retardo,
   enclavamiento y rearme si se usan.
6. Tratar AI y AO como cadenas distintas. Para AI, la entrada es `RawValue`: validar diagnóstico
   y después convertir a `ValueEU` con `NORM_X`/`SCALE_X`. Para AO, la entrada es una consigna
   en unidades de ingeniería: validar permiso y estado del actuador, aplicar la política
   explícita de límite/saturación y convertir en sentido inverso, por ejemplo
   `RawOut = RawMin + (CmdEU - EuMin) * (RawMax - RawMin) / (EuMax - EuMin)`, validando
   `RawMax > RawMin` y `EuMax > EuMin` antes de calcular. Definir tipo/precisión, redondeo y
   política de saturación o rechazo según módulo/actuador; después escribir el canal. No aplicar
   sin más el algoritmo AI al AO ni inferir que escribir el raw confirma la salida eléctrica.
   Definir `OutputEnable`, valor de reposo/fallo, consigna inválida, límites físicos,
   calidad/diagnóstico del canal y realimentación disponible. Una prueba de AO en PLC real exige
   banco/proceso aislado y autorización vigente; nunca se usa como comprobación de software.

### C. Proponer, aplicar y compilar

1. Antes de cualquier cambio, producir una propuesta con entradas, unidades, intervalos y casos
   esperados; generar el código desde una receta/bloque revisado. Para propuestas SCL, usar
   `New-TiaSclProposal.ps1`/`Invoke-TiaWorkflow.ps1 -Workflow propose`. La aplicación SCL de bloques
   existentes está bloqueada actualmente: el roster live V20 no registra `ImportSources` ni
   `ImportFromDocuments`, y `Invoke-TiaWorkflow.ps1 -Workflow apply` debe detenerse antes de mutar.
   Ejecutar solo el preview/gate; no llamar importadores directamente ni describir el preview como
   cambio aplicado. Reabrir la aplicación únicamente después de registrar un importador acotado,
   fail-closed y probado. Cuando esa ruta esté disponible, exigir fixture/manifiesto, backup y el
   resto del contrato de `AGENTS.md`.
2. Usar preview/dry-run si existe. Hacer un cambio pequeño, un bloque cada vez.
3. Compilar el PLC. Si hay errores o advertencias para la aceptación local, no guardar; corregir
   o restaurar. Si compila limpio, guardar y volver a leer fuente, interfaz, tags y estado del
   canal desde TIA.

### D. Probar por niveles, sin confundir evidencias

1. **Prueba AI en fixture:** alimentar el bloque con puntos sintéticos válidos:
    `RawMin`, 25 %, 50 %, 75 % y `RawMax`. Comparar con el cálculo independiente acordado y las
    unidades esperadas. Probar además `RawMin - 1` y `RawMax + 1`: se espera `QualityValid=false`
    y que `ValueEU` no se publique como medida válida (o se conserve el último valor con una marca
    obsoleta inequívoca, si esa es la política especificada). Probar `RawMax <= RawMin` y cada
    estado inválido previsto.
2. **Prueba AO, separada de AI:** aplicar consignas `EuMin`, 25 %, 50 %, 75 % y `EuMax` y
   comprobar el raw calculado contra la transformación inversa documentada. Probar permiso
   denegado, salida deshabilitada, consigna bajo/sobre límite, `EuMax <= EuMin`, canal defectuoso
   y estado de reposo/fallo. Confirmar saturación o rechazo según política; no accionar E/S física.
3. **PLCSIM:** si el modelo y herramienta están disponibles, ejecutar solo la lógica del PLC con
   entradas sintéticas del fixture. Esto verifica el cálculo/estados del programa; no valida
   módulo, cableado, calibración, resolución ni lazo de campo.
4. **Prueba eléctrica de FAT:** únicamente en banco aislado, por personal cualificado y con un
   calibrador/fuente de corriente o tensión adecuada al canal; registrar valores aplicados,
   raw observado, valor EU y diagnóstico. Probar mínimo, puntos intermedios, máximo y los
   estados de sub/sobrerango que el módulo permite. No provocar rotura de cable conectada a
   una máquina en marcha.
5. **SAT/operación:** solo según procedimiento de commissioning del sitio, con proceso y
   actuadores en estado seguro. Esta receta no autoriza forzar tags ni cambiar a RUN/STOP,
   descargar, calibrar ni modificar la configuración de un PLC físico.

## Verificación y evidencia

Guardar en el directorio de ejecución elegido bajo `70-runs/`:

- informe de preflight, versión TIA/CPU/módulo/firmware y ruta exacta del canal;
- referencia al manual de módulo, modo/rango seleccionado, unidad, raw min/max y EU min/max;
- para AI y AO por separado: algoritmo, límites, unidades, permiso, estado de fallo, resolución,
  tolerancia y tabla de puntos/casos esperados;
- exportación/inventario de tags, fuente SCL previa y posterior, propuesta, backup y resultado
  de compilación;
- tabla de casos con raw esperado/observado, unidades calculadas/observadas, calidad,
  diagnóstico, tolerancia y resultado;
- evidencia de simulador o instrumento con fecha y sistema de prueba, separada de la prueba
  PLCSIM;
- estado final de cualquier simulador y lista de valores forzados/modificados vacía.

| Evidencia | Qué permite afirmar |
|---|---|
| Revisión de fórmula + compilación limpia | El código se compila; no demuestra respuesta temporal ni hardware |
| Valores sintéticos en fixture/PLCSIM | El algoritmo y la máquina de estados responden a los casos ejecutados |
| Calibrador en canal aislado | La ruta del canal, escala y diagnosis responden a los puntos probados |
| Instrumento/loop en planta con commissioning aprobado | Solo los puntos y condiciones realmente medidos en esa instalación |

## Parar si

- falta referencia de módulo/canal o no hay forma de confirmar parámetros;
- rango, unidades, signo, raw representation o diagnosis son supuestos;
- la CPU/módulo o el bloque es F/Safety, está protegido o no se clasifica con certeza;
- el destino online no está demostrado como virtual y desechable;
- el circuito está unido al proceso, puede mover un actuador o el estado de la planta es incierto;
- el caso de prueba puede requerir forzar E/S, calibrar, descargar, alterar PG/PC o resetear;
- hay errores/avisos no aceptados, valores inesperados o estado de calidad contradictorio.

## Referencias Siemens

- [NORM_X V20](https://docs.tia.siemens.cloud/r/en-us/v20/scl-s7-1200-s7-1500/conversion-operations-s7-1200-s7-1500/norm_x-normalize-s7-1200-s7-1500)
- [SCALE_X y NORM_X, ejemplos de conversión analógica](https://docs.tia.siemens.cloud/r/simatic_s7_1200_manual_collection_eses_20/basic-instructions/conversion-operations/scale_x-scale-and-norm_x-normalize)
- [Representación de valores analógicos en S7-1200 G2 V20 — ejemplo específico, no universal](https://docs.tia.siemens.cloud/r/simatic_s7_1200_g2_manual_collection_enus_20/plc-concepts-configuration-and-programming/program-structure/processing-of-analog-values)
- [Rangos de entrada de corriente para módulos S7-1200 SB/SM V20 — ejemplo específico](https://docs.tia.siemens.cloud/r/simatic_s7_1200_manual_collection_enus_20/technical-specifications/analog-signal-modules-sms/measurement-ranges-of-the-analog-inputs-for-current-sb-and-sm)
- [Parámetros, smoothing y diagnosis de una entrada analógica ET 200eco PN](https://docs.tia.siemens.cloud/r/en-us/v20/editing-devices-and-networks/additional-information-on-configurations/distributed-i/o/et-200eco-pn/parameter-description-analog-input)
- [Módulo S7-1500 AI 8xU/I HF, MLFB 6ES7531-7NF00-0AB0, manual V20](https://docs.tia.siemens.cloud/r/simatic_s7_1500_et_200mp_manual_collection_enus_20/device-specific-information/analog-modules/analog-input-modules/analog-input-module-ai-8xu/i-hf-6es7531-7nf00-0ab0): parámetros de canal, representación raw, diagnósticos y códigos de medida para ese módulo. Úsalo como ejemplo; no extrapoles sus códigos a otro AI.
- [Módulo S7-1500 AQ 8xU/I HS, MLFB 6ES7532-5HF00-0AB0, manual V20](https://docs.tia.siemens.cloud/r/simatic_s7_1500_et_200mp_manual_collection_enus_20/device-specific-information/analog-modules/analog-output-modules/analog-output-module-aq-8xu/i-hs-6es7532-5hf00-0ab0): tipos de salida, rangos, valores raw y diagnósticos del AO concreto. No copiar raw límites/substitute values a otro modelo.
