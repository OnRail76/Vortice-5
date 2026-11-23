#!/bin/sh
# Graba la banda sonora del propio juego (emulador) sin efectos de sonido: versión -D NOSFX
# salida en banda_sonora/: título, fase (Heart of Steel), dron de jefe y GAME OVER
cd "$(dirname "$0")/.."
C=${CC65:-/home/claude/tools/cc65/bin}; O=banda_sonora; mkdir -p $O build
for v in "ostc -D CHEAT=1" "ostn"; do set -- $v; n=$1; shift
  $C/ca65 -D NOSFX=1 "$@" -I src -o build/$n.o src/game.s && $C/ld65 -C src/vortice5.cfg -o build/dummy build/$n.o && python3 tools/mkxex.py build/$n.xex >/dev/null; done
printf 'in 0 2000 0 0 0\nend 1950\n' > $O/t.txt
python3 tools/fullrun.py 1 8300 100000 0 1 | grep -v '^mem' > $O/p.txt
printf 'in 0 9000 0 0 0\nin 100 104 8 0 0\nin 200 204 0 1 0\nend 2500\n' > $O/g.txt
(cd $O && WAV=t.raw ../tools/run8 ../build/ostn.xex t.txt && WAV=p.raw ../tools/run8 ../build/ostc.xex p.txt && WAV=g.raw ../tools/run8 ../build/ostn.xex g.txt) >/dev/null 2>&1
F="-f s16le -ar 44100 -ac 1"; N="highpass=f=18,loudnorm=I=-14:TP=-1.5:LRA=11"
cd $O
ffmpeg -loglevel error -y $F -ss 0.5 -t 31 -i t.raw -af "$N,afade=t=out:st=28:d=3" -ar 44100 -b:a 192k 01_titulo.mp3
ffmpeg -loglevel error -y $F -ss 3.5 -t 62 -i p.raw -af "$N,afade=t=out:st=58:d=4" -ar 44100 -b:a 192k 02_heart_of_steel_fase.mp3
ffmpeg -loglevel error -y $F -ss 86 -t 45 -i p.raw -af "$N,afade=t=in:d=1,afade=t=out:st=41:d=4" -ar 44100 -b:a 192k 03_dron_jefe.mp3
ffmpeg -loglevel error -y $F -ss 13.1 -t 10.4 -i g.raw -af "$N" -ar 44100 -b:a 192k 04_game_over.mp3
rm -f *.raw *.txt
