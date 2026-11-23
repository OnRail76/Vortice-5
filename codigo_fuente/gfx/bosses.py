from canvas import C, disc, stroke, bez, A
W,H=112,56
BOSSES={}
def garra():
    c=C(W,H)
    # pinza (mitad izquierda) brazo superior
    stroke(c,[(44,14),(30,8),(16,10)],3.2,'2','1')
    stroke(c,bez((16,10),(2,24),(10,46)),3.4,'2','1')
    stroke(c,bez((10,46),(14,52),(24,48)),2.2,'2','1')   # punta garra
    stroke(c,bez((18,16),(14,30),(22,40)),2.0,'2','1')   # dedo interior
    for p in bez((16,10),(2,24),(10,46),8)[1:-1]: c.set(int(p[0]),int(p[1]),'1')  # segmentos
    disc(c,16,10,4,'1'); disc(c,16,10,2.5,'3'); c.set(16,10,'.')   # articulación = punto débil
    disc(c,30,8,2.5,'1'); c.set(30,8,'2')
    # hombro
    c.rect(36,10,46,22,'2'); c.box(36,10,46,22,'1'); c.rect(38,12,39,20,'1')
    for y in (13,16,19): c.set(42,y,'.');c.set(43,y,'.')
    # cuerpo central
    disc(c,56,22,20,'1'); disc(c,56,21,18.5,'2')
    for y in range(6,40,5):
        for x in range(46,56):
            if c.get(x,y)=='2': c.set(x,y,'1')
    c.rect(52,3,55,8,'1')
    disc(c,56,24,10,'1'); disc(c,56,24,8,'3'); disc(c,56,24,4,'1'); disc(c,56,24,2,'.')
    # escotilla inferior / propulsores
    c.rect(48,40,55,44,'1'); c.rect(50,45,52,49,'2'); c.rect(50,50,52,51,'3')
    return c.mirror()
def polipo():
    c=C(W,H)
    # tentáculos (mitad izq)
    for (p0,p1,p2) in [((44,20),(20,2),(4,12)),((42,26),(16,24),(2,34)),((44,32),(26,46),(10,52)),((48,36),(40,52),(30,55))]:
        pts=bez(p0,p1,p2,14)
        for i,(x,y) in enumerate(pts):
            r=2.8-i*0.13
            disc(c,x,y,r+1,'1'); 
        for i,(x,y) in enumerate(pts):
            r=2.8-i*0.13
            disc(c,x,y,r,'1' if i%3==0 else '2')
        c.set(int(pts[-1][0]),int(pts[-1][1]),'3')
    # cuerpo
    disc(c,56,24,22,'2'); 
    for y in range(4,46,4):
        for x in range(36,56,3):
            if c.get(x,y)=='2' and (x+y)%2==0: c.set(x,y,'1')
    disc(c,56,10,6,'1'); disc(c,56,10,4,'2')
    # bocas laterales
    disc(c,44,26,5,'1'); disc(c,44,26,3.5,'3'); disc(c,44,26,1.6,'.')
    # ojos
    for (x,y) in [(50,16),(47,20)]: disc(c,x,y,1.8,'3'); c.set(x,y,'.')
    # boca central (punto débil)
    disc(c,56,32,9,'1'); disc(c,56,33,7,'3'); disc(c,56,34,4.5,'.')
    for x in (52,54): c.rect(x,32,x,36,'2')
    c.rect(55,40,55,46,'3'); c.rect(53,41,53,44,'3')
    return c.mirror()
def horno():
    c=C(W,H)
    # columnas exteriores
    for x0 in (6,22):
        c.rect(x0,4,x0+9,46,'1'); c.rect(x0+1,4,x0+8,46,'2')
        for y in range(8,46,6): c.rect(x0,y,x0+9,y,'1')
        c.rect(x0+3,0,x0+6,3,'1'); c.rect(x0+3,47,x0+6,50,'1')
        c.rect(x0+3,24,x0+6,28,'3'); c.set(x0+4,26,'.')   # válvula
    # tuberías
    c.rect(15,14,22,16,'1'); c.rect(31,20,38,22,'1'); c.rect(15,34,22,36,'1');c.rect(31,38,38,40,'1')
    # cuerpo central
    c.rect(38,6,55,48,'1'); c.rect(40,8,55,46,'2')
    for y in range(10,46,4): c.rect(42,y,46,y,'1')
    c.rect(48,2,55,6,'1'); c.rect(50,0,55,2,'2')
    # boca de fuego (rejilla)
    c.rect(46,18,55,40,'1'); c.rect(48,20,55,38,'3')
    for y in range(22,38,3): c.rect(48,y,55,y,'1')
    disc(c,56,29,6,'.'); disc(c,56,29,4,'3'); disc(c,56,29,2,'.')
    c.rect(50,48,55,52,'1'); c.rect(52,53,55,55,'3')
    return c.mirror()
def prismarca():
    c=C(W,H)
    def cristal(cx,top,bot,hw,col='2',edge='1'):
        for y in range(top,bot+1):
            t=(y-top)/(bot-top); w=hw*(1-abs(t-0.45)*1.6)
            for x in range(int(cx-w),int(cx+w)+1): c.set(x,y,col)
            c.set(int(cx-w),y,edge); c.set(int(cx+w),y,edge)
        for y in range(top+2,bot-1,1): c.set(int(cx),y,'1' if col=='2' else '2')
    # alas cristalinas (abanico)
    for (cx,top,bot,hw) in [(6,10,46,4),(12,4,42,5),(20,0,36,5),(28,6,40,4)]: cristal(cx,top,bot,hw)
    # nodos (puntos débiles)
    for (x,y) in [(24,40),(38,6)]: disc(c,x,y,4,'1'); disc(c,x,y,2.6,'3'); c.set(x,y,'.')
    # brazo
    c.rect(30,22,44,28,'1'); c.rect(31,23,44,27,'2'); c.rect(32,25,43,25,'1')
    # núcleo: hexágono
    for y in range(6,46):
        t=abs(y-26)/20; w=int(14*(1-t*0.6))
        for x in range(56-w,57): c.set(x,y,'1' if x==56-w else '2')
    for y in range(12,40):
        t=abs(y-26)/14; w=int(8*(1-t*0.55))
        for x in range(56-w,57): c.set(x,y,'3')
    c.line(48,26,56,14,'1'); c.line(48,26,56,38,'1'); c.rect(50,26,56,26,'1')
    disc(c,56,26,3,'.')
    c.rect(54,0,55,5,'3'); c.rect(54,46,55,52,'3')
    return c.mirror()
def leviatan():
    c=C(W,H)
    # patas/costillas
    for k,(p0,p1,p2) in enumerate([((40,14),(20,2),(4,8)),((38,22),(14,16),(2,26)),((38,30),(14,34),(4,44)),((42,38),(24,50),(12,55)),((48,42),(42,54),(34,55))]):
        pts=bez(p0,p1,p2,14)
        stroke(c,pts,2.0,'2','1')
        for i,(x,y) in enumerate(pts):
            if i%3==1: disc(c,x,y,1.6,'1')
        c.set(int(pts[-1][0]),int(pts[-1][1]),'3')
    # caparazón
    disc(c,56,26,24,'1'); disc(c,56,26,22,'2')
    for r in (18,13):
        for y in range(H):
            for x in range(56):
                d=((x+.5-56)/(r/A+.5))**2+((y+.5-26)/r)**2
                if 0.86<d<=1 and c.get(x,y)=='2': c.set(x,y,'1')
    # nodos laterales (puntos débiles)
    disc(c,40,24,4.2,'1'); disc(c,40,24,3,'3'); c.set(40,24,'.')
    # ojo central
    disc(c,56,26,11,'1'); disc(c,56,26,9.5,'3'); disc(c,56,26,6,'2'); disc(c,56,26,4,'1'); disc(c,56,26,2.2,'.')
    for y in range(17,36): 
        if c.get(55,y)=='3': pass
    c.rect(54,0,55,3,'2')
    return c.mirror()
BOSS_DEF=[
 ('GARRA-9','Recolector de restos',garra,dict(BG=0x00,PF0=0x04,PF1=0x0A,PF2=0x36),['Articulación izq.','Articulación der.','Ojo-núcleo']),
 ('MADRE PÓLIPO','Órgano criogénico',polipo,dict(BG=0xB0,PF0=0x54,PF1=0xC8,PF2=0x46),['Boca izq.','Boca der.','Boca central']),
 ('HORNO OMEGA','Reactor de asedio',horno,dict(BG=0x00,PF0=0x22,PF1=0x08,PF2=0x3C),['4 válvulas','Rejilla','Boca de fuego']),
 ('EL PRISMARCA','Guardián de refracción',prismarca,dict(BG=0x70,PF0=0x64,PF1=0x9A,PF2=0x0E),['Nodos de las alas','Nodo superior','Prisma central']),
 ('LEVIATÁN V','Organismo central',leviatan,dict(BG=0x40,PF0=0x42,PF1=0x08,PF2=0x2C),['Nodo izq.','Nodo der.','Ojo central']),
]
