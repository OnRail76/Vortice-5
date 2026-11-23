#!/usr/bin/env python3
"""Vórtice 5 — generador de datos (charsets, mapas, oleadas, sprites, jefes, música) -> src/data.s (ca65)."""
import sys, os, random, unicodedata
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'gfx'))
from canvas import C
from sprites import SHIP, SHIP_COLORS, ENEMIES, COMMON
from tiles import T, SECTORS, PF3
from scenery import SETS
from bosses import BOSS_DEF

OUT = []
def A(s=''): OUT.append(s)
def rows(s): return [r for r in s.strip('\n').split('\n')]
def bytes_line(bs, per=16):
    for i in range(0, len(bs), per):
        A('    .byte ' + ','.join('$%02X' % b for b in bs[i:i+per]))
def bits(row, on): return int(''.join('1' if ch in on else '0' for ch in row.ljust(8, '.')[:8]), 2)
BLANK = tuple(tuple('....') for _ in range(8))
def chars_of(c):
    return [[tuple(tuple(c.p[y][x] for x in range(cx, cx+4)) for y in range(cy, cy+8))
             for cx in range(0, c.w, 4)] for cy in range(0, c.h, 8)]
def charbytes(ch):
    v = {'.': 0, '1': 1, '2': 2, '3': 3}
    return [(v[r[0]] << 6) | (v[r[1]] << 4) | (v[r[2]] << 2) | v[r[3]] for r in ch]

# ------------------------------------------------------------------ cabecera
A('; ==========================================================')
A('; VORTICE 5 - datos generados por tools/gen.py  (no editar a mano)')
A('; Diseño, nombres, fases, gráficos y música por Tony C. Ware, adaptados con asistencia IA · 2026 Tony C. Ware')
A('; ==========================================================')

# ------------------------------------------------------------------ paletas de sector
A('\n; ---- paletas: COLBK, PF0, PF1, PF2 por sector')
for k in ('BG', 'PF0', 'PF1', 'PF2'):
    A('sec_%s: .byte %s' % (k.lower(), ','.join('$%02X' % S[k] for S in SECTORS)))
A('PF3_COLOR = $%02X' % PF3)
A('SHIP_C0 = $%02X' % SHIP_COLORS['P0'])
A('SHIP_C1 = $%02X' % SHIP_COLORS['P1'])

# ------------------------------------------------------------------ objetivos de suelo
# tipos: 1 torreta apuntada, 2 contenedor (da P), 3 polipo (alterna, vulnerable abierto),
#        4 bolsa acida (cruz al morir), 5 surtidor (alterna, rafaga abajo activo),
#        6 emisor laser (rafaga abajo), 7 bomba bio (cruz + P)
TGT = {1: {'T': 1, 'C': 2}, 2: {'T': 3, 'O': 3, 'A': 4}, 3: {'T': 1, 'S': 5, 'Z': 5},
       4: {'T': 1, 'E': 6}, 5: {'T': 1, 'B': 7}}
ALT = {2: {'T': 'O', 'O': 'T'}, 3: {'S': 'Z', 'Z': 'S'}}   # metatile alterno
#            hp, score(BCD centenas), flags  bit0=apunta bit1=rafaga abajo bit2=cruz al morir bit3=da P bit4=solo vulnerable en estado "abierto"
TTYPE = {1: (2, 0x03, 0x01), 2: (3, 0x05, 0x08), 3: (3, 0x05, 0x11), 4: (2, 0x03, 0x04),
         5: (3, 0x05, 0x02), 6: (3, 0x05, 0x02), 7: (8, 0x20, 0x0C)}
A('\n; ---- tipos de objetivo de suelo: hp, puntos (BCD centenas), flags')
A('tt_hp:    .byte 0,' + ','.join(str(TTYPE[i][0]) for i in range(1, 8)))
A('tt_score: .byte 0,' + ','.join('$%02X' % TTYPE[i][1] for i in range(1, 8)))
A('tt_flags: .byte 0,' + ','.join('$%02X' % TTYPE[i][2] for i in range(1, 8)))

# ------------------------------------------------------------------ charsets + metatiles por sector
charset_report = []
for S in SECTORS:
    n = S['n']; meta = SETS[n]['meta']; keys = list(meta.keys())
    cs = [BLANK]; idx = {BLANK: 0}; mts = []
    for k in keys:
        ids = []
        for row in chars_of(meta[k]):
            for ch in row:
                if ch not in idx: idx[ch] = len(cs); cs.append(ch)
                ids.append(idx[ch])
        mts.append(ids)
    charset_report.append(len(cs))
    A('\n; ==== SECTOR %d: %s (%d caracteres)' % (n, S['name'], len(cs)))
    A('s%d_chars = %d' % (n, len(cs)))
    A('s%d_charset:' % n)
    bytes_line([b for ch in cs for b in charbytes(ch)])
    A('s%d_mt: ; %d metatiles x 8 (fila sup 4, fila inf 4)' % (n, len(keys)))
    for k, ids in zip(keys, mts):
        A('    .byte ' + ','.join(str(i) for i in ids) + '   ; "%s"' % k)
    tt = [TGT[n].get(k, 0) for k in keys]
    alt = [keys.index(ALT.get(n, {}).get(k, k)) for k in keys]
    A('s%d_mt_tgt: .byte %s' % (n, ','.join(str(x) for x in tt)))
    A('s%d_mt_alt: .byte %s' % (n, ','.join(str(x) for x in alt)))
    A('s%d_crater = %d' % (n, keys.index('K')))
    # cráter: cuadrado (placas), redondo sobre el fondo, o redondo sobre el suelo del sector
    CR = {2: {'T': 'k', 'O': 'k', 'A': 'k'}, 4: {'T': 'q', 'E': 'k'}, 5: {'T': 'q', 'B': 'k'}}.get(n, {})
    crat = [keys.index(CR.get(k, 'K')) for k in keys]
    A('s%d_mt_crat: .byte %s' % (n, ','.join(str(x) for x in crat)))
    # estado "abierto" (vulnerable) para objetivos que alternan
    openk = {2: 'O', 3: 'Z'}.get(n)
    A('s%d_open = %d' % (n, keys.index(openk) if openk else 255))
    SETS[n]['keys'] = keys

# ------------------------------------------------------------------ mapas
MAPLEN = 150
random.seed(5)
TEMPL = {
 1: [['   LPJ  ', '  LPRPJ ', ' LPVPPRJ', '  LPPPJ ', '   LRJ  '],
     ['LPJ     ', 'LRPJ    ', 'LPPJ  LP', 'LJ   LPR', '     LPP', '      LP'],
     ['  GGGG  '], ['        ', '   s    ', '       s', ' s      '],
     [' LPRPPJ ', 'LPPVPRPJ', 'LRPPPPPJ', ' LPPRPJ '], ['PJ    LP', 'RPJ  LPR', 'PJ    LP']],
 2: [['CJ    LC', 'CDJ  LDC', 'CJ  m LC', 'DCJ   LD'], ['CCJ  LCC', 'CJ    LD', 'DJ    LC'],
     ['CJ LJ LC', 'DJ LJ LD', 'CJ LJ LC'], ['CDCJ  LC', 'CDJ   LD', 'CJ    LC'],
     ['CJ   LDC', 'DJ  LCDC', 'CJ   LDC'], ['CJ mm LC', 'DJ    LD']],
 3: [['PPJ  LPP', 'PFJ  LFP'], ['BBBBBBBB'], ['PJ    LP', 'PPJ  LPP', 'PJ    LP'],
     ['bbbbbbbb'], ['PFP  PFP', 'PPJ  LPP'], ['PJ LJ LP', 'PJ    LP']],
 4: [['   LXJ  ', '  LXYXJ ', ' LXYYXJ ', '  LXYJ  '], ['        ', '  s     ', '     s  '],
     ['LXJ     ', 'LXYJ    ', 'LXJ  LXY', '     LYX'], ['  LYXJ  ', ' LXYXXJ ', 'LXYXYXYJ', '  LXJ   ']],
 5: [['FGJ  LFG', 'FJ    LF', 'GMJ  LMG'], ['FJ    LF', 'GJ    LG'], ['GFMJ LMF', 'FJ    LG'],
     ['FFJ  LGF', 'GJ    LF', 'MJ    LM'], ['FJ LJ LF', 'GJ    LG']],
}
FLOOR = {1: ('PR', 'TTTC'), 2: (' ', 'TTA'), 3: ('P', 'TTS'), 4: ('XY', 'TT'), 5: ('FG', 'T'), }
OPEN = {2: (' ', 'TA'), 4: (' ', 'E'), 5: (' ', 'B')}
def gen_map(n):
    rows_ = []
    T_ = TEMPL[n]
    rows_ += [T_[0][0]] * 2
    while len(rows_) < MAPLEN - 14:
        b = random.choice(T_)
        rows_ += b
    for r in rows_: assert len(r) == 8, (n, r)
    rows_ = rows_[:MAPLEN - 14]
    # objetivos
    last = -3
    for i in range(14, len(rows_)):
        if i - last < 3: continue
        r = list(rows_[i]); put = False
        if random.random() < 0.55:
            fl, choices = FLOOR[n]
            cand = [x for x in range(1, 7) if r[x] in fl and r[x-1] not in 'LJ ' and r[x+1] not in 'LJ ']
            if not cand: cand = [x for x in range(8) if r[x] in fl]
            if cand:
                x = random.choice(cand); r[x] = random.choice(choices); put = True
        if not put and n in OPEN and random.random() < 0.5:
            fl, choices = OPEN[n]
            cand = [x for x in range(1, 7) if r[x] == ' ' and r[x-1] == ' ' and r[x+1] == ' ']
            if cand: r[random.choice(cand)] = random.choice(choices); put = True
        if put: last = i; rows_[i] = ''.join(r)
    rows_ += ['        '] * 14
    if n == 5:   # tres bombas biologicas obligatorias cerca del final
        for j, rr in enumerate([MAPLEN - 30, MAPLEN - 24, MAPLEN - 18]):
            r = list(rows_[rr]); r[3] = 'B'; rows_[rr] = ''.join(r)
    return rows_
MAPS = {}
for S in SECTORS:
    n = S['n']; keys = SETS[n]['keys']; m = gen_map(n); MAPS[n] = m
    A('\n; ---- mapa sector %d: %d filas de metatiles (orden de aparicion)' % (n, len(m)))
    uniq = []
    for r in m:
        if r not in uniq: uniq.append(r)
    assert len(uniq) <= 255
    A('s%d_rows:   ; %d filas distintas (diccionario)' % (n, len(uniq)))
    for r in uniq:
        A('    .byte ' + ','.join(str(keys.index(ch)) for ch in r) + '   ; |%s|' % r)
    A('s%d_map:    ; una fila de diccionario por fila del mapa' % n)
    for i in range(0, len(m), 25):
        A('    .byte ' + ','.join(str(uniq.index(r)) for r in m[i:i + 25]))
A('MAPLEN = %d' % MAPLEN)

# ------------------------------------------------------------------ tablas de punteros por sector
A('\n; ---- punteros por sector')
for nm in ('charset', 'mt', 'mt_tgt', 'mt_alt', 'mt_crat', 'map', 'rows'):
    A('sec_%s_lo: .byte %s' % (nm, ','.join('<s%d_%s' % (n, nm) for n in range(1, 6))))
    A('sec_%s_hi: .byte %s' % (nm, ','.join('>s%d_%s' % (n, nm) for n in range(1, 6))))
A('sec_chars: .byte ' + ','.join('s%d_chars' % n for n in range(1, 6)))
A('sec_crater: .byte ' + ','.join('s%d_crater' % n for n in range(1, 6)))
A('sec_open: .byte ' + ','.join('s%d_open' % n for n in range(1, 6)))

# ------------------------------------------------------------------ sprites
A('\n; ---- nave VORTICE 5 (16 lineas por frame): P0 y P1')
for k in ('centro', 'izquierda', 'derecha', 'motor_b'):
    r = rows(SHIP[k]); r = (r + ['........'] * 16)[:16]
    A('ship_%s_p0:' % k); bytes_line([bits(x, 'ac') for x in r])
    A('ship_%s_p1:' % k); bytes_line([bits(x, 'bc') for x in r])
A('ship_p0_lo: .byte <ship_centro_p0,<ship_izquierda_p0,<ship_derecha_p0,<ship_motor_b_p0')
A('ship_p0_hi: .byte >ship_centro_p0,>ship_izquierda_p0,>ship_derecha_p0,>ship_motor_b_p0')
A('ship_p1_lo: .byte <ship_centro_p1,<ship_izquierda_p1,<ship_derecha_p1,<ship_motor_b_p1')
A('ship_p1_hi: .byte >ship_centro_p1,>ship_izquierda_p1,>ship_derecha_p1,>ship_motor_b_p1')

# tipos de objeto aereo: 0..9 enemigos, 10 capsula P, 11 explosion
MOVE = {'AGUJA': 0, 'CARROÑERO': 1, 'ZÁNGANO': 2, 'LAPA': 3, 'AGUJA TÉRMICA': 0, 'CAZADOR DELTA': 4,
        'ORBE ESPEJO': 5, 'ZÁNGANO PRISMA': 1, 'DESTRUCTOR': 5, 'MINA NERVIOSA': 5}
SPEED = {'AGUJA': 2, 'CARROÑERO': 1, 'ZÁNGANO': 1, 'LAPA': 2, 'AGUJA TÉRMICA': 3, 'CAZADOR DELTA': 2,
         'ORBE ESPEJO': 1, 'ZÁNGANO PRISMA': 1, 'DESTRUCTOR': 1, 'MINA NERVIOSA': 1}
HP = {'AGUJA': 1, 'CARROÑERO': 2, 'ZÁNGANO': 1, 'LAPA': 2, 'AGUJA TÉRMICA': 1, 'CAZADOR DELTA': 2,
      'ORBE ESPEJO': 3, 'ZÁNGANO PRISMA': 1, 'DESTRUCTOR': 6, 'MINA NERVIOSA': 2}
SCORE = {'AGUJA': 0x01, 'CARROÑERO': 0x02, 'ZÁNGANO': 0x01, 'LAPA': 0x02, 'AGUJA TÉRMICA': 0x02,
         'CAZADOR DELTA': 0x03, 'ORBE ESPEJO': 0x03, 'ZÁNGANO PRISMA': 0x02, 'DESTRUCTOR': 0x10, 'MINA NERVIOSA': 0x03}
FIRE = {'CARROÑERO': 1, 'LAPA': 0, 'CAZADOR DELTA': 1, 'ORBE ESPEJO': 2, 'DESTRUCTOR': 1, 'MINA NERVIOSA': 4}
objs = []
for (n, s, role, col, wd, frames) in ENEMIES:
    fr = []
    for f in frames:
        r = rows(f)
        if wd == 'D': r = [x for x in r for _ in (0, 1)]
        fr.append(r)
    objs.append(dict(name=n, color=col, dbl=1 if wd == 'D' else 0, frames=fr, move=MOVE[n], speed=SPEED[n],
                     hp=HP[n], score=SCORE[n], fire=FIRE.get(n, 0)))
cap = COMMON[1]; exp_ = COMMON[0]
objs.append(dict(name='CAPSULA', color=cap[3], dbl=0, frames=[rows(cap[5][0])] * 2, move=6, speed=1, hp=1, score=0, fire=0))
objs.append(dict(name='EXPLOSION', color=exp_[3], dbl=0, frames=[rows(f) for f in exp_[5]], move=7, speed=0, hp=0, score=0, fire=0))
A('\n; ---- objetos aereos: 0-9 enemigos (2 por sector), 10 capsula P, 11 explosion')
for i, o in enumerate(objs):
    for j, f in enumerate(o['frames']):
        A('og%d_%d: ; %s' % (i, j, o['name'])); bytes_line([bits(x, 'X') for x in f])
A('NOBJT = %d' % len(objs))
nfr = max(len(o['frames']) for o in objs)
for j in range(nfr):
    A('ot_gfx%d_lo: .byte %s' % (j, ','.join('<og%d_%d' % (i, min(j, len(o['frames'])-1)) for i, o in enumerate(objs))))
    A('ot_gfx%d_hi: .byte %s' % (j, ','.join('>og%d_%d' % (i, min(j, len(o['frames'])-1)) for i, o in enumerate(objs))))
for key in ('color', 'dbl', 'move', 'speed', 'hp', 'fire'):
    A('ot_%s: .byte %s' % (key, ','.join(str(o[key]) for o in objs)))
A('ot_score: .byte ' + ','.join('$%02X' % o['score'] for o in objs))
A('ot_h: .byte ' + ','.join(str(len(o['frames'][0])) for o in objs))
A('ot_w: .byte ' + ','.join(str(16 if o['dbl'] else 8) for o in objs))

# ------------------------------------------------------------------ oleadas
# evento: fila de mapa, tipo, x, cantidad, intervalo (frames), param, suelta P
A('\n; ---- oleadas: fila, tipo, x, cantidad, intervalo, param, sueltaP  (fila 255 = fin)')
random.seed(55)
for S in SECTORS:
    n = S['n']; ev = []; row = 10; k = 0
    while row < MAPLEN - 18:
        t = (n - 1) * 2 + (k % 2)
        mv = objs[t]['move']
        if mv == 3:   x = random.choice([0, 1])            # lapa: lado
        elif mv == 4: x = random.randint(20, 100)
        else:         x = random.randint(12, 104)
        cnt = 3 if objs[t]['hp'] >= 3 else random.choice([4, 5])
        if objs[t]['name'] == 'DESTRUCTOR': cnt = 2
        itv = random.choice([14, 18, 22])
        # separación vertical mínima entre enemigos de la misma oleada (~24 líneas):
        # si van más juntos, dos players no bastan para la misma franja y alguno parpadea
        vy = {0: objs[t]['speed'], 1: 0.75, 2: 1.63, 3: 2.0, 4: objs[t]['speed'], 5: 0.5}[mv]
        itv = max(itv, int(24 / vy + 0.99))
        param = random.randint(0, 255)
        dropP = 1 if k % 4 == 3 else 0
        ev.append((row, t, x, cnt, itv, param, dropP))
        row += random.choice([5, 6, 7]) - (1 if n == 4 else 0)   # el 5 ya va cargado: sin apretar más
        k += 1
    A('s%d_waves:' % n)
    for e in ev: A('    .byte ' + ','.join(str(v) for v in e))
    A('    .byte 255')
A('sec_waves_lo: .byte ' + ','.join('<s%d_waves' % n for n in range(1, 6)))
A('sec_waves_hi: .byte ' + ','.join('>s%d_waves' % n for n in range(1, 6)))

# ------------------------------------------------------------------ jefes
WEAK = {   # x,y,w,h (pixeles del jefe), hp, nucleo(1=solo al final)
 'GARRA-9':      [(13, 6, 7, 9, 10, 0), (92, 6, 7, 9, 10, 0), (51, 16, 11, 16, 20, 1)],
 'MADRE PÓLIPO': [(41, 21, 7, 11, 10, 0), (64, 21, 7, 11, 10, 0), (51, 27, 11, 13, 20, 1)],
 'HORNO OMEGA':  [(9, 23, 4, 7, 8, 0), (25, 23, 4, 7, 8, 0), (83, 23, 4, 7, 8, 0), (99, 23, 4, 7, 8, 0), (50, 22, 12, 14, 22, 1)],
 'EL PRISMARCA': [(21, 36, 7, 9, 8, 0), (84, 36, 7, 9, 8, 0), (35, 2, 7, 9, 8, 0), (70, 2, 7, 9, 8, 0), (51, 18, 11, 17, 24, 1)],
 'LEVIATÁN V':   [(37, 19, 7, 11, 12, 0), (72, 19, 7, 11, 12, 0), (50, 16, 13, 21, 28, 1)],
}
boss_report = []
for k, (name, sub, fn, pal, wp) in enumerate(BOSS_DEF):
    c = fn(); grid = chars_of(c)
    def build_cs(rs):
        cs = [BLANK]; idx = {BLANK: 0}; out = []
        for r in rs:
            o = []
            for ch in grid[r]:
                if ch not in idx: idx[ch] = len(cs); cs.append(ch)
                o.append(idx[ch])
            out.append(o)
        return cs, out
    whole, _ = build_cs(range(7))
    if len(whole) <= 112: split = 7; a = build_cs(range(7)); b = ([BLANK], [])
    else:
        best = None
        for sp in range(1, 7):
            aa = build_cs(range(sp)); bb = build_cs(range(sp, 7)); m = max(len(aa[0]), len(bb[0]))
            if best is None or m < best[0]: best = (m, sp, aa, bb)
        _, split, a, b = best
    boss_report.append((name, len(a[0]), len(b[0]), split))
    t = 'b%d' % (k + 1)
    A('\n; ==== JEFE %d: %s  (charset A %d, B %d, corte en fila %d)' % (k + 1, name, len(a[0]), len(b[0]), split))
    A('%s_csa_n = %d' % (t, len(a[0]))); A('%s_csa:' % t); bytes_line([x for ch in a[0] for x in charbytes(ch)])
    A('%s_csb_n = %d' % (t, len(b[0]))); A('%s_csb:' % t); bytes_line([x for ch in b[0] for x in charbytes(ch)])
    A('%s_scr: ; 7 filas x 28 columnas' % t)
    for o in a[1] + b[1]: A('    .byte ' + ','.join(str(x) for x in o))
    A('%s_split = %d' % (t, split))
    A('%s_pal: .byte $%02X,$%02X,$%02X,$%02X' % (t, pal['BG'], pal['PF0'], pal['PF1'], pal['PF2']))
    w = WEAK[name]
    A('%s_wp_n = %d' % (t, len(w)))
    A('%s_wp: ; x,y,w,h,hp,nucleo' % t)
    for e in w: A('    .byte ' + ','.join(str(v) for v in e))
for nm in ('csa', 'csb', 'scr', 'pal', 'wp'):
    A('boss_%s_lo: .byte %s' % (nm, ','.join('<b%d_%s' % (i, nm) for i in range(1, 6))))
    A('boss_%s_hi: .byte %s' % (nm, ','.join('>b%d_%s' % (i, nm) for i in range(1, 6))))
A('boss_csa_n: .byte ' + ','.join('b%d_csa_n' % i for i in range(1, 6)))
A('boss_csb_n: .byte ' + ','.join('b%d_csb_n' % i for i in range(1, 6)))
A('boss_split: .byte ' + ','.join('b%d_split' % i for i in range(1, 6)))
A('boss_wp_n: .byte ' + ','.join('b%d_wp_n' % i for i in range(1, 6)))

# ------------------------------------------------------------------ textos (codigos internos ANTIC)
def scode(s):
    out = []
    for ch in s:
        ch = unicodedata.normalize('NFKD', ch).encode('ascii', 'ignore').decode() or ' '
        a = ord(ch.upper())
        if 32 <= a < 96: out.append(a - 32)
        else: out.append(0)
    return out
def text(label, s, w=None):
    s = s if w is None else s.center(w)
    A('%s: .byte %s' % (label, ','.join(str(b) for b in scode(s))))
A('\n; ---- textos (codigo interno)')
def text2(label, s, w, add=0, align='c'):
    s = s.center(w) if align == 'c' else s.ljust(w)
    assert len(s) == w, (label, s)
    A('%s: .byte %s' % (label, ','.join(str(b + add if b else 0) for b in scode(s))))
text2('txt_logo', 'VORTICE 5', 16)
text2('txt_sub', 'CORAZON DE ACERO', 16, 192)
text2('txt_style', 'SHOOT EM UP DE 8 BITS DEFINITIVO', 32)
text2('txt_press', 'PULSA FIRE PARA JUGAR', 32)
text2('txt_credit', '2026 TONY C. WARE', 32)
text2('txt_hi', '           RECORD', 32, 0, 'l')
text2('txt_gameover', 'GAME OVER', 16)
text2('txt_score', 'PUNTUACION FINAL', 32)
text2('txt_victory', 'VICTORIA', 16)
text2('txt_victory2', 'EL CORAZON DE ACERO HA CAIDO', 32)
text2('txt_warning', '!! ALERTA: JEFE EN CAMINO !!', 32)
text2('txt_fire2', 'PULSA FIRE DOS VECES PARA SALIR', 32)
text2('txt_clear', 'SECTOR SUPERADO  +5000', 32)
for S in SECTORS:
    text2('txt_sec%d' % S['n'], 'SECTOR %d  %s' % (S['n'], S['name']), 32)
A('txt_sec_lo: .byte ' + ','.join('<txt_sec%d' % n for n in range(1, 6)))
A('txt_sec_hi: .byte ' + ','.join('>txt_sec%d' % n for n in range(1, 6)))

# ------------------------------------------------------------------ pantallas: radar, estrellas, logo
# Radar del título: 32 x 53 píxeles en P0..P3 (anchura normal, uno al lado del otro).
# El píxel del Atari es ~1,67 veces más ancho que alto: elipse de 16 x 26,5 = círculo en pantalla.
import math
RW, RH = 32, 53
cx, cy, rx, ry = 15.5, 26.0, 15.5, 26.0
bmp = [[0] * RW for _ in range(RH)]
for y in range(RH):
    for x in range(RW):
        d = math.hypot((x - cx) / rx, (y - cy) / ry)
        if 0.90 <= d <= 1.0: bmp[y][x] = 1                      # aro exterior
        ang = math.atan2((y - cy) / ry, (x - cx) / rx)
        if 0.52 <= d <= 0.58 and int((ang + math.pi) / (2 * math.pi) * 32) % 4 == 0: bmp[y][x] = 1  # aro interior a trazos
        if 0.78 <= d < 0.90 and min(abs(x - cx), abs(y - cy) / ry * rx) < 0.6: bmp[y][x] = 1  # marcas N E S O
        if d < 0.07: bmp[y][x] = 1                               # centro
A('\n; ---- radar del título: 4 columnas de 53 bytes (P0..P3)')
A('RAD_H = %d' % RH)
A('rad_bmp:')
for p in range(4):
    for y0 in range(0, RH, 27):
        A('    .byte ' + ','.join(str(sum(bmp[y][p * 8 + b] << (7 - b) for b in range(8))) for y in range(y0, min(RH, y0 + 27))))
# barrido: 64 ángulos, paso 8.8 con signo por punto (16 puntos desde el centro)
A('; barrido del radar: incremento x / y (8.8 con signo) por punto, 64 ángulos')
dxs, dys = [], []
for a in range(64):
    t = a * 2 * math.pi / 64 - math.pi / 2
    dxs.append(int(round(math.cos(t) * rx * 0.88 / 16 * 256)) & 0xFFFF)
    dys.append(int(round(math.sin(t) * ry * 0.88 / 16 * 256)) & 0xFFFF)
for nm, v in (('rad_dxl', [d & 255 for d in dxs]), ('rad_dxh', [d >> 8 for d in dxs]), ('rad_dyl', [d & 255 for d in dys]), ('rad_dyh', [d >> 8 for d in dys])):
    A('%s: .byte %s' % (nm, ','.join(str(b) for b in v)))
# ecos: posición (x, y) dentro del radar y ángulo al que el barrido los descubre
blips = []
for ang, rr in ((7, 0.62), (22, 0.35), (37, 0.78), (51, 0.55), (60, 0.25)):
    t = ang * 2 * math.pi / 64 - math.pi / 2
    blips.append((ang, int(round(cx + math.cos(t) * rx * rr)), int(round(cy + math.sin(t) * ry * rr))))
A('NBLIP = %d' % len(blips))
A('blip_a: .byte ' + ','.join(str(b[0]) for b in blips))
A('blip_x: .byte ' + ','.join(str(b[1]) for b in blips))
A('blip_y: .byte ' + ','.join(str(b[2]) for b in blips))
# tipo de cada línea del núcleo de pantallas (0 estrellas, 1 logotipo, 2 texto)
ZONES = [(8, 0), (16, 1), (4, 0), (8, 2), (8, 0), (56, 0), (6, 0), (8, 2), (6, 0), (8, 2), (4, 0), (8, 2), (6, 0), (8, 2), (4, 0), (8, 2), (8, 0)]
klt = []
for n, t in ZONES:
    if t == 2:                            # texto: la línea anterior apaga las estrellas
        klt[-1] = 2; klt += [3] * n
    else: klt += [t] * n
A('KLINES = %d' % len(klt))
A('KRADAR = %d                ; primera línea del núcleo con radar' % (8 + 16 + 4 + 8 + 8))
A('klt:')
for i in range(0, len(klt), 32):
    A('    .byte ' + ','.join(str(b) for b in klt[i:i + 32]))
A('kgrad: .byte 14,14,12,10,8,6,4,2,4,6,8,10,12,14,14,12   ; brillo cromado del logotipo')

# ------------------------------------------------------------------ dron (POKEY 3+4 en 16 bits, reloj 1,79 MHz)
# El contorno sale del MP3 de referencia (tools/drone_cycle.txt): un barrido de tono continuo
# que se repite cada 4,22 s. Cada fase lo usa transportado y con otro tempo.
import numpy as np
CYC = np.loadtxt(os.path.join(HERE, 'drone_cycle.txt'))
def drone(label, semis, tempo):
    n = int(round(len(CYC) / tempo))
    src = np.interp(np.arange(n) * tempo, np.arange(len(CYC)), CYC, period=len(CYC))
    f = src * 2 ** (semis / 12.0)
    N = [int(round(1789790.0 / (2 * fr) - 7)) for fr in f]
    assert all(0 < v < 0xFF00 for v in N)
    out = []
    for v in N: out += [v & 255, v >> 8]
    A('%s: ; %d cuadros, %+d semitonos, tempo x%.2f' % (label, n, semis, tempo))
    bytes_line(out + [0, 0xFF])
DRONES = [('mus_boss', 3, 1.45)]   # el dron de los jefes, tal cual estaba
A('\n; ---- dron: pares (AUDF3 bajo, AUDF4 alto) por cuadro; alto $FF = vuelta al principio')
for lab, st, tp in DRONES: drone(lab, st, tp)
A('mus_lo: .byte ' + ','.join('<' + d[0] for d in DRONES))
A('mus_hi: .byte ' + ','.join('>' + d[0] for d in DRONES))



# ------------------------------------------------------------------ canciones de pantallas (título y GAME OVER)
# Dos voces en 16 bits a 1,79 MHz: bajo en canales 1+2, melodía en 3+4.
# Adaptación libre de los MP3 de referencia: misma tonalidad, tempo y armonía, arreglo propio.
MIDI = {}
for octv in range(0, 8):
    for i, nm in enumerate(['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B']):
        MIDI['%s%d' % (nm, octv)] = 12 * (octv + 1) + i
def N16(m): return int(round(1789790.0 / (2 * 440.0 * 2 ** ((m - 69) / 12.0)) - 7))
A('\n; ---- tabla de notas 16 bits (MIDI 24..95)')
A('nt_lo: .byte ' + ','.join(str(N16(m) & 255) for m in range(24, 96)))
A('nt_hi: .byte ' + ','.join(str(N16(m) >> 8) for m in range(24, 96)))
def N8(m): return max(0, min(255, int(round(63921.0 / (2 * 440.0 * 2 ** ((m - 69) / 12.0)) - 1))))
A('nt8:   .byte ' + ','.join(str(N8(m)) for m in range(24, 96)) + '   ; 8 bits a 64 kHz (melodía en fases)')
def voice(label, events, unit, loop):
    """events: lista (nota|'-', duración en unidades); unit = cuadros por unidad (fraccionario)."""
    out = []; acc = 0.0; pos = 0
    for ev in events:
        note, d = ev[0], ev[1]
        fade = len(ev) > 2 and ev[2] == 'fade'
        t0 = round(pos * unit); pos += d; t1 = round(pos * unit); fr = t1 - t0
        while fr > 0:
            k = min(fr, 250)
            v = 0 if note == '-' else MIDI[note] - 24 + 1
            if fade: v |= 0x80
            out += [v, k]; fr -= k
    out += [0xFF, 1 if loop else 0]
    A('%s: ; %d cuadros' % (label, round(pos * unit)))
    bytes_line(out)
    return round(pos * unit)
# --- TÍTULO ("titulo", de Tony): ~141,5 ppm, Re menor, 12 compases en bucle (acaba en Do -> Re m)
SIXT = 60.0 * 0.1060
def arp(r, third, fifth, lowfifth):
    # arpegio de 16 semicorcheas sobre el acorde (sube, baja y prepara el siguiente)
    return [(n, 1) for n in (r+'4', third+'4', fifth+'4', r+'5', third+'5', fifth+'5', third+'5', r+'5',
                                fifth+'4', r+'5', third+'5', r+'5', fifth+'4', third+'4', r+'4', lowfifth+'3')]
tl = []
tl += arp('D', 'F', 'A', 'A')
tl += [(n,1) for n in ('D4','G4','B4','D5','G5','D5','B4','G4','D5','G5','B4','D5','B4','G4','D4','B3')]
tl += [(n,1) for n in ('A#3','D4','F4','A#4','D5','F5','D5','A#4','F4','A#4','D5','A#4','F4','D4','A#3','F3')]
tl += [(n,1) for n in ('C4','E4','G4','C5','E5','G5','E5','C5','G4','C5','E5','C5','G4','E4','C4','G3')]
tl += [('F5',4),('A4',2),('F5',2),('D5',2),('A4',2),('F5',2),('E5',2)]
tl += [('D5',2),('E5',2),('C5',4),('C5',2),('A4',2),('A4',2),('C5',2)]
tl += [('D5',4),('C5',2),('A#4',2),('D5',4),('F5',4)]
tl += [('F5',2),('D5',2),('A#4',4),('G4',2),('C5',2),('E5',4)]
tl += [('E5',2),('F5',2),('A4',2),('F4',2),('E4',1),('D4',3),('A4',2),('D4',2)]
tl += [('A4',2),('F4',1),('E4',1),('D4',2),('A4',2),('F4',2),('A4',2),('G4',2),('E4',2)]
tl += [(n,1) for n in ('A#3','D4','F4','A#4','D5','F5','D5','A#4','F4','A#4','D5','F5','D5','A#4','F4','D4')]
tl += [(n,1) for n in ('C4','E4','G4','C5','E5','G5','E5','C5','G4','C5','E5','G5','E5','C5','G4','E4')]
troots = ['D','D','A#','C','D','A','A#','A#C','D','D','A#','C']
tb = []
for r in troots:
    halves = ['A#','C'] if r == 'A#C' else [r, r]
    for h in halves:
        lo = h + ('1' if h in ('A#', 'A') else '2'); hi = h + ('2' if h in ('A#', 'A') else '3')
        tb += [(lo, 2), (lo, 2), (hi, 2), (lo, 2)]
assert sum(e[1] for e in tl) == 192 and sum(e[1] for e in tb) == 192, (sum(e[1] for e in tl), sum(e[1] for e in tb))
A('\n; ---- canción del título (bucle de 12 compases, ~20 s)')
t1 = voice('song_title_b', tb, SIXT, True)
t2 = voice('song_title_l', tl, SIXT, True)
assert t1 == t2
# --- FASES ("Heart of Steel", de Tony): ~146 ppm, Re menor, 32 compases en bucle (acaba en La -> Re m)
SIXH = 60.0 * 0.1028
M1 = [('A4',1),('A4',1),('A4',2),('A4',1),('A4',1),('A4',1),('F5',1),('D5',2),('F5',2),('F5',1),('E5',1),('D5',2)]
B2 = [('E5',3),('C5',1),('G4',2),('C5',2),('D5',3),('A4',1),('F4',2),('A4',2)]
B4 = [('G4',2),('C5',2),('E5',2),('E5',2),('F5',2),('E5',2),('D5',2),('A4',2)]
B5 = [('A4',1),('F4',1),('A4',1),('D5',1),('D5',2),('E5',2),('F5',4),('D5',2),('A#4',2)]
B6 = [('G4',2),('E5',2),('C5',2),('E5',2),('D5',2),('A#4',2),('F4',2),('A#4',2)]
hl = []
hl += [('D4',2),('F4',2),('A4',2),('D5',2),('A4',2),('F4',2),('A4',2),('C5',2)]          # 0 Dm
hl += M1                                                                                # 1 Dm|Bb
hl += B2                                                                                # 2 C|Dm
hl += [('A4',2),('D5',2),('A4',2),('F4',2),('A4',2),('C5',2),('F5',2),('C5',2)]          # 3 Dm|F
hl += B4 + B5 + B6                                                                      # 4-6
hl += [('D5',2),('F5',2),('D5',2),('A#4',2),('C5',2),('E5',2),('G5',2),('E5',2)]         # 7 Bb|C
hl += [('E5',2),('C5',2),('A4',2),('E4',2),('F4',2),('A4',2),('D5',2),('F5',2)]          # 8 Am|Dm
hl += M1 + B2                                                                           # 9-10
hl += [('A4',2),('D5',2),('F5',2),('D5',2),('F5',2),('D5',2),('A#4',2),('F4',2)]         # 11 Dm|Bb
hl += B4 + B5 + B6                                                                      # 12-14
hl += [('D5',4),('F5',4),('E5',4),('G5',2),('E5',2)]                                     # 15 Bb|C
hl += [('D4',1),('D4',1),('F4',1),('D4',1),('A4',2),('D4',2),('E4',1),('E4',1),('A4',1),('E4',1),('C5',2),('A4',2)]   # 16 Dm|Am
hl += [('C4',1),('C4',1),('E4',1),('G4',1),('C5',2),('G4',2),('D4',1),('D4',1),('G4',1),('A#4',1),('D5',2),('A#4',2)] # 17 C|Gm
hl += [('G4',4),('A#4',2),('D5',2),('D5',4),('A#4',2),('A4',2)]                          # 18 Gm
hl += [('A4',4),('F4',2),('D4',2),('F4',4),('A#4',2),('D5',2)]                           # 19 Dm|Bb
hl += [('F5',4),('D5',2),('A#4',2),('G4',2),('C5',2),('E5',4)]                           # 20 Bb|C
hl += [('G5',2),('E5',2),('C5',2),('G4',2),('A4',2),('D5',2),('F5',4)]                   # 21 C|Dm
hl += [('D5',2),('C5',2),('A4',2),('F4',2),('A4',2),('C5',2),('D5',4)]                   # 22 Dm
hl += [('E5',4),('C5',2),('A4',2),('A#4',4),('D5',2),('F5',2)]                           # 23 Am|Bb
hl += [('F5',2),('D5',2),('A#4',2),('D5',2),('E5',2),('C5',2),('G4',2),('C5',2)]         # 24 Bb|C
hl += [('E5',4),('D5',2),('C5',2),('B4',4),('D5',2),('G4',2)]                            # 25 C|G
hl += [('D5',2),('B4',2),('G4',2),('B4',2),('A4',2),('D5',2),('F#5',4)]                  # 26 G|D
hl += [('F5',6),('E5',2),('D5',4),('A4',4)]                                              # 27 Dm
hl += [('A#4',2),('D5',2),('F5',2),('D5',2),('A#4',2),('F4',2),('D4',2),('F4',2)]        # 28 Bb
hl += [('G4',2),('C5',2),('E5',2),('C5',2),('G4',2),('E4',2),('C4',2),('E4',2)]          # 29 C
hl += [('D5',4),('A#4',4),('E5',4),('C5',4)]                                             # 30 Bb|C
hl += [('C#5',4),('E5',4),('A4',4),('C#5',4)]                                            # 31 A -> Dm
hroots = ['D','D', 'D','A#', 'C','D', 'D','F', 'C','D', 'D','A#', 'C','A#', 'A#','C',
          'A','D', 'D','A#', 'C','D', 'D','A#', 'C','D', 'D','A#', 'C','A#', 'A#','C',
          'D','A', 'C','G', 'G','G', 'D','A#', 'A#','C', 'C','D', 'D','D', 'A','A#',
          'A#','C', 'C','G', 'G','D', 'D','D', 'A#','A#', 'C','C', 'A#','C', 'A','A']
hb = []
for r in hroots:
    lo = r + ('1' if r in ('A#', 'A', 'G') else '2'); hi = r + ('2' if r in ('A#', 'A', 'G') else '3')
    hb += [(lo, 2), (lo, 2), (hi, 2), (lo, 2)]
assert sum(e[1] for e in hl) == 512 and sum(e[1] for e in hb) == 512, (sum(e[1] for e in hl), sum(e[1] for e in hb))
A('\n; ---- canción de las fases "Heart of Steel" (bucle de 32 compases, ~53 s)')
h1 = voice('song_phase_b', hb, SIXH, True)
h2 = voice('song_phase_l', hl, SIXH, True)
assert h1 == h2
# --- GAME OVER: ~100 ppm, Re menor, 4 compases y final que se apaga (no se repite)
SIX = 9   # cuadros por semicorchea
gb = []
for r in ['D','D','G','D#','D','A']:
    n = 8 if True else 0
    gb += [(r + '2', 1), (r + '2', 1), (r + '3', 1), (r + '2', 1)] * 2
gb = gb[:16 * 3]
gb += [('D2', 16, 'fade')]
gl = [('D5',4),('C5',2),('A4',2),('F4',4),('A4',4),
      ('A#4',4),('G4',4),('G4',2),('A#4',2),('D#5',4),
      ('F5',4),('E5',2),('D5',2),('C#5',4),('E5',4),
      ('D5',16,'fade')]
assert sum(e[1] for e in gb) == 64 and sum(e[1] for e in gl) == 64
A('\n; ---- canción de GAME OVER (una vez, acaba apagándose)')
voice('song_go_b', gb, SIX, False)
voice('song_go_l', gl, SIX, False)
A('song_b_lo: .byte <song_title_b,<song_go_b,<song_phase_b')
A('song_b_hi: .byte >song_title_b,>song_go_b,>song_phase_b')
A('song_l_lo: .byte <song_title_l,<song_go_l,<song_phase_l')
A('song_l_hi: .byte >song_title_l,>song_go_l,>song_phase_l')
# textos del selector de dificultad
text2('txt_dif0', 'DIFICULTAD   <  FACIL  >', 32)
text2('txt_dif1', 'DIFICULTAD   <  NORMAL  >', 32)
text2('txt_dif2', 'DIFICULTAD   <  HARDCORE  >', 32)
A('txt_dif_lo: .byte <txt_dif0,<txt_dif1,<txt_dif2')
A('txt_dif_hi: .byte >txt_dif0,>txt_dif1,>txt_dif2')

import math
A('sintab: .byte ' + ','.join(str((round(20*math.sin(i*2*math.pi/64))) & 255) for i in range(64)))
open(os.path.join(HERE, '..', 'src', 'data.s'), 'w').write('\n'.join(OUT) + '\n')
print('charsets sector:', charset_report)
for b in boss_report: print('jefe %-14s A=%d B=%d corte=%d' % b)
print('mapas:', {n: len(m) for n, m in MAPS.items()})
