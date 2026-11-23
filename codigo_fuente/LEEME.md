# VÓRTICE 5 · Corazón de Acero

Shoot 'em up vertical original para Atari 400/800/XL/XE (48 KB, NTSC).
2026 Tony C. Ware

## Jugar

| Fichero | Uso |
|---|---|
| `bin/vortice5.xex` | Ejecutable para emulador o cargador de XEX (Altirra, atari800, SIO2SD…) |
| `bin/vortice5.atr` | Disco autoarrancable sin DOS (arranca solo al encender) |
| `bin/vortice5.car` | Cartucho AtariMax 128 KB (tipo 41) |

- Joystick en el puerto 1. FIRE dispara (manteniéndolo, dispara solo). START también vale para empezar.
- En el título, joystick izquierda/derecha o SELECT eligen la dificultad:
  - **Fácil**: 5 vidas, balas más lentas, disparan menos y nunca nacen cerca de la nave.
  - **Normal**: 3 vidas.
  - **Hardcore**: 2 vidas, balas más rápidas y más disparos; el margen de seguridad es menor.
  - Balas enemigas a la vez como mucho: 5 (Fácil), 6 (Normal), 8 (Hardcore).
- Pensado para NTSC (60 Hz). En PAL funciona, pero un 17 % más lento.
- Vida extra a los 20.000 puntos y luego cada 50.000.
- Cápsula **P**: sube el disparo. Nivel I: un disparo. II: dos en paralelo. III: dos con más cadencia. Al morir vuelves a I. Con nivel III, la cápsula da 1.000 puntos.
- El disparo daña tanto a lo que vuela como a lo que hay en el suelo, como en Star Force.

- **Truco**: en el título, arriba, arriba, abajo, abajo, izquierda, derecha y FIRE. Suena un BEEP y la nave es invencible. Dura entre partidas (también tras un GAME OVER) hasta que se termina el juego; entonces hay que volver a meterlo.
- La pantalla de victoria se queda al menos 4 segundos y vuelve al título tras dos pulsaciones de FIRE.

## Las cinco fases

| Sector | Aire | Suelo | Jefe |
|---|---|---|---|
| 1 Cementerio de Titanes | Aguja, Carroñero | Centinela, Contenedor (da P) | GARRA-9 |
| 2 Arrecife de Ácido | Zángano, Lapa | Pólipo (solo vulnerable abierto), Bolsa ácida (cruz) | MADRE PÓLIPO |
| 3 Fundición Orbital | Aguja térmica, Cazador delta (sube desde abajo) | Centinela térmico, Surtidor | HORNO OMEGA |
| 4 Santuario Prisma | Orbe espejo (devuelve el disparo), Zángano prisma | Centinela prisma, Emisor láser | EL PRISMARCA |
| 5 Corazón de Acero | Destructor (doble ancho), Mina nerviosa (cruz) | Centinela parásito, Bomba biológica | LEVIATÁN V |

Cada jefe tiene 3 a 5 puntos débiles. El núcleo solo se puede dañar cuando caen los demás. Al acertar, el color de los puntos débiles parpadea en blanco.

## Compilar

Hace falta Python 3 con Pillow y cc65 (ca65/ld65).

```
CC65=/ruta/a/cc65/bin ./build.sh
```

`build.sh` regenera `src/data.s` desde los dibujos (`gfx/`), ensambla y enlaza el juego y crea `build/vortice5.xex`, `.atr` y `.car`.

## Estructura

```
src/game.s      arranque, VBI, DLI, display lists, bucle de partida, inicio de sector
src/engine.s    lógica por cuadro, scroll y anillo, decodificación del mapa, multiplexor, dibujo PMG, marcador
src/objects.s   oleadas, movimientos, balas, objetivos de suelo, colisiones, puntuación
src/boss.s      llegada, combate y destrucción de los jefes
src/screens.s   título, GAME OVER, victoria
src/sound.s     POKEY: pistas con fundido (título, fases, dron de jefe, GAME OVER) y efectos
src/data.s      GENERADO por tools/gen.py (no tocar a mano)
src/cart.s      cargador del cartucho (banco 0)
gfx/*.py        los dibujos: sprites, tiles, escenarios y jefes (la misma fuente que el atlas)
tools/gen.py    convierte los dibujos en charsets, metatiles, mapas, oleadas, jefes, textos y el dron
tools/drone_cycle.txt  contorno de tono del dron (Hz por cuadro), sacado del MP3 de ambiente de referencia
tools/mkxex.py  empaqueta el XEX
tools/mkpack.py crea el ATR autoarrancable y el CAR AtariMax
tools/run8.c    arnés de pruebas sobre libatari800: guion de joystick, capturas y volcados de memoria
tools/shot.py   convierte capturas crudas a PNG
tools/memq.py   lee variables de un volcado usando las etiquetas del enlazador
tools/cheat.sh  compila una versión invulnerable solo para recorrer el juego en pruebas
tools/allstats.sh  partida completa en las tres dificultades: velocidad, balas/sprites ocultos, duplicados
tools/nodprof.sh   perfil de CPU por rutina (sin DMA)
tools/stats.py, prof.py, fullrun.py  análisis de esas partidas
```

## Decisiones técnicas

- **Pantalla**: ANTIC 4, playfield estrecho de 32 columnas (128 × 192), marcador ANTIC 2 arriba, una línea en blanco de separación.
- **Scroll**: vertical fino con VSCROL y grueso moviendo los LMS. La pantalla es un anillo de 32 filas; cada paso solo decodifica una fila nueva. Media línea por cuadro.
- **Mapas**: 150 filas de metatiles 16 × 16 (4 × 2 caracteres) por sector. Un charset por sector (54 a 71 caracteres de 128).
- **Sprites**: la nave es P0 + P1 superpuestos (multicolor, el tercer color es el OR de los dos). Los enemigos usan P2 y P3 reutilizados por bandas con DLI, hasta 8 en pantalla. Cada línea de la display list tiene una máscara de cambios y la DLI solo toca lo que cambia.
- **Disparos y balas**: modo quinto player; todos los misiles salen en COLPF3 ($1E). Disparos propios y balas enemigas van en una sola lista ordenada por altura y cada uno usa cualquiera de los 4 misiles libre en su franja.
- **Turnos**: si en una franja hay más sprites o balas de los que caben, lo que se quedó sin dibujar en un cuadro va primero en el siguiente. Nada queda invisible dos cuadros seguidos: como mucho parpadea.
- **Sin cortes en diagonal**: la DLI escribe los registros con la línea ya empezada y, si hay muchos cambios, llegan 1 o 2 líneas tarde. Un misil o un enemigo que empezara justo ahí salía partido (la primera línea en la posición vieja), muy visible al moverse en diagonal. Ahora cada misil se apunta en la franja que empieza al menos 3 líneas antes y cada enemigo al menos 2: cuando se dibuja, sus registros ya están puestos.
- **Sin raya en los jefes**: los jefes partidos en dos juegos de caracteres cambian CHBASE a mitad. ANTIC toma CHBASE para la línea siguiente al acabar la actual, así que la DLI lo escribe antes de WSYNC; si se escribía después, la primera línea de la segunda mitad salía con los caracteres de la otra (una raya horizontal). El Horno Omega usa un solo juego y no la tenía.
- **Sin cámara lenta**: una oleada no saca enemigos nuevos si ya hay 5 objetos en pantalla (4 en los sectores 4 y 5). Con 7-8 a la vez el cuadro no cabía en 1/60 s y el juego iba a la mitad. Las oleadas salen todas, solo algo más espaciadas.
- **Mapas como diccionario**: cada sector guarda sus filas distintas (unas 40) y la lista de índices; ahorra unos 3,5 KB.
- **Pantallas de texto**: un núcleo de DLI recorre la pantalla línea a línea: estrellas en tres capas con los misiles (quinto player, posiciones leídas con operandos que se ajustan en cada VBI), degradado cromado en el logotipo y nada en las líneas de texto, que van justas de DMA. En el título, un radar en P0..P3 con barrido, estela y ecos; se redibuja cuando el haz ya ha pasado.
- **Sin duplicados**: una bala nueva no nace encima de otra igual (dos fuentes disparando a la vez hacia la nave), y el orbe espejo devuelve como mucho un disparo cada 40 cuadros.
- **Doble búfer**: dos display lists y dos juegos de tablas DLI. La lógica prepara el cuadro siguiente y la VBI solo cambia punteros. Los sprites se dibujan justo después de la VBI, antes de que el haz llegue a la zona de juego.
- **Jefes**: tiles de 112 × 56 con sus propios juegos de caracteres; una DLI cambia CHBASE donde hace falta. El jefe entra con el scroll y el scroll se para.
- **Memoria**: código y datos en $2000-$9FFF. En ejecución se usa $A000-$BFFF (charsets de trabajo, anillo, PMG, display lists), por eso el juego desactiva el BASIC de los XL/XE al arrancar. Algunas tablas de trabajo viven en $B000-$B2FF, el hueco que la PMG de una línea no usa.
- **Música** (canciones de Tony, adaptadas a POKEY):
  - Título: "titulo", bucle de 12 compases (~20 s, ~141 ppm, Re menor) a dos voces de 16 bits.
  - Fases: "Heart of Steel", bucle de 32 compases (~53 s, ~146 ppm, Re menor). Bajo de 16 bits en los canales 3+4, melodía de 8 bits en el canal 2; los efectos van todos al canal 1.
  - Jefes: el dron arcade (barrido de tono sacado del MP3 de ambiente), en los canales 3+4.
  - GAME OVER: una vez, acaba apagándose.
  - Nunca hay cortes en seco: los bucles cierran en el acorde que lleva al principio y todo cambio de pista funde la que suena (~0,8 s) y la nueva entra con fundido.
- **Modo atracción**: ATRACT se pone a 0 en cada VBI.

- **Balas justas**: ninguna bala enemiga puede nacer dentro de una zona alrededor de la nave (60, 44 o 30 de margen según la dificultad).
- **Cráteres**: los objetivos cuadrados dejan un cráter con su placa; los redondos dejan un cráter redondo, sobre el fondo si estaban en el vacío o sobre el suelo del sector si estaban encima de él.

## Aventuras y lecciones

- **Tabla DLI de 400 bytes con índice Y**: las tablas entrelazadas de 16 bytes por línea pasaban de 256 bytes y el índice daba la vuelta. Los valores de la línea 18 aparecían en la 2. Solución: una tabla por campo (32 bytes cada una) y rutinas DLI A/B con direccionamiento absoluto.
- **DLI anidada**: con VSCROL = 7, la primera línea de juego mide un solo scanline y su DLI llegaba mientras la DLI del marcador aún trabajaba. Todo quedaba desplazado una banda. Solución: la DLI del marcador cambia el vector lo primero, los valores de la línea 0 se cargan en la VBI y hay una línea en blanco de margen.
- **Ordenación por inserción**: el `sta mx_ord+1,y` con Y = $FF escribía fuera de la tabla. Los enemigos quedaban sin ordenar y el multiplexor descartaba la mitad.
- **Rendimiento**: con relleno completo de las tablas el juego iba a medio ritmo. Las máscaras de cambio por línea lo dejaron a 60 Hz en los sectores 1-3.
- **Afinado final** (medido en partidas completas en las tres dificultades, con `tools/allstats.sh` y `tools/nodprof.sh`):
  - VBI inmediata propia en juego (sin pasar por el SO), LMS solo cuando cambia el scroll, CHBASE del jefe en caché.
  - Bits de DLI: un barrido desenrollado de la máscara pone el bit y la lista de líneas de una vez (antes: lista, ordenación y dos pasadas).
  - Punteros de las tablas y limpieza de la máscara desenrollados.
  - Un sprite que no ha cambiado (misma posición, mismo gráfico, mismo player) ni se borra ni se vuelve a pintar; cada objeto conserva su player.
  - Colisiones con cajas precalculadas en lista compacta y lista de objetivos de suelo en pantalla.
  - Disparos en anillo (ya salen ordenados), ordenación parcial, misiles desenrollados.
  - Sector 5: oleadas algo más espaciadas.
  - Velocidad media (Normal): sectores 1-3 entre el 90 y el 100 %, sector 4 ~90 %, sector 5 ~87 %; jefes del 90 al 100 %. En Hardcore, con 8 balas, los últimos jefes bajan a ~80 %.
- **Bandera de GAME OVER**: un `sta gover` heredaba A = 1 y la partida terminaba nada más empezar.
- El arnés `run8` (atari800 sin pantalla) permite jugar con guiones de joystick, sacar capturas y leer variables por nombre. Con la versión invulnerable se recorren los cinco sectores en unos segundos de reloj.

- **Temporales de la VBI**: el reproductor de música (en la VBI) usaba los mismos temporales de página cero que el programa y podía pisarlos en mitad de un cálculo. Ahora tiene los suyos propios.

## Pendiente o posible

- Versión PAL con temporizadores ajustados.
- Más variedad de oleadas y movimientos de jefe (ahora están fijos arriba).
- Pausa.
