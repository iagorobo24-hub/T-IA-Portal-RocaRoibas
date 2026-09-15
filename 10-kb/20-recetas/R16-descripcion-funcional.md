# R16 — Generar la descripción funcional

## Objetivo

Crear una primera descripción trazable de un proyecto a partir de evidencia MCP y fuentes
exportadas: PLCs, bloques, lenguajes, llamadas, cobertura, E/S y hallazgos.

## Precondiciones

- Un `analysis.json` generado por `Invoke-TiaProjectAnalysis.ps1` en modo `readOnly`.
- Opcionalmente, un `io-list.json` generado por R15.
- La descripción resultante se considera documentación de ingeniería, no una prueba de runtime.

## Secuencia

```powershell
.\30-tools\scripts\New-TiaFunctionalDescription.ps1 `
  -AnalysisPath ".\70-runs\...\analysis.json" `
  -IoListPath ".\70-runs\...\io-list.json" `
  -OutputPath ".\70-runs\documentation\functional-description.json" `
  -Objective "Descripción inicial del control"
```

## Verificación

Se generan JSON y Markdown con resumen, bloques, fuentes, referencias, E/S y hallazgos. El texto
declara explícitamente que no infiere secuencias ni comportamiento de runtime; cualquier aviso o
bloqueo del dossier se conserva.

## Si falta evidencia

Si no hay lista detallada de E/S, se documenta esa ausencia. Si el dossier es `readOnly=false`, el
script se detiene y no genera una descripción basada en una fuente no confiable.
