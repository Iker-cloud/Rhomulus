# Rendimiento en celular — plan B

Meta: 30 FPS estables en un celular de gama media. Este documento es el orden de pasos si no se llega.

## 1. Medir (hay que hacerlo en un celular real)
- En el juego: **AJUSTES (engranaje o tecla `O`) → RENDIMIENTO: VISIBLE**. Sale arriba a la izquierda: FPS, mínimo de los últimos 5 s, nivel de calidad, memoria e instancias.
- Medir en tres momentos: lobby, tramo 1 con la horda del generador, y la extracción (más zombies y luces).
- Referencia en Studio (PC, sin streaming): unas **61.700 instancias** con el mapa Morro Esperanza cargado y unos 1,7 GB de memoria.
- Si hace falta más detalle: consola del desarrollador (F9) en el celular, pestaña Rendimiento, o MicroProfiler.

## 2. Ya preparado en el código (solo del cliente, `client/Performance`, `Config.Performance`)
| Nivel | Alcance de faroles | Sombra de la linterna | Sombras globales |
| --- | --- | --- | --- |
| ALTA | 110 | sí | sí |
| MEDIA | 70 | no | sí |
| BAJA | 40 | no | no |

- En **AUTO** el celular arranca en MEDIA y baja un nivel si los FPS quedan por debajo de 24 durante 6 s (espera 15 s antes de bajar otra vez; nunca sube solo). En PC arranca en ALTA.
- El jugador puede fijar el nivel en AJUSTES → CALIDAD GRÁFICA.
- Los números se ajustan en `Config.Performance` (`Levels`, `TouchDefault`, `AutoDegrade`).

## 3. Si con BAJA todavía no llega (en este orden)
1. **Streaming del mapa** (se hace en Studio, no se puede por código: las propiedades son `Not Scriptable`): en el lugar de la partida (`Workspace`), `StreamingEnabled = true`, `StreamingTargetRadius = 320`, `StreamingMinRadius = 96`. Vale para todas las plataformas. Después de activarlo, probar: la guía de objetivo, los faroles, la furgoneta y que los zombies no aparezcan en el vacío (los animadores ya esperan a tener todas las piezas, pero hay que verlo).
2. **Zombie común ligero:** `Config.Zombie.Common.ModelDetail = "light"` (de 86 piezas a menos; el rápido ya es ligero). Es global: lo ven también los de PC.
3. **Menos zombies vivos en celular:** bajar `Config.Director.ByPlayers` (máximo de vivos). Es global.
4. **Menos decoración del mapa:** recortar piezas de detalle del pase de arte (basura, maleza, cables) en `MapBuilderBarrio`; son unas 500.

## 4. Qué NO se pudo comprobar
- Ninguna cifra de FPS de un celular real: el emulador de Studio corre en la GPU del PC y no sirve para medir.
- El efecto real de cada nivel en un celular (los valores de la tabla son una estimación).
