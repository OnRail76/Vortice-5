# Análisis de MP3 para adaptar música a POKEY

Necesitan numpy y scipy. Convierte antes el MP3 a WAV mono (`ffmpeg -i tema.mp3 -ac 1 tema.wav`).

- `ana.py tema` — tempo (BPM) y candidatos.
- `tr.py` — saliencia de notas por armónicos (base del resto).
- `mel.py tema inicio paso cuantos por_linea` — melodía y bajo nota a nota.
- `chords.py` — acordes por croma.

Con el tempo, la melodía y el bajo se escriben las tablas de canciones del generador
(pares nota, cuadros) como en `codigo_fuente/tools/gen.py`.

## Grabar la banda sonora del juego

`ost.sh` (cópialo en `tools/` del proyecto) compila una versión con `-D NOSFX` (sin efectos), graba título, fase, jefe y GAME OVER con `run8` y los pasa a MP3 normalizados (ffmpeg). Ojo: el recorte con `-ss` va antes de `-i`; si va detrás, los fundidos usan el tiempo original y la pista sale en silencio.
