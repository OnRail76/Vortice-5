; =====================================================================
;  engine.s · lógica principal, scroll, decodificación, multiplexor, PMG
; =====================================================================

logic:
        jsr read_input
        jsr ship_update
        jsr shots_update
        PROF 2
        jsr scroll_update
        PROF 3
        jsr waves_update
        jsr objects_update
        PROF 4
        jsr targets_update
        PROF 5
        jsr bullets_update
        PROF 6
        jsr collisions
        PROF 7
        jsr boss_update
        PROF 8
        jsr hud_update
        PROF 9
        rts

read_input:
        lda STICK0
        eor #$0F
        and #$0F
        sta joy
        lda STRIG0
        eor #1
        sta trig
        lda CONSOL              ; START también dispara (comodidad)
        and #1
        bne :+
        lda #1
        sta trig
:       rts

; ---------------------------------------------------------------------
;  Nave
; ---------------------------------------------------------------------
ship_update:
        lda sdead
        beq @alive
        dec sdead
        bne @r
        lda lives
        bne @resp
        lda #1
        sta gover
@r:     rts
@resp:  lda #60
        sta ship_x
        lda #YOFF+164
        sta ship_y
        lda #150
        sta sinv
        lda #1
        sta power
        lda #1
        sta hudchg
        rts
@alive:
        lda sinv
        beq :+
        dec sinv
:       ; movimiento
        ldx #0                  ; frame
        lda joy
        and #4                  ; izquierda
        beq @nl
        lda ship_x
        cmp #2
        bcc @nl0
        sbc #2
        sta ship_x
@nl0:   ldx #1
@nl:    lda joy
        and #8
        beq @nr
        lda ship_x
        cmp #119
        bcs @nr0
        adc #2
        sta ship_x
@nr0:   ldx #2
@nr:    lda joy
        and #1
        beq @nu
        lda ship_y
        cmp #YOFF+12
        bcc @nu
        sbc #2
        sta ship_y
@nu:    lda joy
        and #2
        beq @nd
        lda ship_y
        cmp #YOFF+174
        bcs @nd
        adc #2
        sta ship_y
@nd:    cpx #0
        bne @sf
        lda frame
        and #4
        beq @sf
        ldx #3                  ; llama alterna
@sf:    stx ship_f
        ; disparo
        lda firet
        beq :+
        dec firet
        rts
:       lda trig
        bne :+
        rts
:       lda power
        cmp #3
        bne :+
        lda #5
        bne @ft
:       lda #8
@ft:    sta firet
        lda power
        cmp #1
        bne @two
        lda ship_x
        clc
        adc #3
        ldy #0
        jsr new_shot
        jmp @snd
@two:   lda ship_x
        clc
        adc #1
        ldy #0
        jsr new_shot
        lda ship_x
        clc
        adc #6
        ldy #1
        jsr new_shot
@snd:   lda #8
        sta sfx1
        rts

; A = x, Y = misil
; los disparos se reparten en anillo: recorridos desde sh_head salen ya
; ordenados de arriba abajo (el más viejo es el más alto)
new_shot:
        sta tmp0
        sty tmp1
        ldx sh_head
        lda sh_y,x
        beq @ok
        rts
@ok:    inx
        cpx #NSHOT
        bcc :+
        ldx #0
:       stx sh_head
        ldx sh_head
        dex
        bpl :+
        ldx #NSHOT-1
:       lda tmp0
        sta sh_x,x
        lda tmp1
        sta sh_m,x
        lda ship_y
        sec
        sbc #4
        sta sh_y,x
        rts

shots_update:
        ldx #NSHOT-1
@l:     lda sh_y,x
        beq @n
        cmp #YOFF+1
        bcc @kill
        sbc #6
        sta sh_y,x
        jmp @n
@kill:  lda #0
        sta sh_y,x
@n:     dex
        bpl @l
        rts

; ---------------------------------------------------------------------
;  Scroll
; ---------------------------------------------------------------------
scroll_update:
        lda sstop
        beq :+
        rts
:       lda ssub
        eor #1
        sta ssub
        beq :+
        rts
:       dec fine
        bpl @shift
        lda #7
        sta fine
        lda top
        sec
        sbc #1
        and #31
        sta top
        lda #YOFF-23
        sta regy
        lda top
        sec
        sbc #1
        and #31
        jsr decode_row
@shift: ; el suelo baja una línea
        ldx #NTGT-1
@t:     lda tg_type,x
        beq @tn
        inc tg_y,x
        lda tg_y,x
        cmp #YOFF+200
        bcc @tn
        lda #0
        sta tg_type,x
@tn:    dex
        bpl @t
        lda bstate
        cmp #1
        bne @r
        lda bossy
        beq @r
        inc bossy
        lda bossy
        cmp #YOFF+14
        bne @r
        jsr boss_fight_start
@r:     rts

; ---------------------------------------------------------------------
;  Decodifica la siguiente fila de caracteres en la fila A del anillo
; ---------------------------------------------------------------------
decode_row:
        sta tmp6
        tax
        lda ring_lo,x
        sta ptr1
        lda ring_hi,x
        sta ptr1+1
        lda mapst
        beq @map
        cmp #2
        bne @blank
        jmp @boss
@blank: lda #0
        ldy #31
@b:     sta (ptr1),y
        dey
        bpl @b
        rts
@map:   ldy #0                  ; fila = diccionario + índice*8
        sty rowp+1
        lda (mapptr),y
        asl
        rol rowp+1
        asl
        rol rowp+1
        asl
        rol rowp+1
        clc
        adc rowbase
        sta rowp
        lda rowp+1
        adc rowbase+1
        sta rowp+1
        lda #0
        sta tmp5                ; columna
@col:   ldy tmp5
        lda (rowp),y
        sta tmp4                ; metatile
        asl
        asl
        asl
        ldx half
        beq :+
        ora #4
:       tay
        lda (mtp),y
        sta tmp0
        iny
        lda (mtp),y
        sta tmp1
        iny
        lda (mtp),y
        sta tmp2
        iny
        lda (mtp),y
        sta tmp3
        lda tmp5
        asl
        asl
        tay
        lda tmp0
        sta (ptr1),y
        iny
        lda tmp1
        sta (ptr1),y
        iny
        lda tmp2
        sta (ptr1),y
        iny
        lda tmp3
        sta (ptr1),y
        lda half
        beq @nt
        ldy tmp4
        lda (mttgt),y
        beq @nt
        jsr reg_target
@nt:    inc tmp5
        lda tmp5
        cmp #8
        bne @col
        ; siguiente media fila
        lda half
        beq @next
        lda #0
        sta half
        rts
@next:  lda #1
        sta half
        inc mapptr
        bne :+
        inc mapptr+1
:       inc mrow
        lda mrow
        cmp #MAPLEN
        bne :+
        jsr boss_begin
:       rts
@boss:  ; filas del jefe (de abajo arriba) y después vacío
        lda brow
        bpl :+
        jmp @blank
:       ldx sector
        lda boss_scr_lo,x
        sta ptr0
        lda boss_scr_hi,x
        sta ptr0+1
        ldx brow
        beq @bz
@bm:    lda ptr0
        clc
        adc #28
        sta ptr0
        bcc :+
        inc ptr0+1
:       dex
        bne @bm
@bz:    lda #0
        ldy #0
        sta (ptr1),y
        iny
        sta (ptr1),y
        ldy #30
        sta (ptr1),y
        iny
        sta (ptr1),y
        ; copiar 28 bytes: origen y, destino y+2
        lda ptr1
        clc
        adc #2
        sta ptr2
        lda ptr1+1
        adc #0
        sta ptr2+1
        ldy #27
@bc:    lda (ptr0),y
        sta (ptr2),y
        dey
        bpl @bc
        lda brow
        cmp #6
        bne :+
        lda tmp6
        sta bring6
:       lda brow
        bne :+
        lda regy
        clc
        adc #8
        sta bossy
:       dec brow
        rts

; registra un objetivo de suelo: tmp5 = columna, tmp4 = metatile, A = tipo
reg_target:
        sta tmp7
        ldx #NTGT-1
@f:     lda tg_type,x
        beq @ok
        dex
        bpl @f
        rts
@ok:    lda tmp7
        sta tg_type,x
        tay
        lda tt_hp,y
        sta tg_hp,x
        lda tmp5
        sta tg_col,x
        lda tmp4
        sta tg_mt,x
        lda regy
        sta tg_y,x
        lda tmp6
        sec
        sbc #1
        and #31
        sta tg_ring,x
        lda RANDOM
        and #63
        adc #40
        sta tg_t,x
        rts

; escribe el metatile A en el objetivo X (8 caracteres en el anillo)
tg_write:
        sta tg_mt,x
        stx tw_x
        asl
        asl
        asl
        sta tmp0                ; offset en la tabla de metatiles
        lda tg_col,x
        asl
        asl
        sta tmp1                ; offset en la fila
        lda tg_ring,x
        sta tmp2
        tax
        lda ring_lo,x
        sta ptr2
        lda ring_hi,x
        sta ptr2+1
        jsr @four
        lda tmp2
        clc
        adc #1
        and #31
        tax
        lda ring_lo,x
        sta ptr2
        lda ring_hi,x
        sta ptr2+1
        jsr @four
        ldx tw_x
        rts
@four:  lda #4
        sta tmp3
@c:     ldy tmp0
        lda (mtp),y
        ldy tmp1
        sta (ptr2),y
        inc tmp0
        inc tmp1
        dec tmp3
        bne @c
        dec tmp1
        dec tmp1
        dec tmp1
        dec tmp1
        rts

; =====================================================================
;  Construcción del cuadro trasero: multiplexor y listas de dibujo
; =====================================================================
; apunta en el canal X (se conserva) el objeto mx_k/mx_start/mx_hyb
.macro CHAN_ADD
        txa
        asl
        asl
        asl
        clc
        adc as_n,x
        tay
        lda mx_k
        sta as_k,y
        sta as_lk,x
        lda mx_start
        sta as_s,y
        lda mx_hyb
        sta as_b,y
        sta as_lb,x
        inc as_n,x
        lda mx_pass             ; puesto fuera de orden (turno): el canal ya no va ordenado
        bne :+
        lda #1
        sta as_mix,x
:
.endmacro

build:
        lda fsel
        eor #1
        sta tmp7                ; conjunto trasero
        inc bgen                ; generación de esta construcción
        lda #0
        .repeat NOBJ, I
        sta kp+I
        .endrep
        lda tmp7
        ; --- nave
        tax
        lda #0
        sta sh_vis,x
        lda sdead
        bne @noship
        lda sinv
        beq @vis
        lda frame
        and #4
        bne @noship
@vis:   lda #1
        sta sh_vis,x
@noship:
        lda ship_y
        clc
        adc #PMOFF
        sta sh_ix,x
        lda ship_f
        sta sh_fr,x
        ; --- punteros a las tablas traseras y limpieza de la máscara
        lda tmp7                ; (desenrollado: constantes de cada conjunto)
        beq @fpa
        jmp @fpb
@fpa:
        .repeat 12, F
        lda #<(TAB_A+F*32)
        sta fp_hp2+F*2
        lda #>(TAB_A+F*32)
        sta fp_hp2+F*2+1
        .endrep
        lda #0
        .repeat 25, L
        sta TAB_A+F_MASK*32+L
        .endrep
        jmp @fpd
@fpb:
        .repeat 12, F
        lda #<(TAB_B+F*32)
        sta fp_hp2+F*2
        lda #>(TAB_B+F*32)
        sta fp_hp2+F*2+1
        .endrep
        lda #0
        .repeat 25, L
        sta TAB_B+F_MASK*32+L
        .endrep
@fpd:
        lda #0
        ldx #5
@cl2:   sta as_n,x
        sta as_mix,x
        dex
        bpl @cl2
        ; --- ordenar objetos por y (inserción)
        ldy #0
        ldx #0
@co:    lda ob_type,x
        cmp #$FF
        beq @cn
        txa
        sta mx_ord,y
        iny
@cn:    inx
        cpx #NOBJ
        bne @co
        sty mx_cnt
        cpy #2
        bcc @sorted
        ldx #1
@s1:    lda mx_ord,x
        sta tmp0
        tay
        lda ob_y,y
        sta tmp1
        txa
        tay
@s2:    dey
        bmi @s3
        lda mx_ord,y
        sty tmp2
        tay
        lda ob_y,y
        ldy tmp2
        cmp tmp1
        bcc @s3
        beq @s3
        lda mx_ord,y
        sta mx_ord+1,y
        jmp @s2
@s3:    iny
        lda tmp0
        sta mx_ord,y
        inx
        cpx mx_cnt
        bne @s1
@sorted:
        ; --- asignar players 2/3
        ldx tmp7
        lda dset8,x
        sta dwbase
        sta dwptr
        ; dos pasadas: primero los que el cuadro anterior se quedaron sin
        ; dibujar (así, si hay más de dos en una franja, se turnan)
        ldx #NOBJ-1             ; prioridad fijada al empezar (no cambia entre pasadas)
:       lda ob_hid,x
        sta ob_pri,x
        dex
        bpl :-
        lda #0
        sta mx_pass
        ldx #NOBJ-1             ; ¿alguien con turno pendiente?
:       lda ob_pri,x
        bne @opass
        dex
        bpl :-
        inc mx_pass
@opass: lda #0
        sta mx_i
@ol:    lda mx_i
        cmp mx_cnt
        bne :+
        jmp @odone
:       tax
        lda mx_ord,x
        tax
        stx mx_obj
        lda ob_pri,x
        eor mx_pass
        bne :+
        jmp @onext              ; no le toca en esta pasada
:       lda ob_type,x
        tay
        lda ot_h,y
        sta mx_h
        ; visible?
        lda ob_y,x
        cmp #YOFF+192
        bcc :+
        lda #0
        sta ob_hid,x
        jmp @onext
:       clc
        adc mx_h
        cmp #YOFF+1
        bcs :+
        lda #0
        sta ob_hid,x
        jmp @onext
:       sta mx_hyb
        lda ob_y,x              ; línea de la display list (en línea, sin JSR): la de la
        sec                     ; franja que empieza al menos OBD líneas antes (la DLI
        sbc #YOFF+OBD           ; puede escribir los registros con la línea ya empezada)
        bcs @kp
        lda #0
        sta mx_k
        beq @k0
@kp:    clc
        adc fine
        lsr
        lsr
        lsr
        cmp #25
        bcc :+
        lda #24
:       sta mx_k
        beq @k0
        asl
        asl
        asl
        clc
        adc #YOFF
        sec
        sbc fine
@k0:    sta mx_start
        ; elegir player (alterna preferencia por cuadro)
        lda ob_lp,x             ; mismo player que el cuadro anterior (borrado parcial)
        and #1
        sta mx_p
        lda #2
        sta pj_cnt
@try:   lda mx_p
        clc
        adc #4
        tax
        lda mx_pass
        beq @tslow
        lda as_mix,x
        bne @tslow
        lda as_n,x
        beq @tok
        cmp #8
        bcs @tnf
        lda as_lk,x
        cmp mx_k
        bcs @tnf
        lda as_lb,x
        cmp mx_start
        bcc @tok
        beq @tok
        bcs @tnf
@tslow: jsr chan_fits
        bcc @tok
@tnf:
        lda mx_p
        eor #1
        sta mx_p
        dec pj_cnt
        bne @try
        ldx mx_obj              ; no cabe: se queda oculto este cuadro
        lda #1
        sta ob_hid,x
        jmp @onext
@tok:   CHAN_ADD
        ldx mx_obj
        lda #0
        sta ob_hid,x
        lda mx_p
        sta ob_lp,x
@got:   ; registros de la línea k: posición, color (blanco si parpadea), tamaño
        ldx mx_obj
        ldy ob_type,x
        lda ot_dbl,y
        sta tmp2
        lda ob_fl,x
        beq :+
        lda #$0E
        bne :++
:       lda ot_color,y
:       sta tmp1
        lda ob_x,x
        clc
        adc #64
        ldy mx_k
        ldx mx_p
        bne @p3
        sta (fp_hp2),y
        lda tmp1
        sta (fp_c2),y
        lda tmp2
        sta (fp_s2),y
        lda (fp_mk),y
        ora #1
        sta (fp_mk),y
        lda #>PL2
        bne @dw
@p3:    sta (fp_hp3),y
        lda tmp1
        sta (fp_c3),y
        lda tmp2
        sta (fp_s3),y
        lda (fp_mk),y
        ora #2
        sta (fp_mk),y
        lda #>PL3
@dw:    ; entrada de la lista de dibujo
        ldy dwptr
        sta dw_pg,y
        ldx mx_obj
        lda ob_type,x
        cmp #T_EXP
        bne @nf
        lda ob_t,x              ; explosión: 4 frames de 6
        jsr exp_frame
        tay
        lda exp_glo,y
        sta tmp2
        lda exp_ghi,y
        jmp @gs
@nf:    tay                     ; resto: 2 frames, cambia cada 8 cuadros
        lda ob_t,x
        and #8
        bne @g1
        lda ot_gfx0_lo,y
        sta tmp2
        lda ot_gfx0_hi,y
        jmp @gs
@g1:    lda ot_gfx1_lo,y
        sta tmp2
        lda ot_gfx1_hi,y
@gs:    sta tmp3
        ; recorte vertical (casi nunca hace falta)
        lda ob_y,x
        clc
        adc #PMOFF
        sta tmp4
        cmp #41
        bcs :+
        jmp @ctop
:       clc
        adc mx_h
        cmp #234
        bcc :+
        jmp @cbot
:
        lda mx_h
@hs:    ldy dwptr
        ldx mx_obj
        sta dw_h,y
        ; ¿idéntico a lo que ya está pintado (cuadro anterior, mismo player)?
        ; entonces pm_draw ni lo borra ni lo vuelve a pintar
        cmp lr_h,x
        bne @chg
        lda lr_gen,x
        clc
        adc #1
        cmp bgen
        bne @chg
        lda dw_pg,y
        cmp lr_pg,x
        bne @chg
        lda tmp4
        cmp lr_ix,x
        bne @chg
        lda tmp2
        cmp lr_gl,x
        bne @chg
        lda tmp3
        cmp lr_gh,x
        bne @chg
        lda #1
        sta kp,x
        bne @sk
@chg:   lda dw_h,y
        sta lr_h,x
        lda dw_pg,y
        sta lr_pg,x
        lda tmp4
        sta lr_ix,x
        lda tmp2
        sta lr_gl,x
        lda tmp3
        sta lr_gh,x
        lda #0
@sk:    sta dw_sk,y
        lda bgen
        sta lr_gen,x
        txa
        sta dw_ob,y
        lda tmp4
        sta dw_ix,y
        lda tmp2
        sta dw_gl,y
        lda tmp3
        sta dw_gh,y
        inc dwptr
        jmp @onext
@cbot:  lda #233
        sec
        sbc tmp4
        jmp @hs
@ctop:  lda #41                 ; filas a saltar
        sec
        sbc tmp4
        sta tmp0
        clc
        adc tmp2
        sta tmp2
        bcc :+
        inc tmp3
:       lda #41
        sta tmp4
        lda mx_h
        sec
        sbc tmp0
        jmp @hs
@onext: inc mx_i
        jmp @ol
@odone: lda mx_pass
        bne :+
        inc mx_pass
        jmp @opass
:
        lda dwptr
        sec
        sbc dwbase
        ldx tmp7
        sta dw_n,x
        PROF 10
        ; --- proyectiles: disparos y balas juntos, ordenados por altura,
        ;     repartidos en cualquiera de los 4 misiles (todos son COLPF3)
        lda dset16,x
        sta mdptr
        sta mdbase
        ldy #0
        lda #NSHOT
        sta pj_cnt
        ldx sh_head             ; del más viejo al más nuevo = de arriba abajo
@ps:    lda sh_y,x
        cmp #YOFF
        bcc @psn
        sta pj_y,y
        lda sh_x,x
        sta pj_x,y
        lda #6
        sta pj_h,y
        lda #0
        sta pj_k,y
        sta pj_p,y              ; los disparos propios no necesitan turno
        iny
@psn:   inx
        cpx #NSHOT
        bcc :+
        ldx #0
:       dec pj_cnt
        bne @ps
        sty pj_ns               ; estos ya van ordenados
        ldx #0                  ; las más nuevas (más arriba) ocupan los huecos bajos
@pb:    lda bu_y,x
        beq @pbn
        cmp #YOFF
        bcc @pbn
        cmp #YOFF+190
        bcs @pbn
        sta pj_y,y
        lda bu_x,x
        sta pj_x,y
        lda #2
        sta pj_h,y
        lda #1
        sta pj_k,y
        txa
        sta pj_s,y
        lda bu_hid,x
        sta pj_p,y
        iny
@pbn:   inx
        cpx #NBUL
        bne @pb
        sty pj_n
        ; índices ordenados por y
        ldx #0
@pi:    cpx pj_n
        beq @pq
        txa
        sta pj_o,x
        inx
        jmp @pi
@pq:    ldx pj_ns             ; la ordenación solo tiene que colocar las balas
        bne @q1
        ldx #1
@q1:    cpx pj_n
        bcs @pdone
        lda pj_o,x
        sta tmp0
        tay
        lda pj_y,y
        sta tmp1
        txa
        tay
@q2:    dey
        bmi @q3
        lda pj_o,y
        sty tmp2
        tay
        lda pj_y,y
        ldy tmp2
        cmp tmp1
        bcc @q3
        beq @q3
        lda pj_o,y
        sta pj_o+1,y
        jmp @q2
@q3:    iny
        lda tmp0
        sta pj_o,y
        inx
        jmp @q1
@pdone: PROF 11
        ; asignación: dos pasadas (primero las balas que no se vieron en el cuadro
        ; anterior), cualquier misil donde quepa
        lda #0
        sta mx_pass
        ldx pj_n                ; ¿alguna bala con turno pendiente?
        beq @pp1
:       dex
        lda pj_p,x
        bne @ppass
        cpx #0
        bne :-
@pp1:   inc mx_pass
@ppass: lda #0
        sta pj_i
@pal:   ldx pj_i
        cpx pj_n
        bne :+
        jmp @pend
:       lda pj_o,x
        sta mx_obj
        tax
        lda pj_p,x
        eor mx_pass
        bne :+
        jmp @panext
:       lda pj_y,x              ; línea de la display list: la de la franja que empieza
        sec                     ; al menos PJD líneas antes (la DLI escribe los HPOSM con
        sbc #YOFF+PJD           ; la línea ya empezada y pueden llegar 1-2 líneas tarde)
        bcs :+
        lda #0
        beq @k0p
:       clc
        adc fine
        lsr
        lsr
        lsr
        cmp #25
        bcc :+
        lda #24
:
@k0p:   sta mx_k
        beq @s0
        asl
        asl
        asl
        clc
        adc #YOFF
        sec
        sbc fine
@s0:    sta mx_start
        lda pj_y,x
        clc
        adc pj_h,x
        sta mx_hyb
        ldx #0
@ptr:   lda mx_pass             ; camino rápido: segunda pasada y canal en orden
        beq @pslow
        lda as_mix,x
        bne @pslow
        lda as_n,x
        beq @pok
        cmp #8
        bcs @pnf
        lda as_lk,x
        cmp mx_k
        bcs @pnf
        lda as_lb,x
        cmp mx_start
        bcc @pok
        beq @pok
        bcs @pnf
@pslow: jsr chan_fits
        bcc @pok
@pnf:   inx
        cpx #4
        bne @ptr
        ldx mx_obj              ; no cabe en ninguna banda este cuadro
        lda pj_k,x
        beq :+
        ldy pj_s,x
        lda #1
        sta bu_hid,y
:       jmp @panext
@pok:   CHAN_ADD
        stx mx_p
        ldx mx_obj
        lda pj_k,x
        beq :+
        ldy pj_s,x
        lda #0
        sta bu_hid,y
:       lda mx_p
        asl
        tax
        lda fp_m0,x
        sta ptr2
        lda fp_m0+1,x
        sta ptr2+1
        ldx mx_obj
        ldy mx_k
        lda pj_x,x
        clc
        adc #64
        sta (ptr2),y
        ldx mx_p
        lda (fp_mk),y
        ora mbit,x
        sta (fp_mk),y
        ldx mx_obj
        lda pj_k,x
        asl
        asl
        ora mx_p
        tay
        lda pmask,y
        ldy mdptr
        sta md_m,y
        lda pj_h,x
        sta md_h,y
        lda pj_y,x
        clc
        adc #PMOFF
        sta md_ix,y
        inc mdptr
@panext: inc pj_i
        jmp @pal
@pend:  lda mx_pass
        bne @padone
        inc mx_pass
        jmp @ppass
@padone: PROF 12
        lda mdptr
        sec
        sbc mdbase
        ldx tmp7
        sta md_n,x
        ; --- CHBASE: línea 0 siempre, cambios solo con jefe
        ldx #0
        jsr line_chbase
        ldy #0
        sta (fp_ch),y
        sta f_tmp2
        lda bstate
        beq @chd
        ; los cambios de charset solo varían si se mueve el jefe o el anillo
        lda top
        cmp ch_top
        bne @chr
        lda bring6
        cmp ch_b6
        beq @chp
@chr:   lda top
        sta ch_top
        lda bring6
        sta ch_b6
        lda #0
        sta ch_n
        ldx #1
@chl:   jsr line_chbase
        cmp f_tmp2
        beq @chn
        sta f_tmp2
        ldy ch_n
        cpy #6
        bcs @chn
        sta ch_v,y
        txa
        sta ch_l,y
        inc ch_n
@chn:   inx
        cpx #25
        bne @chl
@chp:   ldx ch_n                ; reproducir los cambios guardados
        beq @chd
@cpl:   dex
        lda ch_l,x
        tay
        lda ch_v,x
        sta (fp_ch),y
        lda (fp_mk),y
        ora #64
        sta (fp_mk),y
        cpx #0
        bne @cpl
@chd:   ; --- bits de DLI: en la línea anterior a cada línea con cambios, y la
        ; lista ordenada de esas líneas para las DLI (la línea 0 la pone la VBI)
        lda tmp7
        beq :+
        jmp @dlb
:       ldy #0
        .repeat 24, K
        lda TAB_A+F_MASK*32+K+1
        beq :+
        lda #K+1
        sta lk_a,y
        iny
        lda #$80
:       ora #$64
        sta DLA+7+3*K
        .endrep
        rts
@dlb:   ldy #0
        .repeat 24, K
        lda TAB_B+F_MASK*32+K+1
        beq :+
        lda #K+1
        sta lk_b,y
        iny
        lda #$80
:       ora #$64
        sta DLB+7+3*K
        .endrep
        rts

; ---------------------------------------------------------------------
; ¿Cabe el objeto (mx_k, mx_start, mx_hyb) en el canal X (0-3 misiles,
; 4-5 players)? Se comprueba contra todo lo ya puesto en ese canal, sin
; importar el orden: el de arriba tiene que acabar antes de que empiece
; la línea del de abajo. C=0 cabe.
; ---------------------------------------------------------------------
chan_fits:
        lda as_n,x
        bne :+
        clc
        rts
:       cmp #8                  ; como mucho 8 por canal
        bcc :+
        rts                     ; (C=1: no cabe)
:       sta cf_n
        lda mx_pass             ; segunda pasada y canal sin turnos: todo va en orden,
        beq @full               ; basta con mirar el último puesto (el más bajo)
        lda as_mix,x
        bne @full
        txa
        asl
        asl
        asl
        clc
        adc cf_n
        tay
        dey
        lda as_k,y
        cmp mx_k
        bcs @no
        lda as_b,y
        cmp mx_start
        beq :+
        bcs @no
:       clc
        rts
@full:  txa
        asl
        asl
        asl
        tay
@l:     lda as_k,y
        cmp mx_k
        beq @no
        bcs @below
        lda as_b,y              ; el ya puesto va encima
        cmp mx_start
        beq @nx
        bcs @no
        jmp @nx
@below: lda mx_hyb              ; el nuevo va encima
        cmp as_s,y
        beq @nx
        bcs @no
@nx:    iny
        dec cf_n
        bne @l
        clc
        rts
@no:    sec
        rts



fptab:
        .repeat 12, F
        .word TAB_A+F*32
        .endrep
        .repeat 12, F
        .word TAB_B+F*32
        .endrep

mbit:   .byte 4,8,16,32
pmask:  .byte %00000010,%00001000,%00100000,%10000000   ; disparo: 1 color clock
        .byte %00000011,%00001100,%00110000,%11000000   ; bala: 2 color clocks
dset8:  .byte 0,8
dset16: .byte 0,16

; A = yb del objeto -> mx_k (línea DL) y mx_start (yb en que empieza esa línea)
calc_k:
        sec
        sbc #YOFF
        bcs @pos
        lda #0
        sta mx_k
        sta mx_start
        rts
@pos:   clc
        adc fine
        lsr
        lsr
        lsr
        cmp #25
        bcc :+
        lda #24
:       sta mx_k
        bne :+
        lda #0
        sta mx_start
        rts
:       asl
        asl
        asl
        clc
        adc #YOFF
        sec
        sbc fine
        sta mx_start
        rts

; ¿cabe el objeto en el player mx_p (0=P2,1=P3)? C=0 sí
try_player:
        lda mx_p
        clc
        adc #4
        tax
        jmp try_chan
try_missile:
        ldx mx_p
try_chan:
        lda mx_lastk,x
        cmp #$FF
        beq @ok
        cmp mx_k
        bcs @no                 ; misma línea o anterior
        lda mx_lastb,x
        cmp mx_start
        beq @ok
        bcs @no
@ok:    lda mx_k
        sta mx_lastk,x
        lda mx_hyb
        sta mx_lastb,x
        clc
        rts
@no:    sec
        rts

; CHBASE de la línea X (en jefe puede cambiar a charset B)
line_chbase:
        stx f_line
        lda bstate
        beq @lvl
        lda bring6
        cmp #$FF
        beq @a
        txa
        clc
        adc top
        and #31
        sta f_tmp
        lda bring6
        sec
        sbc f_tmp
        and #31                 ; distancia a la fila 6 del jefe
        cmp #7
        bcs @a
        sta f_tmp
        lda #6
        sec
        sbc f_tmp               ; fila del jefe
        ldx sector
        cmp boss_split,x
        bcc @a
        ldx f_line
        lda #>CS_BB
        rts
@a:     ldx f_line
        lda #>CS_BA
        rts
@lvl:   lda chlvl
        rts

exp_glo: .byte <og11_0,<og11_1,<og11_2,<og11_3
exp_ghi: .byte >og11_0,>og11_1,>og11_2,>og11_3

exp_frame:
        cmp #6
        bcc @0
        cmp #12
        bcc @1
        cmp #18
        bcc @2
        lda #3
        rts
@2:     lda #2
        rts
@1:     lda #1
        rts
@0:     lda #0
        rts

; =====================================================================
;  Dibujo de PMG del cuadro visible
; =====================================================================
pm_draw:
        ; borrar lo anterior (players 2/3)
        ldx er_n
        beq @ed
@el:    dex
        ldy er_ob,x             ; el mismo objeto se queda igual: no se borra
        lda kp,y
        bne @en
        lda er_pg,x
        sta ptr0+1
        lda er_ix,x
        sta ptr0
        lda #0
        ldy er_h,x
        beq @en
        dey
@ez:    sta (ptr0),y
        dey
        bpl @ez
@en:    cpx #0
        bne @el
@ed:    ; dibujar
        ldx fsel
        lda dset8,x
        sta tmp6
        lda dw_n,x
        sta er_n
        beq @dd
        lda #0
        sta tmp5
@dl:    ldx tmp6
        lda dw_pg,x
        sta ptr0+1
        lda dw_ix,x
        sta ptr0
        lda dw_gl,x
        sta ptr1
        lda dw_gh,x
        sta ptr1+1
        lda dw_h,x
        ldy tmp5
        sta er_h,y
        lda dw_pg,x
        sta er_pg,y
        lda dw_ix,x
        sta er_ix,y
        lda dw_ob,x
        sta er_ob,y
        lda dw_sk,x             ; ya está pintado tal cual
        bne @dn
        ldy dw_h,x
        beq @dn
        dey
@dc:    lda (ptr1),y
        sta (ptr0),y
        dey
        bpl @dc
@dn:    inc tmp6
        inc tmp5
        lda tmp5
        cmp er_n
        bne @dl
@dd:    ; nave (P0/P1): solo si ha cambiado algo
        ldx fsel
        lda sh_vis,x
        beq :+
        lda sh_ix,x
:       cmp shp_idx             ; posición (0 = oculta)
        bne @sch
        lda sh_fr,x
        cmp shp_fr
        bne @sch
        jmp @mis
@sch:   lda shp_idx
        beq @sn
        sta ptr0
        lda #>PL0
        sta ptr0+1
        lda #>PL1
        sta ptr1+1
        lda shp_idx
        sta ptr1
        lda #0
        ldy #15
@sz:    sta (ptr0),y
        sta (ptr1),y
        dey
        bpl @sz
        sta shp_idx
@sn:    ldx fsel
        lda sh_vis,x
        beq @mis
        lda sh_ix,x
        sta shp_idx
        sta ptr0
        sta ptr1
        lda #>PL0
        sta ptr0+1
        lda #>PL1
        sta ptr1+1
        ldy sh_fr,x
        sty shp_fr
        lda ship_p0_lo,y
        sta ptr2
        lda ship_p0_hi,y
        sta ptr2+1
        lda ship_p1_lo,y
        sta ptr3
        lda ship_p1_hi,y
        sta ptr3+1
        ldy #15
@sd:    lda (ptr2),y
        sta (ptr0),y
        lda (ptr3),y
        sta (ptr1),y
        dey
        bpl @sd
@mis:   ; misiles: borrar las líneas del cuadro anterior y dibujar (bucles desenrollados:
        ; un disparo ocupa 6 líneas, una bala 2)
        ldx me_n
        beq @md
        lda #0
@ml:    dex
        ldy me_ix,x
        sta MIS,y
        sta MIS+1,y
        sta MIS+2,y             ; (en una bala estas 4 de más caen en líneas que
        sta MIS+3,y             ;  se redibujan igualmente o están vacías)
        sta MIS+4,y
        sta MIS+5,y
        cpx #0
        bne @ml
@md:    ldx fsel
        lda dset16,x
        tax
        ldy fsel
        lda md_n,y
        sta me_n
        beq @mr
        clc
        adc dset16,y
        sta tmp6                ; fin
        lda #0
        sta tmp5
@mdl:   lda md_ix,x
        ldy tmp5
        sta me_ix,y
        inc tmp5
        tay
        lda md_m,x
        sta tmp1
        lda md_h,x
        cmp #6
        bne @mb2
        lda MIS,y
        ora tmp1
        sta MIS,y
        lda MIS+1,y
        ora tmp1
        sta MIS+1,y
        lda MIS+2,y
        ora tmp1
        sta MIS+2,y
        lda MIS+3,y
        ora tmp1
        sta MIS+3,y
        lda MIS+4,y
        ora tmp1
        sta MIS+4,y
        lda MIS+5,y
        ora tmp1
        sta MIS+5,y
        jmp @mnx
@mb2:   lda MIS,y
        ora tmp1
        sta MIS,y
        lda MIS+1,y
        ora tmp1
        sta MIS+1,y
@mnx:   inx
        cpx tmp6
        bne @mdl
@mr:    rts


; =====================================================================
;  Marcador
; =====================================================================
hud_update:
        lda msgt
        beq @n
        dec msgt
        bne @r
        lda #1
        sta hudchg
@n:     lda hudchg
        beq @r
        lda #0
        sta hudchg
        jsr hud_draw
@r:     rts

hud_draw:
        ldx #31
@c:     lda hud_proto,x
        sta HUD,x
        dex
        bpl @c
        ; puntos
        ldx #2
        ldy #4
@d:     lda score,x
        lsr
        lsr
        lsr
        lsr
        ora #$10
        sta HUD,y
        iny
        lda score,x
        and #$0F
        ora #$10
        sta HUD,y
        iny
        dex
        bpl @d
        lda lives
        ora #$10
        sta HUD+18
        lda power
        ora #$10
        sta HUD+24
        lda sector
        clc
        adc #$11
        sta HUD+31
        rts

hud_proto:      ; "PTS 000000  VIDAS 3  NV 1  SEC 1"
        .byte $30,$34,$33,0,$10,$10,$10,$10,$10,$10,0,0
        .byte $36,$29,$24,$21,$33,0,$13,0,0
        .byte $2E,$36,0,$11,0,0
        .byte $33,$25,$23,0,$11

; mensaje de 32 bytes (ptr0) en el marcador durante msgt cuadros
hud_msg:
        ldy #31
@c:     lda (ptr0),y
        sta HUD,y
        dey
        bpl @c
        rts

hud_sector:
        ldx sector
        lda txt_sec_lo,x
        sta ptr0
        lda txt_sec_hi,x
        sta ptr0+1
        jmp hud_msg

; ---------------------------------------------------------------------
        .segment "BSS"
dwbase: .res 1
dwptr:  .res 1
mdbase: .res 1
mdptr:  .res 1
mx_i:   .res 1
mx_obj: .res 1
mx_h:   .res 1
mx_k:   .res 1
mx_start: .res 1
mx_p:   .res 1
mx_hyb: .res 1
f_hp2:  .res 1
f_hp3:  .res 1
f_m0:   .res 1
f_m1:   .res 1
f_m2:   .res 1
f_m3:   .res 1
f_s2:   .res 1
f_s3:   .res 1
f_c2:   .res 1
f_c3:   .res 1
f_tmp:  .res 1
f_tmp2: .res 1
f_line: .res 1
tw_x:   .res 1
as_n:   .res 6
as_mix: .res 6
cf_n:   .res 1
mx_pass: .res 1
ob_hid: .res NOBJ
ob_pri: .res NOBJ
bu_hid: .res NBUL
lk_na:  .res 1
lk_nb:  .res 1
shp_fr: .res 1
ch_top: .res 1
ch_b6:  .res 1
ch_n:   .res 1
ch_l:   .res 6
ch_v:   .res 6
pj_n:   .res 1
pj_i:   .res 1
pj_try: .res 1
pj_cnt: .res 1
pj_ns:  .res 1
        .segment "CODE"

; variables fuera del fichero cargado: hueco libre de $B000 (la PMG de una
; línea solo usa $B300-$B7FF)
        .segment "HIBSS"
bgen:   .res 1
kp:     .res NOBJ
lr_gen: .res NOBJ
lr_pg:  .res NOBJ
lr_ix:  .res NOBJ
lr_h:   .res NOBJ
lr_gl:  .res NOBJ
lr_gh:  .res NOBJ
dw_ob:  .res 16
dw_sk:  .res 16
er_ob:  .res 8
ob_lp:  .res NOBJ
as_lk:  .res 6
as_lb:  .res 6
as_k:   .res 48
as_s:   .res 48
as_b:   .res 48
pj_p:   .res 14
pj_s:   .res 14
pj_y:   .res 14
pj_x:   .res 14
pj_h:   .res 14
pj_k:   .res 14
pj_o:   .res 14
        .segment "CODE"
