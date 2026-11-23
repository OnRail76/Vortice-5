from canvas import C
import math
from tiles import T
def base_plate(rust=0,vent=False):
    c=C(16,16,'2'); c.rect(0,0,15,0,'3'); c.rect(0,0,0,15,'3'); c.rect(15,0,15,15,'1'); c.rect(0,15,15,15,'1')
    for x,y in [(2,1),(13,1),(2,13),(13,13)]: c.set(x,y,'.')
    if rust:
        for x,y in [(5,4),(6,4),(5,5),(9,9),(10,9),(10,10),(11,10),(4,11)]: c.set(x,y,'1')
    if vent:
        for y in range(4,12,2): c.rect(4,y,11,y,'.')
    return c
def crater_over(fill):
    # el mismo cráter redondo, pero encima del suelo (cristal, carne...): sin cuadrado alrededor
    c=C(16,16); r=crater_round()
    for y in range(16):
        for x in range(16):
            ch=r.p[y][x]
            c.p[y][x]=ch if ch!='.' else fill.p[y][x]
    c.ell(7.5,7.5,4.2,4.0,'.')
    for x,y in [(6,6),(9,8),(7,9)]: c.set(x,y,'1')
    return c
def girder():
    c=C(16,16,'.'); c.rect(0,0,15,1,'2'); c.rect(0,14,15,15,'2'); c.rect(0,1,15,1,'1');c.rect(0,15,15,15,'1')
    c.line(0,2,15,13,'1'); c.line(15,2,0,13,'1'); return c
def space(star=None):
    c=C(16,16,'.')
    if star: c.set(star[0],star[1],'3')
    return c
def coral(seed=0):
    c=C(16,16,'2')
    for y in range(16):
        for x in range(16):
            v=math.sin(x*1.3+seed)*math.cos(y*0.9+seed*2)+math.sin((x+y)*0.7)
            if v>1.1: c.set(x,y,'3')
            elif v<-1.0: c.set(x,y,'1')
    return c
def membrane():
    c=C(16,16,'.')
    for x in range(16):
        y=int(7+4*math.sin(x/16*2*math.pi)); c.set(x,y,'1'); c.set(x,y+1,'1')
        y2=int(3+2*math.sin(x/16*2*math.pi+1)); c.set(x,y2,'1')
    return c
def belt(ph=0):
    c=C(16,16,'2'); c.rect(0,0,15,1,'1'); c.rect(0,14,15,15,'1')
    for y in range(2,14):
        if (y+ph)%4==0: c.rect(0,y,15,y,'1')
    c.rect(0,0,0,15,'1'); c.rect(15,0,15,15,'1'); return c
def furnace():
    c=C(16,16,'1'); c.rect(2,2,13,13,'3')
    for x in range(3,13,3): c.rect(x,2,x,13,'.')
    return c
def crystal(v=0):
    c=C(16,16,'1')
    for i in range(-16,16,6):
        c.line(i+v,0,i+v+15,15,'2')
    for i in range(0,32,8):
        c.line(i-v,0,i-16-v,15,'3')
    return c
def flesh(v=0):
    c=C(16,16,'1')
    for y in range(16):
        for x in range(16):
            if (int(x*0.7+3*math.sin((y+v)/5*math.pi)))%5==0: c.set(x,y,'3')
    return c
def metal5():
    c=C(16,16,'2'); c.box(0,0,15,15,'1');
    for x,y in [(2,2),(13,2),(2,13),(13,13)]: c.set(x,y,'.')
    c.rect(5,7,10,8,'1'); return c
def edge(fill,side,seed=0):
    c=C(16,16,'.')
    for y in range(16):
        cut=int(5+3*math.sin(y*0.9+seed)+2*math.sin(y*2.3+seed*3))
        for x in range(16):
            inside = x>=cut if side=='L' else x<16-cut
            if inside: c.set(x,y,fill.p[y][x])
    return c
def T_(k): return C.rows(T[k])
def crater_round():
    # cráter redondo sobre el fondo: anillo de restos irregular, centro quemado
    c=C.rows('''
................
.....1..1.2.....
...1.211121.1...
..1221.....1221.
..21.........12.
.12...2..3....21
.1...1.2....2.1.
.2.3.........21.
.12........1..2.
.1..2..3.2....1.
..21..........2.
..1221.....1221.
...1.2111121.1..
.....1.2..1.....
................
................
''')
    return c
SETS={
1:dict(meta={' ':space(),'s':space((7,5)),'P':base_plate(),'R':base_plate(1),'V':base_plate(vent=True),'G':girder(),
            'L':edge(base_plate(1),'L',1),'J':edge(base_plate(),'R',2),'T':T_('torreta'),'C':T_('contenedor'),'K':T_('crater')},
    map=['  s    s','   LPRJ ','  LPVTPJ',' LRPPPRP','  GGGGGG','s LPTPRJ','  LPCPJ ','   LRJ s','s       ','   G  s ','  LPPJ  ',' LRTPRJ ']),
2:dict(meta={' ':space(),'m':membrane(),'C':coral(0),'D':coral(2),'L':edge(coral(1),'L',1),'J':edge(coral(3),'R',2),'T':T_('polipo_cerrado'),'O':T_('polipo_abierto'),'A':T_('bolsa_acida'),'K':T_('crater'),'k':crater_round()},
    map=['CJ    LC','CDJ  LDC','CJ mm LC','DCJ   LD','CCTJ  LC','DJ   LTD','CJ  A LC','CDJ   LD','COJ  LCC','CJ mm LD','DCJ  LCC','CJ   LDC']),
3:dict(meta={' ':space(),'B':belt(0),'b':belt(2),'P':base_plate(),'F':furnace(),'L':edge(base_plate(),'L',1),'J':edge(base_plate(),'R',2),'T':T_('torreta_cuadrada'),'S':T_('surtidor'),'Z':T_('surtidor_activo'),'K':T_('crater')},
    map=['PPJ  LPP','PFJ  LFP','BBBBBBBB','PJ    LP','PTJ  LTP','PJ    LP','bbbbbbbb','PPSJLZPP','PFP  PFP','PJ    LP','BBBBBBBB','PKJ  LTP']),
4:dict(meta={' ':space(),'s':space((4,9)),'X':crystal(0),'Y':crystal(3),'L':edge(crystal(1),'L',1),'J':edge(crystal(2),'R',2),'T':T_('cristal_torreta'),'E':T_('emisor_laser'),'K':T_('crater'),'k':crater_round(),'q':crater_over(crystal(0))},
    map=['s  LXJ  ','  LXYXJ ',' LXTYXJs','  LXYJ  ','s   E  s','  LYXJ  ',' LXYTXJ ','LXYXYXYJ','  s   s ','E LXJ  E','  LXYXJ ',' LXTXYJs']),
5:dict(meta={' ':space(),'F':flesh(0),'G':flesh(2),'M':metal5(),'L':edge(flesh(1),'L',1),'J':edge(flesh(3),'R',2),'T':T_('torreta_parasita'),'B':T_('bomba_bio'),'K':T_('crater'),'k':crater_round(),'q':crater_over(flesh(0))},
    map=['FGJ  LFG','FJ    LF','GMJ  LMG','FJ  B LF','GTJ   LG','FJ    LF','GFMJ LMF','FJ    LG','GJ  B LF','FTJ  LTG','GJ    LF','FMJ  LMG']),
}
def build(n):
    S=SETS[n]; c=C(128,192)
    for r,row in enumerate(S['map']):
        row=(row+' '*8)[:8]
        for k,ch in enumerate(row): c.paste(S['meta'][ch],k*16,r*16)
    return c
def charcount(c):
    s=set()
    for cy in range(0,c.h,8):
        for cx in range(0,c.w,4):
            s.add(tuple(tuple(c.p[y][x] for x in range(cx,cx+4)) for y in range(cy,cy+8)))
    return len(s)
def metacount(n):
    S=SETS[n]; tot=set()
    for m in S['meta'].values():
        for cy in (0,8):
            for cx in range(0,16,4): tot.add(tuple(tuple(m.p[y][x] for x in range(cx,cx+4)) for y in range(cy,cy+8)))
    return len(tot)
