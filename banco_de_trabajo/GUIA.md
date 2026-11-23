# Banco de trabajo · juegos para Atari 8 bits

Lo que se usó para hacer **Vórtice 5** y sirve para el próximo título: herramientas,
el flujo de trabajo de principio a fin y las lecciones aprendidas por el camino.

## 1. Montar las herramientas (Linux, una vez)

| Herramienta | Para qué | Cómo |
|---|---|---|
| cc65 2.19 (ca65 + ld65) | Ensamblar y enlazar | `git clone https://github.com/cc65/cc65 && make -C cc65` → binarios en `cc65/bin` |
| atari800 (libatari800) | Emulador sin pantalla para pruebas automáticas | `git clone https://github.com/atari800/atari800 && cd atari800 && ./autogen.sh && ./configure --target=libatari800 --disable-netsio && make` |
| `run8` | El arnés de pruebas (este banco) | `gcc -O2 -I atari800/src/libatari800 -o run8 arnes/run8.c atari800/src/libatari800.a -lm` |
| Python 3 + Pillow + numpy | Gráficos, generadores, análisis | `pip install pillow numpy scipy` |
| Playwright + Chromium | Documentación HTML → PDF | `pip install playwright && playwright install chromium` |
| ffmpeg | Grabar la banda sonora a MP3 | paquete del sistema |

Para jugar de verdad: Altirra (Windows) o atari800 con pantalla.

## 2. El flujo de trabajo

```
gfx/*.py  ──►  tools/gen.py  ──►  src/data.s  ──►  ca65/ld65  ──►  main.bin
(dibujos en texto)  (charsets, mapas,   (generado)                     │
                     oleadas, jefes,                      mkxex.py ───┼──► .xex
                     música, textos)                      mkpack.py ──┴──► .atr + .car
```

1. **Dibujar en texto.** Sprites, tiles, escenarios y jefes son cuadrículas de caracteres
   en Python (`graficos/canvas.py` da rectángulos, elipses, trazos y espejo; `graficos/pal.py`
   convierte códigos de color $HL a RGB NTSC). La misma fuente sirve al juego y a los documentos.
2. **Generar los datos.** Un script convierte los dibujos en charsets de 1 KB, metatiles,
   mapas, tablas de enemigos, jefes partidos en dos juegos de caracteres y música en tablas.
   Comprueba los límites (128 caracteres por juego, sprites por franja…) y avisa si algo no cabe.
3. **Ensamblar.** `build.sh` regenera, ensambla, enlaza y empaqueta los tres formatos.
4. **Probar sin manos** con `run8` (sección 3).
5. **Medir** velocidad, sprites ocultos y duplicados (sección 4).
6. **Documentar** con los generadores de `documentacion/` (sección 5).

## 3. El arnés `run8`

Ejecuta un .xex/.atr/.car en atari800 sin pantalla siguiendo un guion de texto:

```
in  F0 F1 joy trig start   # entre los cuadros F0 y F1: joy (1 arriba, 2 abajo, 4 izq., 8 der.; se suman), fuego 0/1, START 0/1
shot F nombre.raw          # captura de pantalla en el cuadro F (384×240, códigos de color)
mem  F 0080 128 z.bin      # volcado de memoria (dirección en hex, longitud en decimal)
end  F                     # último cuadro
```

- `WAV=salida.raw run8 juego.xex guion` graba el sonido (PCM 16 bits, 44.100 Hz, mono).
- `shot.py` convierte capturas a PNG; `memq.py` lee variables por nombre con el fichero de etiquetas.
- Con una versión invulnerable (`-D CHEAT=1`) un bot recorre el juego entero en un minuto de reloj.

## 4. Medir

| Script | Qué da |
|---|---|
| `fullrun.py` | Guion de partida completa: elige dificultad, juega en zigzag con fuego y vuelca memoria cada N cuadros |
| `allstats.sh` + `stats.py` | Por tramo (fase/jefe y sector): velocidad (vueltas de lógica por cuadro), balas, balas/disparos/sprites que se quedan sin dibujar, duplicados |
| `nodprof.sh` + `prof.py` | Coste en ciclos de cada rutina, con sondas `PROF n` (VCOUNT + cuadro) y DMA apagado |

Una vuelta de lógica que pasa de un cuadro tarda dos: el juego va al 50 % en ese momento.
Lo que importa es que casi todas las vueltas quepan en un cuadro, no la media.

## 5. Documentar

- `render_assets.py`: sprites, tiles, cráteres y jefes desde los mismos `gfx/*.py`, más recortes de capturas reales.
- `build_atlas.py` (A4 apaisado) y `build_manual.py` (A5) escriben HTML; `make_pdf.py` lo pasa a PDF.
- `common.py` reúne los textos compartidos (créditos, historia, lema, datos de sectores).

## 6. Lecciones aprendidas (Vórtice 5)

**Pantalla y DLI**
- Tablas DLI de más de 256 bytes con índice Y dan la vuelta: una tabla por campo (32 bytes), rutinas A/B con direccionamiento absoluto.
- Con VSCROL = 7 la primera línea mide un scanline y su DLI llega dentro de la anterior: deja una línea en blanco tras el marcador y carga la línea 0 en la VBI.
- Pon el bit de DLI solo en la línea anterior a una línea que cambia algo, con una máscara de cambios por línea. Un barrido desenrollado de la máscara vale más que ordenar listas.
- Las escrituras de la DLI tras WSYNC pueden llegar 1-2 líneas tarde (línea con DMA de caracteres, muchos registros). No pongas un sprite o misil en las primeras líneas de su franja: apúntalo en la franja que empieza unas líneas antes (Vórtice 5: 3 para misiles, 2 para players). Se comprueba buscando en capturas formas partidas.
- CHBASE a mitad de pantalla: escríbelo en la DLI *antes* de WSYNC. ANTIC lo toma para la línea siguiente al terminar la actual; después de WSYNC llega una línea tarde (raya).
- Pantallas de texto con DLI de pantalla completa (un bucle con WSYNC por línea): en las líneas de texto, con mucha DMA, no hagas casi nada pero espera siempre a WSYNC. Para leer tablas desplazadas, usa operandos que se ajustan en la VBI (`lda tabla+desp,y`) con tablas duplicadas para no dar la vuelta. Dibuja en los players cuando el haz ya ha pasado.
- Al pasar del juego a las pantallas, deja solo la VBI hasta que el sistema haya cambiado la display list: si no, la DL del juego dispara la DLI de pantallas varias veces por cuadro y el sistema deja de hacer su VBI.
- Tope de objetos en pantalla al crear enemigos: cuando la vuelta no cabe en un cuadro el juego va a la mitad, así que es mejor espaciar las oleadas que dejar que coincidan.
- Doble búfer: dos display lists y dos juegos de tablas; la lógica prepara el cuadro siguiente y la VBI solo cambia punteros.
- La PMG de resolución de una línea deja libre $B000–$B2FF: buen sitio para tablas de trabajo.

**Sprites**
- Multiplexar P2/P3 por franjas y los 4 misiles como un solo recurso compartido entre disparos y balas.
- **Turnos**: lo que no cupo en un cuadro va primero en el siguiente. Así nada queda invisible dos cuadros seguidos; como mucho parpadea.
- Un sprite que no cambió (posición, gráfico, player) no se borra ni se repinta. Que cada objeto conserve su player.
- Recorre los objetos en el orden en que suelen estar ya (el reparto de huecos lo marca): la ordenación por inserción sale casi gratis.

**Rendimiento**
- VBI inmediata propia en juego (copiar sombras a mano) en vez de pasar por el SO.
- No toques los LMS si el scroll no se movió; cachea lo que solo cambia con el scroll.
- Colisiones contra listas compactas de lo que está vivo y en pantalla.
- Si un tramo sigue lento, a veces la solución es de diseño: espaciar las oleadas.

**Sonido**
- Lo que corre en la VBI necesita sus propios temporales de página cero.
- Nunca cortes en seco: bucles que cierran en el acorde que lleva al principio y fundido en cada cambio de pista.
- AUDCTL $78 (dos voces de 16 bits) para pantallas; $28 en juego (bajo de 16 bits, melodía de 8, efectos en su canal).

**Juego justo**
- Ninguna bala nace dentro de una zona alrededor de la nave; tope de balas según la dificultad.
- Una bala nueva no nace encima de otra igual; un enemigo que devuelve disparos, con enfriamiento.

**Formatos**
- ATR autoarrancable sin DOS: tope de 255 sectores (~32 KB); vigílalo.
- Cartucho AtariMax 128 KB: el banco 0 copia los demás a RAM y desconecta el cartucho.
- Desconecta el BASIC de los XL/XE (PORTB) si usas $A000–$BFFF.

## 7. Lista para el próximo título

1. Copia `plantilla/` (build.sh, vortice5.cfg, cart.s) y los empaquetadores.
2. Define paleta y reglas del hardware antes de dibujar (cuántos colores, sprites por franja, tamaño de jefes).
3. Dibuja en `gfx/` con `canvas.py`; haz que el generador compruebe los límites.
4. Haz una versión con `CHEAT` y `PROF` desde el primer día; mide en cada cambio grande.
5. Prueba los tres formatos al final de cada ronda.
