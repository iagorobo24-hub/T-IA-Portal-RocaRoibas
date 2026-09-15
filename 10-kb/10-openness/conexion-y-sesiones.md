# Conexión, sesiones y el ciclo de vida de TIA Portal

> Todo lo de este documento está ✅ **verificado en esta máquina el 2026-09-14**, midiendo
> tiempos reales y contando procesos. No es documentación copiada.

## Lo que hay que saber antes de nada

| Hecho | Medido |
|---|---|
| `Connect` **en frío** (no hay TIA corriendo) | **27,7 s** — arranca una instancia headless |
| `Connect` **en caliente** (ya hay instancia) | **0,3 s** — se reengancha a la existente |
| `Disconnect` | **No cierra TIA Portal.** El proceso sobrevive |
| Instancia headless en reposo | ~**1,3 GB** de RAM |

🔴 **Las dos consecuencias prácticas:**

1. **Mantener una instancia caliente hace todo ~90 veces más rápido.** Merece la pena
   deliberadamente.
2. **Si no cierras nunca, se acumulan instancias de 1,3 GB.** Hay que limpiar a propósito.

---

## El ciclo correcto

```
Doctor                 ← ¿entorno sano? Si no, para aquí
Connect  /  Attach     ← ver abajo cuál
OpenProject
  ... trabajo ...
SaveProject            ← o SaveSession si hay Multiuser
CloseProject
Disconnect             ← suelta la conexión, NO cierra TIA
```

### `Connect` frente a `Attach`

| Situación | Qué usar |
|---|---|
| No hay TIA corriendo | `Connect` — arranca una instancia headless |
| Hay una instancia headless de una sesión anterior | `Connect` — se reengancha, 0,3 s ✅ *verificado* |
| El usuario tiene TIA **abierto con interfaz** y un proyecto dentro | `Attach` solo si el servidor lo expone; en `tia-inspect` actual no existe 🔒 |

🔒 **Nunca abras una segunda instancia sobre un proyecto que el usuario tiene abierto.**
Dos procesos escribiendo el mismo `.ap20` es una forma excelente de perder trabajo. Está en
`AGENTS.md` §2.

### Hallazgo verificado: `Connect` no es `Attach`

El roster real de `tia-inspect` V20 contiene `Connect`, pero no contiene una herramienta
`Attach`. En una prueba con TIA visible, `Connect` respondió correctamente y la siguiente
`GetProjectTree` devolvió `Failed retrieving project tree`: la conexión no tenía proyecto.
Por tanto, un agente no puede inferir que ha seleccionado la ventana visible solo porque
`Connect` haya terminado sin error.

La regla operativa es: si hay una ventana visible y el proyecto objetivo no está confirmado,
parar. La identificación debe hacerla una interfaz gráfica disponible o el usuario; después se
repite la secuencia de lectura sobre el proyecto correcto.

---

## La fuga de procesos

✅ **Verificado.** Secuencia real:

```
Connect       → arranca Siemens.Automation.Portal (PID 14480), 27,7 s
GetState      → isConnected: true
Disconnect    → ok
                ↓
PID 14480 SIGUE VIVO, 1,3 GB
```

Ni `Disconnect` ni el fin del proceso del servidor MCP cierran TIA. La instancia se queda.

📄 La API de Openness sí tiene una operación para cerrar TIA
(`ExitAndCloseTiaPortal` en los snippets de Siemens), pero **`tia-inspect` no la expone**:
no está entre sus 59 herramientas. Así que desde el MCP no hay forma.

### Cómo limpiar

```powershell
30-tools\scripts\Stop-TiaPortal.ps1
```

Antes de matar nada consulta por MCP si hay un proyecto abierto, y se niega si lo hay salvo que
pases `-Force`. Intenta cierre limpio (`CloseMainWindow`) antes de forzar.

### Estrategia recomendada

**Una instancia caliente durante la sesión de trabajo, cerrarla al terminar.**

```
mañana:    primer Connect          28 s (peaje que se paga una vez)
           resto del día           0,3 s por conexión
final:     Stop-TiaPortal.ps1
```

No cierres TIA entre tarea y tarea: estarías pagando 28 s cada vez para ahorrar RAM que
probablemente te sobra.

---

## Estado del servidor

`GetState` devuelve lo que importa:

```json
{ "isConnected": true, "project": "-", "session": "-", "allowWrite": false }
```

| Campo | Qué mirar |
|---|---|
| `isConnected` | Si es `false`, cualquier otra llamada dará `InvalidState` |
| `project` | `-` significa que no hay proyecto abierto |
| `session` | Distinto de `-` → hay **sesión local de Multiuser** → guardar con `SaveSession`, no `SaveProject` 🔒 |
| `allowWrite` | Si es `false`, las 40 herramientas de escritura **ni existen** |

---

## Guardar: `SaveProject` o `SaveSession`

📄 Las operaciones de escritura cambian el proyecto **solo en memoria**. Si no persistes, se
pierden.

| Caso | Herramienta |
|---|---|
| Proyecto normal | `SaveProject` |
| Sesión local de Multiuser abierta | **`SaveSession`** |

Cada respuesta de escritura de `tia-inspect` dice explícitamente cuál toca. Léela.

---

## Modo escritura

✅ **Verificado:** arrancado sin `--allow-write`, `tools/list` devuelve exactamente **59
herramientas**, todas de lectura. Las 40 de escritura **no se registran**: no aparecen en la
lista y el modelo no puede llamar a lo que no ve.

Para escribir hay que relanzar el servidor con la bandera. Con ella, las herramientas destructivas
vienen anotadas `destructiveHint: true` para que el cliente pueda pedir confirmación.

🔒 El `.mcp.json` de este workspace registra `tia-inspect` **en solo lectura**. Es deliberado:
ver [ADR-006](../../00-meta/decisiones/ADR-006-limites-seguridad.md).

Para una sesión de escritura puntual desde la consola:

```powershell
30-tools\scripts\Invoke-TiaMcp.ps1 -AllowWrite -Calls @( ... )
```

---

## Protocolo MCP

✅ Verificado en el handshake real:

| | |
|---|---|
| Servidor | `TiaMcpServer v0.1.0.0` |
| Protocolo negociado | `2025-06-18` |
| Transporte | stdio, JSON-RPC delimitado por líneas |
| Herramientas (solo lectura) | **59** |

⚠️ **En stdio, los logs van a stderr.** Escribir en stdout corrompería el JSON-RPC. Si arrancas
el servidor con `--logging 1`, esa salida es stderr y no interfiere.
