; =====================================================================
;  screens.s · título, GAME OVER y victoria
; =====================================================================

; pantalla común de textos (DLT): 0 logo ANTIC7 (16), 1 ANTIC6 (16),
; 2..6 líneas ANTIC2 (32)
STAR0 = $A000                   ; estrellas por capa: 256 líneas repetidas (512 bytes) para
STAR1 = $A200                   ; leerlas con lda tabla+desplazamiento,y sin dar la vuelta.
STAR2 = $A400                   ; En las pantallas de texto esta RAM del juego está libre
RPX   = $A600                   ; puntos del barrido del radar (64 ángulos x 16)
RPY   = $AA00
RTOP  = 32+KRADAR               ; primera línea (scanline) del radar
RHPOS = 112                     ; P0..P3 uno al lado del otro, centrados

screen_mode:
        lda #0
        sta mode
        sta NMIEN
        jsr hide_pm
        jsr stars_init
        lda #<DLT
        sta SDLSTL
        lda #>DLT
        sta SDLSTH
        lda #$40                ; solo VBI hasta que el sistema haya puesto la display
        sta NMIEN               ; list de pantallas: si no, la DL del juego (con sus bits
        jsr wait_vbi            ; de DLI) dispararía el núcleo varias veces por cuadro
        jsr wait_vbi
        lda #<kernel
        sta VDSLST
        lda #>kernel
        sta VDSLST+1
        lda #$10                ; misiles = quinto player (estrellas en COLPF3)
        sta GPRIOR
        lda #2                  ; players por DMA (radar), misiles a mano (GRAFM)
        sta GRACTL
        lda #$C8                ; radar verde
        sta PCOLR0
        sta PCOLR1
        sta PCOLR2
        sta PCOLR3
        lda #$39                ; playfield estrecho, players de una línea
        sta SDMCTL
        lda #$C0
        sta NMIEN
        lda #$E0
        sta CHBAS
        lda #$00
        sta COLOR2
        sta COLOR4
        lda #$0C
        sta COLOR1
        lda #$36
        sta COLOR3
        ; borrar pantalla de textos
        lda #0
        tax
:       sta TSCR,x
        inx
        bne :-
        rts

hide_pm:
        lda #0
        ldx #7
:       sta HPOSP0,x
        dex
        bpl :-
        jsr clear_pm
        lda #0
        sta AUDC1
        sta AUDC2
        sta sfx1
        sta sfx2
        rts

; copia texto ptr0 (A bytes) a TSCR+X
put_text:
        sta tmp0
        stx tmp1
        ldy #0
:       lda (ptr0),y
        ldx tmp1
        sta TSCR,x
        inc tmp1
        iny
        cpy tmp0
        bne :-
        rts

; ptr0 <- dirección
.macro TXT addr, len, pos
        lda #<addr
        sta ptr0
        lda #>addr
        sta ptr0+1
        lda #len
        ldx #pos
        jsr put_text
.endmacro

; 6 dígitos BCD (dirección en ptr1) en TSCR+X, con desplazamiento de color A
put_score:
        sta tmp2
        stx tmp1
        ldy #2
:       lda (ptr1),y
        lsr
        lsr
        lsr
        lsr
        ora #$10
        ora tmp2
        ldx tmp1
        sta TSCR,x
        inc tmp1
        lda (ptr1),y
        and #$0F
        ora #$10
        ora tmp2
        ldx tmp1
        sta TSCR,x
        inc tmp1
        dey
        bpl :-
        rts

title:
        jsr screen_mode
        jsr radar_init
        TXT txt_logo, 16, 0
        TXT txt_sub, 16, 32
        TXT txt_style, 32, 64
        TXT txt_hi, 32, 160
        TXT txt_credit, 32, 192
        lda #<hi0
        sta ptr1
        lda #>hi0
        sta ptr1+1
        lda #0
        ldx #160+19
        jsr put_score
        jsr show_diff
        lda #TRK_TITLE
        jsr music_now
        ; soltar el botón
:       lda STRIG0
        beq :-
        lda #0
        sta dif_lock
        sta ch_idx
        lda #15
        sta ch_prev
@w:     lda frame
        and #32
        bne @off
        TXT txt_press, 32, 96
        jmp @chk
@off:   lda #0
        ldx #31
:       sta TSCR+96,x
        dex
        bpl :-
@chk:
:       lda VCOUNT              ; un cuadro por vuelta, con el haz ya por debajo del
        cmp #(32+KLINES)/2      ; núcleo: el radar nunca se ve a medio pintar
        bcc :-
        jsr radar_tick
        jsr diff_input
        jsr cheat_input
        php
:       lda VCOUNT              ; esperar a que empiece el cuadro siguiente
        cmp #(32+KLINES)/2
        bcs :-
        plp
        bcc :+
        jmp @w                  ; ese FIRE era el final del truco
:       lda STRIG0
        beq @go
        lda CONSOL
        and #1
        beq @go
        jmp @w
@go:    jsr music_fade_wait
        ; preparar juego
        lda #$40                ; fuera el núcleo de pantallas
        sta NMIEN
        lda #0
        sta GRAFM
        ldx #3
:       sta HPOSP0,x
        sta HPOSM0,x
        dex
        bpl :-
        lda #3
        sta GRACTL
        lda #$31
        sta GPRIOR
        lda #$3D
        sta SDMCTL
        lda #SHIP_C0
        sta PCOLR0
        lda #SHIP_C1
        sta PCOLR1
        lda #$00
        sta COLOR2
        sta COLOR4
        lda #$0A
        sta COLOR1
        lda #PF3_COLOR
        sta COLOR3
        rts

; selector: joystick izquierda/derecha o SELECT
diff_input:
        lda dif_lock
        beq @rd
        dec dif_lock
        rts
@rd:    lda STICK0
        and #$0C
        cmp #$0C
        beq @sel
        and #$04                ; bit a 0 = izquierda pulsada
        bne @right
        lda diff
        beq :+
        dec diff
        jmp @shw
:       lda #2
        sta diff
        jmp @shw
@right: inc diff
        lda diff
        cmp #3
        bcc @shw
        lda #0
        sta diff
        jmp @shw
@sel:   lda CONSOL
        and #2
        bne @r
        inc diff
        lda diff
        cmp #3
        bcc @shw
        lda #0
        sta diff
@shw:   lda #14
        sta dif_lock
        jmp show_diff
@r:     rts

show_diff:
        ldx diff
        lda txt_dif_lo,x
        sta ptr0
        lda txt_dif_hi,x
        sta ptr0+1
        lda #32
        ldx #128
        jmp put_text

title_vbi:
        lda frame               ; estrellas: tres capas a distinta velocidad (bajan)
        and #3
        bne :+
        dec so0
:       lda frame
        and #1
        bne :+
        dec so1
:       dec so2
        dec so2
        lda frame               ; logotipo: el brillo baja por las letras
        lsr
        and #15
        eor #15
        sta gph
        lda frame               ; y el tono va cambiando despacio
        lsr
        lsr
        and #$F0
        sta ghue
        rts

; ---------------------------------------------------------------------
;  Núcleo de las pantallas de texto (DLI de toda la pantalla, línea a
;  línea): estrellas con los misiles en las líneas vacías, degradado en
;  el logotipo, nada en las líneas de texto. Tipos en klt (generado).
; ---------------------------------------------------------------------
kernel:
        pha
        txa
        pha
        tya
        pha
        ldy #0
kl_l:     ldx klt,y
        beq kl_star
        dex
        beq kl_logo
        dex
        beq kl_kill
        sta WSYNC               ; 3: texto: solo esperar la línea (van justas de DMA)
        jmp kl_nx
kl_kill:
        lda #$36                ; 2: línea antes del texto: sin estrellas, PF3 rojo
        sta WSYNC
        sta COLPF3
        stx GRAFM               ; (X = 0)
        jmp kl_nx
kl_logo:  tya
        clc
        adc gph
        and #15
        tax
        lda kgrad,x
        ora ghue
        sta WSYNC
        sta COLPF0
        lda #0
        sta GRAFM
        jmp kl_nx
kl_star:                          ; los operandos se ajustan en cada VBI (desplazamiento)
ks0     = *
        lda STAR0,y
        sta kv0
ks1     = *
        lda STAR1,y
        sta kv1
ks2     = *
        lda STAR2,y
        sta WSYNC
        sta HPOSM2
        lda kv0
        sta HPOSM0
        lda kv1
        sta HPOSM1
        lda kstc,y
        sta COLPF3
        lda #$15                ; M0, M1 y M2 de un reloj de color de ancho
        sta GRAFM
kl_nx:    iny
        cpy #KLINES
        bne kl_l
        lda #0
        sta GRAFM
        pla
        tay
        pla
        tax
        pla
        rti

; estrellas al azar: lejanas (muchas), medias y cercanas (estela de 2 líneas)
stars_init:
        ldx #0
@s:     lda RANDOM
        cmp #44
        lda #0
        bcs :+
        lda RANDOM
        and #$7F
        clc
        adc #64
:       sta STAR0,x
        sta STAR0+256,x
        lda RANDOM
        cmp #24
        lda #0
        bcs :+
        lda RANDOM
        and #$7F
        clc
        adc #64
:       sta STAR1,x
        sta STAR1+256,x
        inx
        bne @s
@n:     lda RANDOM              ; cercanas: un par de líneas seguidas
        cmp #16
        lda #0
        bcs :+
        lda RANDOM
        and #$7F
        clc
        adc #64
:       sta STAR2,x
        sta STAR2+256,x
        inx
        sta STAR2,x
        sta STAR2+256,x
        inx
        bne @n
        rts

; ---------------------------------------------------------------------
;  Radar del título: aros fijos (rad_bmp) en P0..P3 y un barrido que gira
; ---------------------------------------------------------------------
radar_init:
        ldx #3                  ; posición de los cuatro players
        lda #RHPOS+24
:       sta HPOSP0,x
        sec
        sbc #8
        dex
        bpl :-
        lda #0
        ldx #3
:       sta SIZEP0,x
        dex
        bpl :-
        ; copiar los aros
        ldx #RAD_H-1
:       lda rad_bmp,x
        sta PMB+$400+RTOP,x
        lda rad_bmp+RAD_H,x
        sta PMB+$500+RTOP,x
        lda rad_bmp+RAD_H*2,x
        sta PMB+$600+RTOP,x
        lda rad_bmp+RAD_H*3,x
        sta PMB+$700+RTOP,x
        dex
        bpl :-
        ; puntos del barrido para los 64 ángulos (una vez)
        lda #0
        sta ra_a
@ang:   lda #$80                ; x = 15,5   y = 26,0 (8.8)
        sta ra_xl
        lda #15
        sta ra_xh
        lda #0
        sta ra_yl
        lda #26
        sta ra_yh
        lda ra_a
        asl
        asl
        asl
        asl
        sta ra_i                ; ángulo*16 (puntos 0..15)
        lda ra_a
        lsr
        lsr
        lsr
        lsr
        clc
        adc #>RPX
        sta ptr2+1              ; página de RPX (64*16 = 4 páginas)
        clc
        adc #(>RPY)-(>RPX)
        sta ptr3+1
        lda #0
        sta ptr2
        sta ptr3
        ldx ra_a
        ldy #16
        sty ra_n
        ldy ra_i
@pt:    lda ra_xl
        clc
        adc rad_dxl,x
        sta ra_xl
        lda ra_xh
        adc rad_dxh,x
        sta ra_xh
        sta (ptr2),y
        lda ra_yl
        clc
        adc rad_dyl,x
        sta ra_yl
        lda ra_yh
        adc rad_dyh,x
        sta ra_yh
        sta (ptr3),y
        iny
        dec ra_n
        bne @pt
        inc ra_a
        lda ra_a
        cmp #64
        bne @ang
        lda #0
        sta ra_a
        sta ra_on
        ldx #NBLIP-1
:       sta blip_t,x
        dex
        bpl :-
        rts

; cada 2 cuadros el barrido avanza: se borra el viejo (4 líneas: la de delante
; entera y una estela que se va aclarando) y se pintan los ecos y el nuevo
radar_tick:
        lda frame
        and #1
        beq :+
        jmp @blips
:       lda ra_on
        beq @new
        lda ra_a
        sta ra_b
        lda #0
        sta ra_op               ; 0 = borrar
        jsr sweep4
@new:   lda ra_a
        clc
        adc #1
        and #63
        sta ra_a
        ldx #NBLIP-1            ; ¿descubre algún eco?
@bl:    lda blip_a,x
        cmp ra_a
        bne @bn
        lda #100
        sta blip_t,x
@bn:    dex
        bpl @bl
        jsr @blips
        lda ra_a
        sta ra_b
        lda #1
        sta ra_op               ; 1 = pintar
        sta ra_on
        jmp sweep4
@blips: ldx #NBLIP-1            ; ecos: dos píxeles encendidos mientras dura su tiempo
@be:    lda blip_t,x
        beq @bnx
        dec blip_t,x
        stx ra_k
        php
        ldy blip_y,x
        lda blip_x,x
        tax
        plp
        beq @boff
        jsr px_on
        ldx ra_k
        ldy blip_y,x
        lda blip_x,x
        tax
        inx
        jsr px_on
        jmp @bk
@boff:  jsr px_off
        ldx ra_k
        ldy blip_y,x
        lda blip_x,x
        tax
        inx
        jsr px_off
@bk:    ldx ra_k
@bnx:   dex
        bpl @be
        rts

; las 4 líneas del barrido en el ángulo ra_b: dos enteras y dos punteadas
sweep4: lda #0
        sta ra_d
@d:     lda ra_b
        sec
        sbc ra_d
        and #63
        ldx ra_d
        ldy sw_step,x
        jsr sw_line
        inc ra_d
        lda ra_d
        cmp #2
        bne @d
        rts
sw_step: .byte 1,2
sw_cnt:  .byte 15,8

; una línea: ángulo A, paso Y (1 = todos los puntos)
sw_line:
        sty ra_st
        pha
        lsr
        lsr
        lsr
        lsr
        clc
        adc #>RPX
        sta ptr2+1
        clc
        adc #(>RPY)-(>RPX)
        sta ptr3+1
        lda #0
        sta ptr2
        sta ptr3
        pla
        asl
        asl
        asl
        asl
        ora #1                  ; el punto 0 está en el centro
        sta ra_i
        ldx ra_d
        lda sw_cnt,x
        sta ra_n                ; puntos que tocan con ese paso
@p:     ldy ra_i
        lda (ptr2),y
        tax
        lda (ptr3),y
        tay
        lda ra_op
        beq :+
        jsr px_on
        jmp :++
:       jsr px_off
:       lda ra_i
        clc
        adc ra_st
        sta ra_i
        dec ra_n
        bne @p
@r:     rts

; píxel X (0..31), Y (fila 0..52) del radar: encender / volver al dibujo de los aros
px_addr:
        txa
        lsr
        lsr
        lsr
        sta ra_c                ; columna (player)
        clc
        adc #>(PMB+$400)
        sta ptr1+1
        lda #RTOP
        sta ptr1
        txa
        and #7
        tax
        lda bitmsk,x
        rts
px_on:  jsr px_addr
        ora (ptr1),y
        sta (ptr1),y
        rts
px_off: jsr px_addr
        sta ra_m
        eor #$FF
        and (ptr1),y
        sta ra_v
        ldx ra_c                ; lo que haya en el dibujo fijo en ese bit
        tya
        clc
        adc rad_col,x
        tax
        lda rad_bmp,x
        and ra_m
        ora ra_v
        sta (ptr1),y
        rts
bitmsk: .byte $80,$40,$20,$10,$08,$04,$02,$01
rad_col: .byte 0,RAD_H,RAD_H*2,RAD_H*3
kstc:   .repeat 192, I
        .byte <(((I*7) & 6) + 6)    ; brillo de las estrellas por línea (grises 6..12)
        .endrep

game_over:
        jsr screen_mode
        jsr update_hi
        TXT txt_gameover, 16, 0
        TXT txt_score, 32, 64
        TXT txt_hi, 32, 160
        TXT txt_credit, 32, 192
        lda #<score
        sta ptr1
        lda #>score
        sta ptr1+1
        lda #0
        ldx #64+32+13
        jsr put_score
        lda #<hi0
        sta ptr1
        lda #>hi0
        sta ptr1+1
        lda #0
        ldx #160+19
        jsr put_score
        lda #TRK_GO
        jsr music_now
        ; esperar a que la música acabe sola (no se corta) y un poco más
:       jsr wait_vbi
        lda song_done
        beq :-
        lda #150
        jmp end_wait

victory_screen:
        jsr screen_mode
        jsr update_hi
        lda #0                  ; al acabar el juego se pierde el truco
        sta invuln
        TXT txt_victory, 16, 0
        TXT txt_victory2, 32, 64
        TXT txt_score, 32, 96
        TXT txt_credit, 32, 192
        lda #<score
        sta ptr1
        lda #>score
        sta ptr1+1
        lda #0
        ldx #128+13
        jsr put_score
        lda #TRK_TITLE
        jsr music_now
        ; al menos 4 segundos en pantalla
        ldx #240
:       jsr wait_vbi
        dex
        bne :-
        ; si se venía con FIRE apretado, no cuenta: primero hay que soltarlo
:       jsr wait_vbi
        lda STRIG0
        beq :-
        ; después, dos pulsaciones de FIRE para volver al título
        lda #2
        sta tmp6
@vw:    jsr wait_vbi
        lda frame
        and #32
        bne @voff
        TXT txt_fire2, 32, 160
        jmp @vchk
@voff:  lda #0
        ldx #31
:       sta TSCR+160,x
        dex
        bpl :-
@vchk:  lda STRIG0
        bne @vw
        lda #10                 ; pulsación contada
        sta sfx1
:       jsr wait_vbi            ; esperar a que se suelte
        lda STRIG0
        beq :-
        dec tmp6
        bne @vw
        jmp music_fade_wait

; ---------------------------------------------------------------------
;  Truco: arriba, arriba, abajo, abajo, izquierda, derecha y FIRE
;  -> BEEP y nave invencible hasta que se termine el juego
;  C=1 si el FIRE pulsado era el final del truco (no empieza la partida)
; ---------------------------------------------------------------------
cheat_input:
        lda STICK0
        cmp ch_prev
        beq @fire
        sta ch_prev
        cmp #15
        beq @fire
        ldx ch_idx
        cpx #6
        bcs @miss
        cmp ch_seq,x
        bne @miss
        inc ch_idx
        jmp @fire
@miss:  ldx #0
        cmp #14                 ; un "arriba" puede empezar la secuencia
        bne :+
        ldx #1
        lda ch_idx
        cmp #2
        bne :+
        ldx #2
:       stx ch_idx
@fire:  lda ch_idx
        cmp #6
        bne @no
        lda STRIG0
        bne @no
        lda #1
        sta invuln
        lda #0
        sta ch_idx
        lda #24
        sta beep_t
:       jsr wait_vbi
        lda STRIG0
        beq :-
        sec
        rts
@no:    clc
        rts

ch_seq: .byte 14,14,13,13,11,7

end_wait:
        sta tmp7
:       jsr wait_vbi
        lda tmp7
        cmp #180
        bcs @nk
        lda STRIG0              ; FIRE salta la espera pasado un momento
        beq @x
@nk:    dec tmp7
        bne :-
@x:     jmp music_fade_wait

update_hi:
        lda score+2
        cmp hi2
        bcc @r
        bne @set
        lda score+1
        cmp hi1
        bcc @r
        bne @set
        lda score
        cmp hi0
        bcc @r
@set:   lda score
        sta hi0
        lda score+1
        sta hi1
        lda score+2
        sta hi2
@r:     rts

        .segment "BSS"
dif_lock: .res 1
ch_idx: .res 1
ch_prev: .res 1
        .segment "CODE"

        .segment "BSS"
so0:    .res 1
so1:    .res 1
so2:    .res 1
gph:    .res 1
ghue:   .res 1
kv0:    .res 1
kv1:    .res 1
ra_a:   .res 1
ra_i:   .res 1
ra_n:   .res 1
ra_c:   .res 1
ra_m:   .res 1
ra_v:   .res 1
ra_on:  .res 1
ra_b:   .res 1
ra_op:  .res 1
ra_d:   .res 1
ra_st:  .res 1
ra_k:   .res 1
ra_xl:  .res 1
ra_xh:  .res 1
ra_yl:  .res 1
ra_yh:  .res 1
blip_t: .res 8
        .segment "CODE"
