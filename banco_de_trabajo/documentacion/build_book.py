# -*- coding: utf-8 -*-
"""Libro del juego de Vórtice 5: un único PDF con la memoria de diseño (texto de Tony C. Ware),
las instrucciones (folleto A5 a dos páginas por hoja), el atlas visual y el arte de portada.

uso: python3 build_book.py   (necesita ../docs con atlas.html y manual.html generados)
"""
import os, re, sys, subprocess, pathlib
sys.path.insert(0, '/home/claude/docs')
from common import TITLE, SUBTITLE, DESIGN, CREDITS, TAGLINE, STORY, STORY_PUNCH, SIGN, MACHINE
from pypdf import PdfReader, PdfWriter, Transformation, PageObject
from playwright.sync_api import sync_playwright

HERE = pathlib.Path(__file__).resolve().parent
DOCS = pathlib.Path('/home/claude/docs')
A4L = (841.89, 595.28)

def pdf(html_path, out):
    with sync_playwright() as p:
        b = p.chromium.launch(); pg = b.new_page()
        pg.goto(pathlib.Path(html_path).resolve().as_uri()); pg.wait_for_load_state('networkidle')
        pg.pdf(path=str(out), print_background=True, prefer_css_page_size=True); b.close()

# ---------------------------------------------------------------- atlas e instrucciones, sin nº de página propio
HIDE = '<style>.foot span:last-child{visibility:hidden}</style></head>'
for name in ('atlas', 'manual'):
    h = (DOCS / (name + '.html')).read_text()
    (DOCS / (name + '_libro.html')).write_text(h.replace('</head>', HIDE, 1))
    pdf(DOCS / (name + '_libro.html'), HERE / (name + '_libro.pdf'))

# ---------------------------------------------------------------- páginas propias del libro
css = re.search(r'<style>(.*?)</style>', (DOCS / 'atlas.html').read_text(), re.S).group(1)
css += '''
.lead{font-size:12.5pt;line-height:1.6;color:#d9dce6}
.body p{margin:0 0 3.2mm;font-size:10.5pt;line-height:1.62;color:#d9dce6}
.kicker{font:600 8pt "DejaVu Sans Mono",monospace;letter-spacing:.16em;text-transform:uppercase;color:#7fd4e0}
.cap{font-size:8pt;color:var(--muted);margin-top:1.6mm}
.img{border-radius:1.5mm;overflow:hidden;background:#000;border:1px solid var(--line)}
.img img{display:block;width:100%}
.quote{border-left:3px solid #7fd4e0;padding:3mm 0 3mm 6mm;font:italic 14pt/1.5 Inter,sans-serif;color:#eef0f6}
.sc{display:grid;grid-template-columns:9mm 1fr 30mm;gap:3mm;align-items:center;border:1px solid var(--line);border-radius:2mm;padding:2mm 3mm;background:#10131e}
.sc .n{font:800 15pt "Inter Display",sans-serif;color:#7fd4e0}
.sc b{font:700 10pt "Inter Display",sans-serif;letter-spacing:.04em}
.sc small{display:block;color:var(--muted);font-size:8.5pt}
.sc em{display:block;font-style:normal;font:600 7.5pt "DejaVu Sans Mono",monospace;color:var(--amber);margin-top:.6mm}
.divider{justify-content:center;align-items:flex-start;padding-left:30mm;background:radial-gradient(90% 90% at 80% 50%,#14243a 0%,#0b0d14 70%)}
.divider .num{font:800 110pt/0.9 "Inter Display",sans-serif;color:#1d2a40}
.toc{display:grid;grid-template-columns:auto 1fr auto;gap:1.6mm 6mm;font-size:10.5pt;align-items:baseline}
.foot{gap:6mm}
.toc .p{font-family:"DejaVu Sans Mono",monospace;color:var(--amber)}
.toc .d{border-bottom:1px dotted #3a4258;transform:translateY(-1.2mm)}
.cv{display:flex;flex-direction:column;gap:2mm}
.cv img{height:104mm;width:auto;border-radius:1.5mm;display:block;box-shadow:0 0 0 1px var(--line)}
.cv .t{font:700 10pt "Inter Display",sans-serif;letter-spacing:.05em}
.cv .v{font:600 7pt "DejaVu Sans Mono",monospace;color:#7fd4e0;letter-spacing:.14em}
.cv p{font-size:8.6pt;color:#cfd3e0;max-width:78mm;margin:0}
.nov li{margin:0 0 2.6mm;font-size:10pt;line-height:1.5}
.nov li b{color:#eef0f6}
'''

def foot(label):
    return f'<div class="foot"><span>VÓRTICE 5 · LIBRO DEL JUEGO · {label}</span><span>{CREDITS}</span><span></span></div>'

P = {}   # páginas propias por nombre
P['portada'] = f'''<section class="page" style="padding:0;background:#05060a">
<div style="position:absolute;right:0;top:0;bottom:0;width:158mm;overflow:hidden"><img src="img/caratula_oficial.jpg" style="height:100%;width:100%;object-fit:cover;object-position:center top"></div>
<div style="position:absolute;right:158mm;top:0;bottom:0;width:30mm;background:linear-gradient(90deg,#05060a00,#05060a)"></div>
<div style="position:absolute;left:16mm;top:20mm;width:112mm;display:flex;flex-direction:column;gap:5mm">
 <span class="eyebrow">Libro del juego</span>
 <h1 style="font-size:58pt;font-weight:800;line-height:.92">VÓRTICE<br><span style="color:var(--red)">5</span></h1>
 <div style="font:600 19pt 'Inter Display',sans-serif;color:var(--amber)">{SUBTITLE}</div>
 <div style="display:inline-block;align-self:flex-start;border:1.5px solid var(--fg);border-radius:2mm;padding:2mm 4mm;font:700 10.5pt 'Inter Display',sans-serif;letter-spacing:.04em">{DESIGN}</div>
 <p style="font-size:10pt;color:#cfd3e0">Memoria de diseño · Instrucciones · Atlas visual · Arte de portada</p>
 <p style="font-size:11.5pt;font-style:italic;color:#cfd3e0;max-width:104mm">{TAGLINE}</p>
</div>
<div style="position:absolute;left:16mm;width:112mm;bottom:14mm;display:flex;flex-direction:column;gap:3mm">
 <p class="credit" style="font-size:9.5pt">{CREDITS}</p>
 <span class="mono muted" style="font-size:8pt">{SIGN} · {MACHINE}</span>
</div></section>'''

def divider(num, title, sub):
    return f'''<section class="page divider"><div class="num">{num}</div>
<h2 style="font-size:40pt;margin-top:-6mm">{title}</h2><p class="lead" style="max-width:170mm;margin-top:4mm">{sub}</p>{foot(title.upper())}</section>'''

P['div_mem'] = divider('I', 'Memoria de diseño', 'Cómo nació Vórtice 5, contado por su autor: el origen, los cinco escenarios, los jefes, la música y el nombre.')
P['div_ins'] = divider('II', 'Instrucciones', 'El folleto del juego: historia, carga y controles, dificultades, marcador, los cinco sectores, los jefes, consejos y un secreto.')
P['div_atl'] = divider('III', 'Atlas visual', 'Cómo cabe en un Atari de 8 bits: reglas del hardware, la nave, cada sector con sus enemigos y su jefe, el sonido y el presupuesto comprobado.')
P['div_art'] = divider('IV', 'Arte de portada', 'La carátula oficial y nueve versiones alternativas, incluida la edición MSX.')

P['mem1'] = f'''<section class="page"><div class="head"><span class="kicker">01 · El origen</span><h2>Una idea sencilla</h2><span class="sub">Del A400 Mini a los primeros prototipos</span></div>
<div style="display:grid;grid-template-columns:1fr 128mm;gap:10mm">
<div class="body">
<p>La compra del A400 Mini me llevó a descubrir los ordenadores Atari de 8 bits a través de sus juegos. No fue un reencuentro: los estaba conociendo por primera vez, y me engancharon. Entonces empecé a preguntarme qué podría conseguir con ideas más contemporáneas y la ayuda de asistentes de inteligencia artificial.</p>
<p>Me atraía especialmente ese contraste: intentar crear un arcade nuevo para una arquitectura concebida entre finales de los años setenta y principios de los ochenta, sin perder de vista sus limitaciones ni su personalidad.</p>
<h3 style="margin:4mm 0 2mm;color:#7fd4e0">Del primer boceto a la dirección definitiva</h3>
<p>El primer planteamiento se acercaba a Xenon 2, pero pronto comprendí que aquella idea no encajaba bien con lo que quería conseguir. La versión inicial no cuajó. Entonces llegó una segunda propuesta: algo más cercano a Star Force, pero con alma de euroshooter.</p>
<p>Ahí encontré el rumbo: velocidad, acción constante, oleadas peligrosas y grandes enemigos finales. Lo importante no era imitar exactamente un clásico, sino recuperar aquello que tanto me gustaba de esos juegos y construir algo propio a partir de esas sensaciones.</p>
</div>
<div><div class="img"><img src="img/nave_ilustracion.jpg"></div><p class="cap">Vórtice 5: interpretación artística de la nave protagonista.</p>
<div style="display:flex;gap:4mm;align-items:center;margin-top:5mm"><div class="img" style="background:#000;padding:3mm;width:30mm"><img src="img/ship_centro.png" style="image-rendering:pixelated"></div>
<p class="cap" style="margin:0">Y la misma nave en el Atari: 8 × 15 píxeles en dos players superpuestos.</p></div></div>
</div>{foot('MEMORIA')}</section>'''

P['mem2'] = f'''<section class="page" style="padding:10mm 14mm 14mm"><div class="head" style="padding-bottom:2mm"><span class="kicker">Lámina de diseño industrial</span><span class="sub">Vórtice 5, caza estelar de asalto · reproducción íntegra</span></div>
<div style="flex:1;display:flex;justify-content:center;align-items:center;min-height:0"><img src="img/lamina_industrial.jpg" style="max-height:158mm;max-width:100%;border-radius:1.5mm"></div>{foot('MEMORIA')}</section>'''

SCN = [('Cementerio de Titanes', 'Un cementerio de chatarra y maquinaria de destrucción.', 's1_3900'),
       ('Arrecife de Ácido', 'Un entorno hostil de naturaleza corrosiva.', 's2_9800'),
       ('Fundición Orbital', 'Una inmensa zona de transformación y energía.', 's3_18600'),
       ('Santuario Prisma', 'Un paisaje extraño, geométrico y brillante.', 's4_25600'),
       ('Corazón de Acero', 'El lugar donde aguarda el adversario definitivo.', 's5_35500')]
cards = ''.join(f'<div class="sc"><span class="n">0{i+1}</span><div><b>{n.upper()}</b><small>{d}</small></div><div class="img"><img src="img/game_{s}.png" style="height:22mm;object-fit:cover"></div></div>' for i, (n, d, s) in enumerate(SCN))
P['mem3'] = f'''<section class="page"><div class="head"><span class="kicker">02 · Diseño arcade</span><h2>Cinco escenarios, una idea</h2><span class="sub">La evolución de un matamarcianos vertical</span></div>
<div style="display:grid;grid-template-columns:1fr 150mm;gap:10mm">
<div class="body">
<p>Conforme avanzaba el proyecto, aquella fórmula sencilla empezó a crecer. Inspirándome en el sentido del espectáculo y la variedad de Life Force y Gradius, terminé imaginando cinco escenarios diferenciados, cada uno con una identidad visual propia.</p>
<p>Las oleadas de enemigos siguen la tradición de Xevious y Star Force: adversarios de lectura rápida, aparentemente sencillos, pero capaces de resultar letales. He buscado variedad y agresividad sin convertir la dificultad en algo injusto. Siempre habrá margen de mejora, pero creo que el equilibrio funciona.</p>
</div>
<div style="display:flex;flex-direction:column;gap:2.4mm">{cards}</div>
</div>{foot('MEMORIA')}</section>'''

P['mem4'] = f'''<section class="page"><div class="head"><span class="kicker">03 · Diseñar al enemigo</span><h2>Del píxel al coloso</h2><span class="sub">Puntos débiles, núcleos y bocetos en JsPaint</span></div>
<div style="display:grid;grid-template-columns:1fr 140mm;gap:10mm">
<div class="body">
<p>Para los enemigos finales miré especialmente hacia Zanac y su manera de plantear los puntos débiles: pequeñas torretas u orbes que hay que destruir antes de alcanzar el núcleo central. Esa estructura me permitía dar personalidad a los enfrentamientos y convertirlos en algo más que una simple resistencia a disparos.</p>
<p>Muchos de esos gigantes nacieron de ideas dispersas y de bocetos muy primitivos hechos en JsPaint. Poco a poco fueron tomando forma. GARRA-9, destructor y compactador consciente de residuos espaciales, es un buen ejemplo de esa evolución desde una silueta esquemática hasta una imagen industrial mucho más elaborada.</p>
</div>
<div style="display:flex;flex-direction:column;gap:3mm">
 <div class="img"><img src="img/garra9_render.jpg"></div><p class="cap" style="margin:0">GARRA-9 · interpretación visual realista del enemigo final.</p>
 <div style="display:grid;grid-template-columns:1fr 1fr 1fr;gap:3mm;align-items:end">
  <div><div class="img"><img src="img/boceto_garra9.jpg"></div><p class="cap">Boceto original de GARRA-9</p></div>
  <div><div class="img"><img src="img/boceto_nave.jpg"></div><p class="cap">Boceto original de la nave</p></div>
  <div><div class="img" style="padding:2mm"><img src="img/boss1.png" style="image-rendering:pixelated"></div><p class="cap">GARRA-9 en el Atari: 112 × 56 píxeles</p></div>
 </div>
</div></div>{foot('MEMORIA')}</section>'''

P['mem5'] = f'''<section class="page"><div class="head"><span class="kicker">04 · Sonido, nombre y recuerdos</span><h2>El círculo se cierra</h2><span class="sub">Una idea de juventud convertida en un juego</span></div>
<div style="display:grid;grid-template-columns:1fr 1fr;gap:12mm">
<div class="body">
<h3 style="margin:0 0 2mm;color:#7fd4e0">La música también empezó con un boceto</h3>
<p>Para componer la música hice algo bastante poco sofisticado: silbé al micrófono unas notas que tenía en la cabeza y las grabé con Audacity. Sí, literalmente. A partir de aquel punto de partida, y combinando herramientas de IA con programas como Drum Machine, apareció un tema que se parecía bastante a lo que había imaginado.</p>
<p>Para los jefes finales buscaba otra sensación: un drone electrónico de sabor arcade ochentero, más amenazante y mecánico. El resultado terminó encajando con el carácter de esos grandes adversarios.</p>
<ul class="rules" style="margin-top:3mm"><li><span>TÍTULO</span><span>«Titulo», bucle de 12 compases</span></li><li><span>FASES</span><span>«Heart of Steel», bucle de 32 compases</span></li><li><span>JEFES</span><span>El dron arcade</span></li><li><span>GAME OVER</span><span>Una vez, apagándose</span></li></ul>
</div>
<div class="body">
<h3 style="margin:0 0 2mm;color:#7fd4e0">¿Por qué «Vórtice 5»?</h3>
<p>El nombre llevaba muchos años conmigo. De chaval jugué en MSX a Defcom 1 y a Vortex Raider. Me fascinaba la combinación de nombre y número del primero, y también la fuerza de la palabra «vortex» del segundo. Traducirla a «vórtice» me parecía natural.</p>
<p>Estoy casi seguro de que en alguna cinta olvidada debe de existir un intento de hacer las aventuras de Vórtice 5 en BASIC. Quizá nunca llegue a encontrarlo, pero me gusta pensar que esta versión recupera algo de aquel entusiasmo.</p>
<div class="quote" style="margin-top:5mm">«Así nació Vórtice 5 — Corazón de Acero. Un juego que espero que entretenga a quien se anime a probarlo, sin más pretensiones».</div>
<p class="mono" style="font-size:8pt;color:#7fd4e0;margin-top:2mm;letter-spacing:.12em">TONY C. WARE · NOTAS DE DISEÑO</p>
</div></div>{foot('MEMORIA')}</section>'''

P['nov'] = f'''<section class="page"><div class="head"><span class="eyebrow">Esta edición · noviembre de 2026</span><h2>Novedades</h2></div>
<div style="display:grid;grid-template-columns:1fr 112mm;gap:10mm">
<ul class="nov" style="padding-left:5mm;margin:0">
<li><b>Pantalla de título nueva.</b> Radar con barrido, estela y ecos de las fuerzas de Leviatán V; estrellas en tres capas que bajan a distinta velocidad; logotipo cromado que cambia de tono. GAME OVER y victoria comparten las estrellas y el logotipo.</li>
<li><b>Sin cámara lenta.</b> Una oleada espera a que haya hueco si ya hay 5 enemigos en pantalla (4 en los sectores 4 y 5). Las fases van ahora al 90–100 % de velocidad en Normal; antes caían a la mitad cuando coincidían dos oleadas.</li>
<li><b>Jefes sin raya.</b> GARRA-9, Madre Pólipo, El Prismarca y Leviatán V cambian de juego de caracteres a mitad del cuerpo; ese cambio llegaba una línea tarde y dejaba una raya horizontal. Corregido y comprobado píxel a píxel.</li>
<li><b>Disparos y enemigos sin cortes.</b> Moviéndose en diagonal, algunos disparos, balas y enemigos salían partidos en su primera línea. Ya no.</li>
<li><b>Créditos.</b> 2026 Tony C. Ware.</li>
<li><b>Banda sonora.</b> Las cuatro pistas, grabadas del propio Atari sin efectos de sonido.</li>
<li><b>Más sitio.</b> Los mapas se guardan como un diccionario de filas: unos 3,5 KB menos, la misma pantalla.</li>
</ul>
<div style="display:flex;flex-direction:column;gap:3mm"><div class="img"><img src="img/full_t_60.png" style="image-rendering:pixelated"></div><p class="cap" style="margin:0">El título nuevo, capturado del juego.</p>
<div class="img"><img src="img/game_b4_31200.png" style="image-rendering:pixelated;height:52mm;object-fit:cover;object-position:top"></div><p class="cap" style="margin:0">El Prismarca, entero, sin raya.</p></div>
</div>{foot('NOVEDADES')}</section>'''

P['oficial'] = f'''<section class="page"><div class="head"><span class="kicker">Arte de portada</span><h2>Carátula oficial</h2><span class="sub">Versión oficial aprobada para Vórtice 5 · Corazón de Acero</span></div>
<div style="flex:1;display:flex;justify-content:center;min-height:0"><img src="img/caratula_oficial.jpg" style="height:150mm;border-radius:1.5mm;box-shadow:0 0 0 1px var(--line)"></div>{foot('ARTE DE PORTADA')}</section>'''

VAR = [('01', 'Acabado oscuro', 'v01_acabado_oscuro', 'Menos brillo en general, para darle al conjunto un toque más suave y menos agresivo.'),
       ('02', 'Retro neón', 'v02_retro_neon', 'Un coloreado basado en las imágenes CGA de los ordenadores con DOS.'),
       ('03', 'Ilustración anime', 'v03_anime', 'La visión más lógica de un matamarcianos de época: anime japonés, nostálgico y siempre vigente.'),
       ('04', 'Textura envejecida', 'v04_textura_envejecida', 'El auténtico retro: la sensación de un juego usado o de una novela barata de ciencia ficción de la época.'),
       ('05', 'Leviatán 5', 'v05_leviatan5', 'El resultado de decirle a una IA que no sabe dibujar que dibuje. Tiene su encanto sintético: diseño industrial puro, modernismo maquinal en su esencia.'),
       ('06', 'Cósmica orgánica', 'v06_cosmica_organica', 'Una visión oscura, al estilo del cómic y la ilustración europea para adultos de la época.'),
       ('07', 'Versión V5', 'v07_version_v5', 'El primer boceto de lo que fue la carátula oficial, con la V5 volando hacia el núcleo enemigo.'),
       ('08', 'Edición cósmica', 'v08_edicion_cosmica', 'La visión típica para 8 bits: deja claro, desde el primer vistazo, a qué venimos y adónde vamos.'),
       ('09', 'Versión MSX', 'v09_msx', 'Una versión inspirada en aquellas carátulas de los cartuchos japoneses para MSX.')]
for k in range(3):
    grp = VAR[k * 3:k * 3 + 3]
    cells = ''.join(f'<div class="cv"><img src="img/{f}.jpg"><span class="v">VARIANTE {n}</span><span class="t">{t.upper()}</span><p>{d}</p></div>' for n, t, f, d in grp)
    title = 'Versiones alternativas' if k < 2 else 'Otras visiones y versión MSX'
    P['var%d' % k] = f'''<section class="page"><div class="head"><span class="kicker">Arte de portada</span><h2>{title}</h2></div>
<div style="display:grid;grid-template-columns:repeat(3,auto);justify-content:space-between;gap:6mm">{cells}</div>{foot('ARTE DE PORTADA')}</section>'''

P['contra'] = f'''<section class="page" style="justify-content:center;align-items:center;text-align:center;gap:7mm;background:radial-gradient(90% 80% at 50% 40%,#2a0d14 0%,#0b0d14 70%)">
<span class="eyebrow">{MACHINE}</span>
<h1 style="font-size:46pt;font-weight:800">VÓRTICE <span style="color:var(--red)">5</span></h1>
<div style="font:600 16pt 'Inter Display',sans-serif;color:var(--amber)">{SUBTITLE} · {DESIGN}</div>
<p style="max-width:190mm;font-size:13pt;font-style:italic;color:#cfd3e0">{TAGLINE}</p>
<p style="max-width:170mm;font-size:12pt">{CREDITS}</p>
<span class="mono muted" style="font-size:9pt">{SIGN}</span></section>'''

# ---------------------------------------------------------------- orden del libro
atlas = PdfReader(str(HERE / 'atlas_libro.pdf'))
manual = PdfReader(str(HERE / 'manual_libro.pdf'))
ATLAS_PAGES = list(range(2, 16))          # 3..16: reglas, nave, sectores y jefes, comunes, presupuesto
MANUAL_PAGES = list(range(1, 13))         # 2..13 del folleto, de dos en dos
order = [('e', 'portada'), ('e', 'indice'), ('e', 'div_mem'), ('e', 'mem1'), ('e', 'mem2'), ('e', 'mem3'), ('e', 'mem4'), ('e', 'mem5'),
         ('e', 'div_ins')] + [('m', i) for i in range(0, len(MANUAL_PAGES), 2)] + \
        [('e', 'div_atl'), ('e', 'nov')] + [('a', i) for i in ATLAS_PAGES] + \
        [('e', 'div_art'), ('e', 'oficial'), ('e', 'var0'), ('e', 'var1'), ('e', 'var2'), ('e', 'contra')]
pno = {k: n + 1 for n, (t, k) in enumerate(order) if t == 'e'}
first_m = next(n + 1 for n, (t, k) in enumerate(order) if t == 'm')
first_a = next(n + 1 for n, (t, k) in enumerate(order) if t == 'a')
sec_a = {name: first_a + i for i, name in enumerate(['Reglas del hardware', 'La nave Vórtice 5'])}
TOC = [('I', 'Memoria de diseño', pno['div_mem']), ('', 'El origen · Lámina de diseño industrial', pno['mem1']), ('', 'Cinco escenarios, una idea', pno['mem3']),
       ('', 'Del píxel al coloso', pno['mem4']), ('', 'El círculo se cierra', pno['mem5']),
       ('II', 'Instrucciones', pno['div_ins']), ('', 'Historia, carga y controles', first_m), ('', 'Dificultad, marcador y nave', first_m + 1),
       ('', 'Los cinco sectores', first_m + 2), ('', 'Jefes y puntuación', first_m + 4), ('', 'Consejos y un secreto', first_m + 5),
       ('III', 'Atlas visual', pno['div_atl']), ('', 'Novedades de esta edición', pno['nov']), ('', 'Reglas del hardware y la nave', first_a),
       ('', 'Sectores y jefes', first_a + 2), ('', 'Comunes, sonido y presupuesto', first_a + 12),
       ('IV', 'Arte de portada', pno['div_art']), ('', 'Carátula oficial y nueve versiones', pno['oficial'])]
rows = ''.join(f'<span class="mono" style="color:#7fd4e0">{a}</span><span style="{"font-weight:700;font-size:11.5pt" if a else "color:#cfd3e0;padding-left:4mm"}">{t}</span><span class="p">{p:02d}</span>' for a, t, p in TOC)
P['indice'] = f'''<section class="page"><div class="head"><span class="eyebrow">Contenido</span><h2>Libro del juego</h2></div>
<div style="display:grid;grid-template-columns:1fr 100mm;gap:14mm"><div class="toc">{rows}</div>
<div style="display:flex;flex-direction:column;gap:4mm"><div class="img"><img src="img/portada_memoria.jpg"></div>
<p class="cap" style="margin:0">Este libro reúne en un solo documento la memoria de diseño de Tony C. Ware, el folleto de instrucciones, el atlas visual y el arte de portada.</p></div></div>{foot('CONTENIDO')}</section>'''

keys = [k for t, k in order if t == 'e']
html = f'<!doctype html><html lang="es"><head><meta charset="utf-8"><title>Vórtice 5 · Libro del juego</title><style>{css}</style></head><body>{"".join(P[k] for k in keys)}</body></html>'
(HERE / 'extra.html').write_text(html)
pdf(HERE / 'extra.html', HERE / 'extra.pdf')
extra = PdfReader(str(HERE / 'extra.pdf'))
eidx = {k: i for i, k in enumerate(keys)}

# ---------------------------------------------------------------- montaje + números de página
from reportlab.pdfgen import canvas as rc
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
fontp = subprocess.run(['fc-match', '-f', '%{file}', 'DejaVu Sans Mono'], capture_output=True, text=True).stdout
pdfmetrics.registerFont(TTFont('Mono', fontp))
nums = HERE / 'nums.pdf'
c = rc.Canvas(str(nums), pagesize=A4L)
for n in range(1, len(order) + 1):
    if n not in (1, len(order)):
        c.setFont('Mono', 7); c.setFillColorRGB(.55, .58, .66); c.drawRightString(A4L[0] - 45, 17, '%02d' % n)
    c.showPage()
c.save()
numr = PdfReader(str(nums))

w = PdfWriter()
for n, (t, k) in enumerate(order):
    if t == 'e':
        page = extra.pages[eidx[k]]
    elif t == 'a':
        page = atlas.pages[k]
    else:
        page = PageObject.create_blank_page(width=A4L[0], height=A4L[1])
        for j, idx in enumerate(MANUAL_PAGES[k:k + 2]):
            mp = manual.pages[idx]
            page.merge_transformed_page(mp, Transformation().translate(tx=j * A4L[0] / 2, ty=0))
    page.merge_page(numr.pages[n])
    w.add_page(page)
w.add_metadata({'/Title': 'Vórtice 5 · Corazón de Acero — Libro del juego', '/Author': 'Tony C. Ware',
                '/Subject': 'Memoria de diseño, instrucciones, atlas visual y arte de portada'})
w.compress_identical_objects(remove_identicals=True, remove_unreferenced=True)
out = HERE / 'VORTICE_5_Libro_del_juego.pdf'
with open(out, 'wb') as f: w.write(f)
print('páginas', len(order), out)
