# HMI y simulación

HMI no es una sola tecnología en TIA Portal. Antes de tocar una pantalla hay que identificar
la familia del dispositivo y el runtime que la ejecutará:

- **WinCC Unified**: paneles Unified y WinCC Unified PC Runtime.
- **WinCC Comfort/Advanced**: paneles Comfort/Basic y Runtime Advanced clásico.
- **Runtime Advanced**: ejecuta el proyecto de WinCC Advanced en Windows; no convierte un
  dispositivo Unified en un dispositivo compatible.

La versión del runtime debe ser compatible con la versión del dispositivo/proyecto. La
compilación del PLC no demuestra que una HMI pueda ejecutarse. La receta correspondiente debe
registrar dispositivo, versión, licencia, conexiones y resultado de arranque.

En esta máquina el dato verificado es: TIA Portal V20 está instalado y el ejecutable encontrado
es WinCC Runtime Advanced V17.0 HF8. Por eso el proyecto HMI V20 de los juegos no se considera
simulable hasta instalar/verificar un runtime compatible; la prueba anterior terminó con
“The device is not supported and cannot be compiled”.

Referencias: [matriz de versiones](runtime-version-matrix.md), [Comfort/Advanced](comfort-advanced.md)
y [Unified](unified.md).
