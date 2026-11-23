; =====================================================================
;  VÓRTICE 5 · Corazón de Acero
;  Shoot 'em up vertical para Atari 400/800/XL/XE (48 KB, NTSC)
;  Diseño, nombres, fases, gráficos y música por Tony C. Ware, adaptados con asistencia IA · 2026 Tony C. Ware
;  Ensamblador: ca65 (cc65).  Ver build.sh
; =====================================================================
        .include "hw.inc"

; medición de tiempos (solo en la versión de pruebas con -D PROF)
.macro PROF n
.ifdef PROF
        lda VCOUNT
        sta prof_v+n
        lda frame
        sta prof_f+n
.endif
.endmacro

; ---------------------------------------------------------------------
; Mapa de memoria en tiempo de ejecución (fuera del fichero cargado)
; ---------------------------------------------------------------------
CS_LVL  = $A000         ; charset de la fase (1 KB)
CS_BA   = $A400         ; charset jefe A
CS_BB   = $A800         ; charset jefe B
RING    = $AC00         ; 32 filas x 32 columnas (anillo de scroll)
PMB     = $B000         ; base PMG (resolución 1 línea)
MIS     = $B300
PL0     = $B400
PL1     = $B500
PL2     = $B600
PL3     = $B700
DLA     = $B800         ; display list juego A
DLB     = $B880         ; display list juego B
HUD     = $B900         ; 32 bytes marcador
DLT     = $B940         ; display list títulos
TAB_A   = $BA00         ; tablas DLI A (25 líneas x 16)
TAB_B   = $BC00         ; tablas DLI B
TSCR    = $BE00         ; pantalla de títulos: 8 x 32

; campos por línea en las tablas DLI
F_HP2 = 0
F_HP3 = 1
F_HM0 = 2
F_HM1 = 3
F_HM2 = 4
F_HM3 = 5
F_C2  = 6
F_C3  = 7
F_S2  = 8
F_S3  = 9
F_CH  = 10
F_MASK = 11            ; bits: 0 P2, 1 P3, 2 M0, 3 M1, 4 M2, 5 M3, 6 CHBASE

NOBJ  = 8               ; objetos aéreos
NSHOT = 6               ; disparos del jugador
NBUL  = 8               ; balas enemigas
NTGT  = 10              ; objetivos de suelo vivos
YOFF  = 32              ; las Y se guardan +32 (y=-32..223)
OBD   = 2               ; margen de líneas para los players (ver build)
PJD   = 3               ; margen de líneas para los misiles (ver build)
PMOFF = 41-YOFF         ; índice PMG = yb + 9 (línea en blanco tras el marcador)

T_CAP  = 10             ; tipo de objeto: cápsula P
T_EXP  = 11             ; tipo de objeto: explosión

; ---------------------------------------------------------------------
        .segment "ZEROPAGE"
tmp0:   .res 1
tmp1:   .res 1
tmp2:   .res 1
tmp3:   .res 1
tmp4:   .res 1
tmp5:   .res 1
tmp6:   .res 1
tmp7:   .res 1
ptr0:   .res 2
ptr1:   .res 2
ptr2:   .res 2
ptr3:   .res 2
dlik:   .res 1
dmask:  .res 1
fp_hp2: .res 2
fp_hp3: .res 2
fp_m0:  .res 2
fp_m1:  .res 2
fp_m2:  .res 2
fp_m3:  .res 2
fp_c2:  .res 2
fp_c3:  .res 2
fp_s2:  .res 2
fp_s3:  .res 2
fp_ch:  .res 2
fp_mk:  .res 2
fsel:   .res 1          ; 0/1 conjunto visible
ready:  .res 1          ; lógica terminada -> VBI cambia buffers
newfrm: .res 1          ; VBI ha cambiado buffers
frame:  .res 1
mode:   .res 1          ; 0 títulos, 1 juego
sector: .res 1          ; 0..4
lives:  .res 1
power:  .res 1          ; 1..3
score:  .res 3          ; BCD: [0]=decenas/unidades [1]=millares/centenas [2]=centenas de millar/decenas de millar
nextx:  .res 1          ; próxima vida extra (BCD de score+2)
hudchg: .res 1
ship_x: .res 1
ship_y: .res 1          ; yb
ship_f: .res 1          ; frame
sdead:  .res 1          ; >0: muerto (cuenta atrás)
sinv:   .res 1          ; >0: invulnerable
firet:  .res 1
joy:    .res 1
trig:   .res 1
top:    .res 1          ; fila del anillo arriba del todo
fine:   .res 1          ; 0..7
ssub:   .res 1
sstop:  .res 1          ; 1 = scroll parado
mapptr: .res 2          ; índice de fila del mapa (diccionario)
rowbase: .res 2         ; diccionario de filas del sector
rowp:   .res 2          ; fila actual
mrow:   .res 1
half:   .res 1
mapst:  .res 1          ; 0 mapa, 1 vacío, 2 filas de jefe
regy:   .res 1
mtp:    .res 2          ; metatiles del sector
mttgt:  .res 2
mtalt:  .res 2
mtcrat: .res 2
wavep:  .res 2
brow:   .res 1          ; siguiente fila de jefe a decodificar (6..0)
bstate: .res 1          ; 0 no,1 entrando,2 combate,3 muriendo,4 superado
bossy:  .res 1
bring6: .res 1
btimer: .res 1
bspawn: .res 1
bflash: .res 1
bwpleft:.res 1
cur_bk: .res 1
cur_p0: .res 1
cur_p1: .res 1
cur_p2: .res 1
basep2: .res 1
chlvl:  .res 1          ; CHBASE por defecto para el playfield
msgt:   .res 1          ; tiempo de mensaje en el marcador
; música / sonido
mus_on: .res 1
mus_p:  .res 1
mus_i:  .res 1
mus_t:  .res 1
mbass:  .res 2
mlead:  .res 2
lvol:   .res 1
sfx1:   .res 1
sfx2:   .res 1
sfx2k:  .res 1
pmmode: .res 1
; temporales propios del sonido (la VBI no puede pisar los del programa)
sptr:   .res 2
st4:    .res 1
st5:    .res 1
st6:    .res 1
st7:    .res 1

; ---------------------------------------------------------------------
        .segment "INITSEG"
; Se ejecuta durante la carga (INITAD): desactiva el BASIC de los XL/XE
; para tener RAM en $A000-$BFFF. En un 400/800 no tiene efecto.
init_basic:
        lda PORTB
        ora #$02
        sta PORTB
        lda #$C0
        sta $6A         ; RAMTOP
        rts

; ---------------------------------------------------------------------
        .segment "CODE"
start:
        jmp main

        .include "data.s"

; tablas de direcciones del anillo
ring_lo:
        .repeat 32, I
        .byte <(RING+I*32)
        .endrep
ring_hi:
        .repeat 32, I
        .byte >(RING+I*32)
        .endrep

; =====================================================================
main:
        sei
        lda PORTB               ; fuera BASIC (XL/XE): RAM en $A000-$BFFF
        ora #$02
        sta PORTB
        lda #$C0
        sta $6A
        lda #0
        sta NMIEN
        cld
        ldx #$FF
        txs
        ; limpiar página cero del juego
        lda #0
        ldx #$80
@zc:    sta $00,x
        inx
        bne @zc
        lda #0
        sta hi0
        sta hi1
        sta hi2
        lda #1                  ; dificultad por defecto: Normal
        sta diff
        lda #0
        sta invuln
        sta beep_t
        sta trk_req
        sta trk_cur
        sta sv_att
        sta song_done
        ; POKEY
        lda #3
        sta SKCTL
        lda #0
        sta AUDCTL
        ; PMG
        lda #>PMB
        sta PMBASE
        lda #3
        sta GRACTL
        lda #$31
        sta GPRIOR
        lda #0
        sta SIZEP0
        sta SIZEP1
        sta SIZEM
        ; VBI diferida
        lda #7
        ldy #<vbi
        ldx #>vbi
        jsr SETVBV
        ; VBI inmediata: durante la partida se salta el trabajo del sistema
        lda #6
        ldy #<vbi_imm
        ldx #>vbi_imm
        jsr SETVBV
        lda #<dli_hud_a
        sta VDSLST
        lda #>dli_hud_a
        sta VDSLST+1
        cli
        lda #$40
        sta NMIEN
        jsr build_dls
title_loop:
        jsr title
        jsr game
        jmp title_loop

; =====================================================================
;  VBI diferida
; =====================================================================
; ---------------------------------------------------------------------
; VBI inmediata. En pantallas sigue el camino normal del sistema (que luego
; llama a la VBI diferida). En partida copia a mano solo los registros que el
; juego necesita, lee el joystick y sale directamente: ahorra ~1.500 ciclos
; por cuadro y, de paso, el modo atracción no puede activarse.
; ---------------------------------------------------------------------
vbi_imm:
        lda mode
        bne :+
        jmp SYSVBV
:       lda COLOR0
        sta COLPF0
        lda COLOR1
        sta COLPF1
        lda COLOR2
        sta COLPF2
        lda COLOR3
        sta COLPF3
        lda COLOR4
        sta COLBK
        lda PCOLR0
        sta COLPM0
        lda PCOLR1
        sta COLPM1
        lda GPRIOR
        sta PRIOR
.ifdef NODMA
        lda #0                  ; (solo medición: sin DMA de vídeo)
.else
        lda SDMCTL
.endif
        sta DMACTL
        lda CHBAS
        sta CHBASE
        lda PORTA
        and #$0F
        sta STICK0
        lda TRIG0
        sta STRIG0
        ; sigue en la VBI del juego

vbi:
        lda #0
        sta ATRACT
        inc frame
        lda mode
        bne @game
        jsr title_vbi
        jmp @snd
@game:
        lda ready
        beq @nochg
        lda fsel
        eor #1
        sta fsel
        lda #0
        sta ready
        lda #1
        sta newfrm
@nochg:
        ; display list, DLI y scroll del conjunto visible
        ldx fsel
        lda dlih_lo,x
        sta VDSLST
        lda dlih_hi,x
        sta VDSLST+1
        lda dl_lo,x
        sta DLISTL
        sta SDLSTL
        lda dl_hi,x
        sta DLISTH
        sta SDLSTH
        lda vs_fine,x
        sta VSCROL
        lda shp_hx,x
        sta HPOSP0
        sta HPOSP1
        txa
        tay
        ldx #0
        cpy #0
        bne :+
        jsr TAB_A_load
        jmp @snd
:       jsr TAB_B_load
@snd:
        jsr sound
        jmp XITVBV

dlih_lo: .byte <dli_hud_a,<dli_hud_b
dlih_hi: .byte >dli_hud_a,>dli_hud_b
; --- parámetros por dificultad: Fácil, Normal, Hardcore
dif_lives: .byte 5,3,2
dif_safe:  .byte 60,44,30       ; no nacen balas tan cerca de la nave (líneas / color clocks)
dif_turr:  .byte 125,95,65      ; cadencia base de torretas
dif_wp:    .byte 30,0,<-18      ; ajuste de cadencia de los jefes
dif_bul:   .byte 5,6,8          ; balas enemigas a la vez como máximo
dl_lo:  .byte <DLA,<DLB
dl_hi:  .byte >DLA,>DLB

; =====================================================================
;  DLI
; =====================================================================
; tablas por campo: base + campo*32 + línea
.macro DLIHUD base, next
        pha
        lda #<next              ; primero: la DLI de la línea 0 puede llegar enseguida
        sta VDSLST
        lda #>next
        sta VDSLST+1
        lda #0                  ; índice en la lista de líneas con cambios
        sta dlik
        txa
        pha
        lda base+F_CH*32
        ldx cur_bk
        sta WSYNC
        stx COLBK
        sta CHBASE
        lda cur_p0
        sta COLPF0
        lda cur_p1
        sta COLPF1
        lda cur_p2
        sta COLPF2
        pla
        tax
        pla
        rti
.endmacro

.macro DLIPF base, list
        pha
        txa
        pha
        ldx dlik                ; solo hay DLI en las líneas con cambios:
        inc dlik                ; la lista dice qué línea toca
        lda list,x
        tax
        lda base+F_MASK*32,x
        beq @out
        sta dmask
        and #$40                ; ¿cambia CHBASE? (bit 6) Se escribe ANTES de WSYNC: ANTIC
        beq @nc                 ; toma CHBASE para la línea siguiente al acabar esta; si se
        lda base+F_CH*32,x      ; escribe después, la primera línea de la fila sale con el
        sta CHBASE              ; juego de caracteres del otro trozo del jefe (raya)
@nc:    sta WSYNC
        lsr dmask
        bcc @n2
        lda base+F_HP2*32,x
        sta HPOSP2
        lda base+F_C2*32,x
        sta COLPM2
        lda base+F_S2*32,x
        sta SIZEP2
@n2:    lsr dmask
        bcc @n3
        lda base+F_HP3*32,x
        sta HPOSP3
        lda base+F_C3*32,x
        sta COLPM3
        lda base+F_S3*32,x
        sta SIZEP3
@n3:    lsr dmask
        bcc @n4
        lda base+F_HM0*32,x
        sta HPOSM0
@n4:    lsr dmask
        bcc @n5
        lda base+F_HM1*32,x
        sta HPOSM1
@n5:    lsr dmask
        bcc @n6
        lda base+F_HM2*32,x
        sta HPOSM2
@n6:    lsr dmask
        bcc @n7
        lda base+F_HM3*32,x
        sta HPOSM3
@n7:
@out:   pla
        tax
        pla
        rti
.endmacro

; valores de la línea 0 (desde la VBI)
.macro DLILOAD base
        lda base+F_MASK*32
        sta dmask
        lsr dmask
        bcc @h2
        lda base+F_HP2*32
        sta HPOSP2
        lda base+F_C2*32
        sta COLPM2
        lda base+F_S2*32
        sta SIZEP2
        jmp @p3
@h2:    lda #0
        sta HPOSP2
@p3:    lsr dmask
        bcc @h3
        lda base+F_HP3*32
        sta HPOSP3
        lda base+F_C3*32
        sta COLPM3
        lda base+F_S3*32
        sta SIZEP3
        jmp @m0
@h3:    lda #0
        sta HPOSP3
@m0:    lda #0
        lsr dmask
        bcc :+
        lda base+F_HM0*32
:       sta HPOSM0
        lda #0
        lsr dmask
        bcc :+
        lda base+F_HM1*32
:       sta HPOSM1
        lda #0
        lsr dmask
        bcc :+
        lda base+F_HM2*32
:       sta HPOSM2
        lda #0
        lsr dmask
        bcc :+
        lda base+F_HM3*32
:       sta HPOSM3
        rts
.endmacro

dli_hud_a:  DLIHUD TAB_A, dli_pf_a
dli_hud_b:  DLIHUD TAB_B, dli_pf_b
dli_pf_a:   DLIPF TAB_A, lk_a
dli_pf_b:   DLIPF TAB_B, lk_b
TAB_A_load: DLILOAD TAB_A
TAB_B_load: DLILOAD TAB_B

; =====================================================================
;  Display lists
; =====================================================================
build_dls:
        ; juego A y B
        ldx #0
@d:     lda dl_proto,x
        sta DLA,x
        sta DLB,x
        inx
        cpx #dl_proto_end-dl_proto
        bne @d
        lda #<DLA
        sta DLA+83
        lda #>DLA
        sta DLA+84
        lda #<DLB
        sta DLB+83
        lda #>DLB
        sta DLB+84
        ; títulos
        ldx #0
@t:     lda dlt_proto,x
        sta DLT,x
        inx
        cpx #dlt_proto_end-dlt_proto
        bne @t
        rts

dl_proto:
        .byte $70,$70,$70
        .byte $C2,<HUD,>HUD
        .byte $00               ; 1 línea en blanco: margen para la DLI del marcador
        .repeat 24
        .byte $64,0,0           ; el bit de DLI se pone por cuadro donde hace falta
        .endrep
        .byte $44,0,0
        .byte $41,0,0
dl_proto_end:

dlt_proto:
        .byte $70,$70,$F0                   ; DLI: el núcleo de pantallas empieza en la línea siguiente
        .byte $70
        .byte $47,<(TSCR+0),>(TSCR+0)       ; logotipo (degradado por línea)
        .byte $30
        .byte $46,<(TSCR+32),>(TSCR+32)     ; subtítulo
        .byte $70
        .byte $70,$70,$70,$70,$70,$70,$70   ; zona del radar (56 líneas)
        .byte $50
        .byte $42,<(TSCR+64),>(TSCR+64)
        .byte $50
        .byte $42,<(TSCR+96),>(TSCR+96)
        .byte $30
        .byte $42,<(TSCR+128),>(TSCR+128)
        .byte $50
        .byte $42,<(TSCR+160),>(TSCR+160)
        .byte $30
        .byte $42,<(TSCR+192),>(TSCR+192)
        .byte $70
        .byte $41,<DLT,>DLT
dlt_proto_end:

; LMS de la DL trasera según 'top'
set_lms:
        lda fsel                ; solo si 'top' ha cambiado para esa display list
        eor #1
        tax
        lda top
        cmp lms_top,x
        bne :+
        rts
:       sta lms_top,x
        lda fsel
        bne @a                  ; visible B -> trasera A
        lda #<DLB
        sta ptr0
        lda #>DLB
        sta ptr0+1
        jmp @go
@a:     lda #<DLA
        sta ptr0
        lda #>DLA
        sta ptr0+1
@go:    ldy #8
        ldx top
        lda #25
        sta tmp0
@l:     lda ring_lo,x
        sta (ptr0),y
        iny
        lda ring_hi,x
        sta (ptr0),y
        iny
        iny
        inx
        txa
        and #31
        tax
        dec tmp0
        bne @l
        rts

; =====================================================================
;  Sincronía de cuadro
; =====================================================================
wait_vbi:
        lda frame
@w:     cmp frame
        beq @w
        rts

; =====================================================================
;  PARTIDA
; =====================================================================
game:
        lda #0
        sta NMIEN
        sta score
        sta score+1
        sta score+2
        sta sector
        lda #$02
        sta nextx
        ldx diff
        lda dif_lives,x
        sta lives
        lda #1
        sta power
        lda #0
        sta gover
        sta victory
        jsr clear_pm
        jsr level_init
        jsr fill_screen
        jsr prime
        lda #1
        sta mode
        lda #$C0
        sta NMIEN
@loop:
        ; esperar a que la VBI muestre el cuadro preparado
@w:     lda newfrm
        beq @w
        lda #0
        sta newfrm
        inc loopcnt             ; (solo para medir: vueltas de la lógica)
        PROF 0
        jsr pm_draw             ; dibujar sprites del cuadro visible
        PROF 1
        jsr logic               ; lógica del cuadro siguiente
        PROF 13
        lda gover
        bne @over
        lda victory
        bne @vict
        jsr build               ; tablas DLI + listas de dibujo (traseras)
        PROF 14
        jsr set_lms
        PROF 15
.ifdef PROF
        ldx #31                 ; copia de una vuelta completa, para medir
:       lda prof_v,x
        sta prof_lv,x
        dex
        bpl :-
.endif
        lda fsel
        eor #1
        tax
        lda fine
        sta vs_fine,x
        lda ship_x
        clc
        adc #64
        sta shp_hx,x
        lda #1
        sta ready
        jmp @loop
@over:  jsr music_fade_wait
        jsr game_over
        rts
@vict:  jsr music_fade_wait
        jsr victory_screen
        rts

; prepara los dos conjuntos de buffers antes de encender las DLI
prime:
        lda #0
        sta lk_na
        sta lk_nb
        lda #$FF
        sta lms_top
        sta lms_top+1
        sta ch_top
        lda #0
        sta fsel
        sta ready
        sta newfrm
        lda #60
        sta ship_x
        lda #YOFF+164
        sta ship_y
        lda #0
        sta sdead
        lda #120
        sta sinv
        jsr prime1
        lda #1
        sta fsel
        jsr prime1
        inc bgen                ; el segundo conjunto no llega a pintarse
        inc bgen
        lda #0
        ldx #NOBJ-1
:       sta kp,x
        dex
        bpl :-
        lda #1
        sta newfrm
        rts
prime1:
        jsr build
        jsr set_lms
        lda fsel
        eor #1
        tax
        lda fine
        sta vs_fine,x
        lda ship_x
        clc
        adc #64
        sta shp_hx,x
        rts

; ---------------------------------------------------------------------
; Inicio de sector: charset, paleta, mapa, oleadas, pantalla llena
; ---------------------------------------------------------------------
level_init:
        ldx sector
        ; copiar charset del sector a CS_LVL
        lda sec_charset_lo,x
        sta ptr0
        lda sec_charset_hi,x
        sta ptr0+1
        lda sec_chars,x
        jsr copy_charset_lvl
        ldx sector
        lda sec_bg,x
        sta cur_bk
        lda sec_pf0,x
        sta cur_p0
        lda sec_pf1,x
        sta cur_p1
        lda sec_pf2,x
        sta cur_p2
        sta basep2
        lda #>CS_LVL
        sta chlvl
        lda sec_mt_lo,x
        sta mtp
        lda sec_mt_hi,x
        sta mtp+1
        lda sec_mt_tgt_lo,x
        sta mttgt
        lda sec_mt_tgt_hi,x
        sta mttgt+1
        lda sec_mt_alt_lo,x
        sta mtalt
        lda sec_mt_alt_hi,x
        sta mtalt+1
        lda sec_mt_crat_lo,x
        sta mtcrat
        lda sec_mt_crat_hi,x
        sta mtcrat+1
        lda sec_map_lo,x
        sta mapptr
        lda sec_map_hi,x
        sta mapptr+1
        lda sec_rows_lo,x
        sta rowbase
        lda sec_rows_hi,x
        sta rowbase+1
        lda sec_waves_lo,x
        sta wavep
        lda sec_waves_hi,x
        sta wavep+1
        lda #0
        sta mrow
        sta mapst
        sta bstate
        sta sstop
        sta ssub
        lda #1
        sta half
        ; vaciar objetos
        jsr clear_objects
        lda #110
        sta msgt
        jsr hud_sector
        ; música del sector
        lda #TRK_PHASE          ; Heart of Steel (entra con fundido)
        jsr music_request
        rts

; primer llenado de la pantalla (25 filas) — solo al empezar la partida
fill_screen:
        lda #0
        sta fine
        lda #24
        sta top
        lda #25
        sta tmp7
@f:     ldx #0
@s:     lda tg_type,x
        beq @n
        lda tg_y,x
        clc
        adc #8
        sta tg_y,x
@n:     inx
        cpx #NTGT
        bne @s
        lda top
        sec
        sbc #1
        and #31
        sta top
        lda #YOFF-8
        sta regy
        lda top
        jsr decode_row
        dec tmp7
        bne @f
        ; fila siguiente por adelantado
        lda #YOFF-16
        sta regy
        lda top
        sec
        sbc #1
        and #31
        jsr decode_row
        rts

; ptr0 = origen, A = nº de caracteres
copy_charset_lvl:
        ldx #>CS_LVL
copy_cs:
        stx ptr1+1
        ldx #0
        stx ptr1
        sta tmp0                ; caracteres
        ; bytes = A*8 -> copiar tmp0 bloques de 8
@c:     ldy #7
@b:     lda (ptr0),y
        sta (ptr1),y
        dey
        bpl @b
        lda ptr0
        clc
        adc #8
        sta ptr0
        bcc :+
        inc ptr0+1
:       lda ptr1
        clc
        adc #8
        sta ptr1
        bcc :+
        inc ptr1+1
:       dec tmp0
        bne @c
        rts

clear_objects:
        ldx #NOBJ-1
        lda #$FF
@o:     sta ob_type,x
        dex
        bpl @o
        lda #0
        ldx #NOBJ-1
:       sta ob_hid,x
        dex
        bpl :-
        ldx #NBUL-1
:       sta bu_hid,x
        dex
        bpl :-
        lda #0
        ldx #NSHOT-1
@s:     sta sh_y,x
        dex
        bpl @s
        sta sh_head
        ldx #NBUL-1
@b:     sta bu_y,x
        dex
        bpl @b
        ldx #NTGT-1
@t:     sta tg_type,x
        dex
        bpl @t
        sta sp_left
        sta sp_left+1
        rts

clear_pm:
        lda #0
        tax
@c:     sta MIS,x
        sta PL0,x
        sta PL1,x
        sta PL2,x
        sta PL3,x
        inx
        bne @c
        stx er_n
        stx me_n
        inc bgen                ; nada de lo apuntado sigue pintado
        inc bgen
        ldx #NOBJ-1
:       sta lr_pg,x             ; (A = 0)
        dex
        bpl :-
        sta shp_idx
        rts

        .include "engine.s"
        .include "objects.s"
        .include "boss.s"
        .include "screens.s"
        .include "sound.s"

; ---------------------------------------------------------------------
        .segment "BSS"
diff:   .res 1
lms_top: .res 2
lk_a:   .res 24
lk_b:   .res 24
prof_v: .res 16
prof_f: .res 16
prof_lv: .res 16
prof_lf: .res 16
loopcnt: .res 1
invuln: .res 1
hi0:    .res 1
hi1:    .res 1
hi2:    .res 1
gover:  .res 1
victory:.res 1
vs_fine:.res 2
shp_hx: .res 2
; objetos aéreos
ob_type:.res NOBJ
ob_x:   .res NOBJ
ob_y:   .res NOBJ
ob_xf:  .res NOBJ
ob_yf:  .res NOBJ
ob_vx:  .res NOBJ
ob_vy:  .res NOBJ
ob_vyh: .res NOBJ
ob_x0:  .res NOBJ
ob_hp:  .res NOBJ
ob_t:   .res NOBJ
ob_p:   .res NOBJ
ob_fl:  .res NOBJ
ob_drop:.res NOBJ
; disparos
sh_x:   .res NSHOT
sh_y:   .res NSHOT
sh_m:   .res NSHOT
; balas
bu_x:   .res NBUL
bu_xf:  .res NBUL
bu_y:   .res NBUL
bu_yf:  .res NBUL
bu_vxl: .res NBUL
bu_vxh: .res NBUL
bu_vyl: .res NBUL
bu_vyh: .res NBUL
; objetivos de suelo
tg_type:.res NTGT
tg_col: .res NTGT
tg_y:   .res NTGT
tg_ring:.res NTGT
tg_hp:  .res NTGT
tg_mt:  .res NTGT
tg_t:   .res NTGT
; generadores de oleada (2)
sp_left:.res 2
sp_type:.res 2
sp_x:   .res 2
sp_itv: .res 2
sp_t:   .res 2
sp_p:   .res 2
sp_drop:.res 2
sp_i:   .res 2
; listas de dibujo (2 conjuntos x 8)
dw_pg:  .res 16
dw_ix:  .res 16
dw_h:   .res 16
dw_gl:  .res 16
dw_gh:  .res 16
dw_n:   .res 2
er_pg:  .res 8
er_ix:  .res 8
er_h:   .res 8
er_n:   .res 1
; misiles (2 conjuntos x 16)
md_ix:  .res 32
md_h:   .res 32
md_m:   .res 32
md_n:   .res 2
me_ix:  .res 16
me_h:   .res 16
me_n:   .res 1
; nave (por conjunto)
sh_vis: .res 2
sh_ix:  .res 2
sh_fr:  .res 2
shp_idx:.res 1
sh_head:.res 1
; multiplexor
mx_ord: .res NOBJ
mx_cnt: .res 1
mx_lastb: .res 6
mx_lastk: .res 6
; jefe: puntos débiles
wp_x:   .res 5
wp_y:   .res 5
wp_w:   .res 5
wp_h:   .res 5
wp_hp:  .res 5
wp_core:.res 5
wp_t:   .res 5
wp_n:   .res 1
