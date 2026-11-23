; =====================================================================
;  objects.s · oleadas, enemigos aéreos, suelo, balas, colisiones
; =====================================================================

; ---------------------------------------------------------------------
;  Oleadas
; ---------------------------------------------------------------------
waves_update:
        lda bstate
        bne @run
        ldy #0
        lda (wavep),y
        cmp #255
        beq @run
        cmp mrow
        beq @go
        bcs @run
@go:    ldx #0
        lda sp_left
        beq @free
        inx
        lda sp_left+1
        bne @run
@free:  ldy #1
        lda (wavep),y
        sta sp_type,x
        iny
        lda (wavep),y
        sta sp_x,x
        iny
        lda (wavep),y
        sta sp_left,x
        iny
        lda (wavep),y
        sta sp_itv,x
        iny
        lda (wavep),y
        sta sp_p,x
        iny
        lda (wavep),y
        sta sp_drop,x
        lda #0
        sta sp_t,x
        sta sp_i,x
        lda wavep
        clc
        adc #7
        sta wavep
        bcc @run
        inc wavep+1
@run:   ldx #0
        jsr @one
        ldx #1
@one:   lda sp_left,x
        beq @r
        lda sp_t,x
        beq @sp
        dec sp_t,x
@r:     rts
@sp:    stx tmp6
        jsr spawn_from
        ldx tmp6
        bcs @r
        dec sp_left,x
        inc sp_i,x
        lda sp_itv,x
        sta sp_t,x
        rts

; tope por sector (los sectores 4 y 5 tienen sprites y balas más caros)
obj_cap: .byte 5,5,5,4,4

; busca hueco libre -> X (C=1 si no hay)
find_obj:
        ldx #NOBJ-1
@f:     lda ob_type,x
        cmp #$FF
        beq @ok
        dex
        bpl @f
        sec
        rts
@ok:    clc
        rts

; crea un enemigo desde el generador tmp6
spawn_from:
        ldx #NOBJ-1             ; tope de objetos a la vez: con más, el cuadro no cabe
        ldy #0                  ; en 1/60 s y el juego va a la mitad. La oleada espera
@cnt:   lda ob_type,x           ; (se reintenta en el cuadro siguiente)
        cmp #$FF
        beq :+
        iny
:       dex
        bpl @cnt
        tya
        ldx sector
        cmp obj_cap,x
        bcc :+
        rts                     ; (C = 1)
:       jsr find_obj
        bcc :+
        rts
:       ldy tmp6
        lda sp_type,y
        sta ob_type,x
        sta tmp0
        tay
        lda ot_hp,y
        sta ob_hp,x
        lda #0
        sta ob_t,x
        sta ob_fl,x
        sta ob_xf,x
        sta ob_yf,x
        sta ob_vy,x
        sta ob_vyh,x
        sta ob_drop,x
        sta ob_vx,x
        ldy tmp6
        lda sp_i,y
        asl
        asl
        asl
        asl
        clc
        adc sp_p,y
        sta ob_p,x
        lda sp_drop,y
        beq :+
        lda sp_left,y
        cmp #1
        bne :+
        lda #1
        sta ob_drop,x
:       lda sp_x,y
        sta ob_x,x
        sta ob_x0,x
        lda #YOFF-16
        sta ob_y,x
        ldy tmp0
        lda ot_move,y
        cmp #2
        bne @n2
        ldy tmp6                ; zigzag: sentido alterno
        lda sp_i,y
        and #1
        beq :+
        lda #1
        bne @vx
:       lda #$FF
@vx:    sta ob_vx,x
        clc
        rts
@n2:    cmp #3
        bne @n3
        ldy tmp6                ; lapa: salta desde un lado
        lda sp_x,y
        beq @left
        lda #120
        sta ob_x,x
        lda #$FE
        bne @lv
@left:  lda #0
        sta ob_x,x
        lda #2
@lv:    sta ob_vx,x
        lda sp_i,y
        asl
        asl
        asl
        adc #YOFF+96
        sta ob_y,x
        lda #$FD
        sta ob_vyh,x
        clc
        rts
@n3:    cmp #4
        bne @n4
        lda #YOFF+196           ; cazador: entra por abajo
        sta ob_y,x
        clc
        rts
@n4:    cmp #5
        bne @n5
        ldy tmp6                ; flotantes: separados en x
        lda sp_i,y
        asl
        asl
        asl
        asl
        clc
        adc sp_x,y
        cmp #112
        bcc :+
        sbc #96
:       sta ob_x,x
@n5:    clc
        rts

; ---------------------------------------------------------------------
;  Movimiento de objetos aéreos
; ---------------------------------------------------------------------
objects_update:
        ldx #NOBJ-1
obj_loop:
        lda ob_type,x
        cmp #$FF
        beq obj_next
        stx tmp7
        inc ob_t,x
        lda ob_fl,x
        beq :+
        dec ob_fl,x
:       ldy ob_type,x
        lda ot_move,y
        asl
        tay
        lda mv_tab+1,y
        pha
        lda mv_tab,y
        pha
        rts                     ; salto a la rutina (vuelve a obj_ret)
obj_ret:
        ldx tmp7
        ; fuera por abajo
        lda ob_y,x
        cmp #YOFF+200
        bcc obj_next
        lda #$FF
        sta ob_type,x
obj_next:
        dex
        bpl obj_loop
        rts

mv_tab: .word mv_dive-1, mv_sine-1, mv_zig-1, mv_arc-1, mv_rise-1, mv_float-1, mv_cap-1, mv_exp-1

mv_end = obj_ret

; 0 picado
mv_dive:
        ldy ob_type,x
        lda ob_y,x
        clc
        adc ot_speed,y
        sta ob_y,x
        cmp #YOFF+48
        bcc @e
        lda ob_t,x
        and #1
        beq @e
        jsr steer
@e:     jmp mv_end

; 1 seno
mv_sine:
        lda ob_yf,x
        clc
        adc #$C0
        sta ob_yf,x
        bcc :+
        inc ob_y,x
:       lda ob_t,x
        asl
        clc
        adc ob_p,x
        and #63
        tay
        lda sintab,y
        bmi @neg
        clc
        adc ob_x0,x
        cmp #121
        bcc @st
        lda #120
        bne @st
@neg:   clc
        adc ob_x0,x
        bcs @st
        lda #0
@st:    sta ob_x,x
        lda ob_t,x
        cmp #60
        bne @e
        jsr maybe_fire
@e:     jmp mv_end

; 2 zigzag
mv_zig:
        lda ob_yf,x
        clc
        adc #$A0
        sta ob_yf,x
        lda ob_y,x
        adc #1
        sta ob_y,x
        lda ob_t,x
        and #31
        bne :+
        lda ob_vx,x
        eor #$FF
        clc
        adc #1
        sta ob_vx,x
:       lda ob_x,x
        clc
        adc ob_vx,x
        cmp #121
        bcc :+
        lda ob_vx,x             ; rebote
        eor #$FF
        clc
        adc #1
        sta ob_vx,x
        lda ob_x,x
:       sta ob_x,x
        jmp mv_end

; 3 arco (lapa)
mv_arc:
        lda ob_x,x
        clc
        adc ob_vx,x
        cmp #122
        bcc :+
        lda #$FF
        sta ob_type,x
        jmp mv_end
:       sta ob_x,x
        lda ob_yf,x
        clc
        adc ob_vy,x
        sta ob_yf,x
        lda ob_y,x
        adc ob_vyh,x
        sta ob_y,x
        lda ob_vy,x
        clc
        adc #$14
        sta ob_vy,x
        bcc :+
        inc ob_vyh,x
:       lda ob_y,x
        cmp #YOFF-12
        bcs @e
        lda #$FF
        sta ob_type,x
@e:     jmp mv_end

; 4 sube desde abajo
mv_rise:
        ldy ob_type,x
        lda ob_y,x
        sec
        sbc ot_speed,y
        sta ob_y,x
        cmp #YOFF-14
        bcs :+
        lda #$FF
        sta ob_type,x
        jmp mv_end
:       lda ob_t,x
        cmp #50
        bcs :+
        jsr steer
:       lda ob_t,x
        cmp #36
        bne @e
        jsr maybe_fire
@e:     jmp mv_end

; 5 flotante
mv_float:
        lda ob_vx,x             ; enfriamiento de la respuesta del orbe
        beq :+
        dec ob_vx,x
:
        lda ob_yf,x
        clc
        adc #$80
        sta ob_yf,x
        bcc :+
        inc ob_y,x
:       lda ob_t,x
        and #3
        bne :+
        jsr steer
:       lda ob_t,x
        and #127
        cmp #64
        bne @e
        jsr maybe_fire
@e:     jmp mv_end

; 6 cápsula
mv_cap:
        lda ob_t,x
        and #1
        bne :+
        inc ob_y,x
:       jmp mv_end

; 7 explosión
mv_exp:
        lda ob_t,x
        cmp #24
        bcc @e
        lda #$FF
        sta ob_type,x
@e:     jmp mv_end

; acerca la x del objeto X a la nave
steer:
        lda ob_x,x
        cmp ship_x
        beq @r
        bcs @l
        cmp #120
        bcs @r
        inc ob_x,x
        rts
@l:     dec ob_x,x
@r:     rts

; dispara si el tipo dispara (bit0) y está en pantalla
maybe_fire:
        ldy ob_type,x
        lda ot_fire,y
        and #1
        beq @r
        lda diff                ; en Fácil, la mitad de las veces no dispara
        bne :+
        lda RANDOM
        bmi @r
:
        lda ob_y,x
        cmp #YOFF+4
        bcc @r
        cmp ship_y
        bcs @r
        jsr obj_center
        jmp fire_aimed
@r:     rts

; tmp0/tmp1 = centro del objeto X
obj_center:
        ldy ob_type,x
        lda ot_w,y
        lsr
        clc
        adc ob_x,x
        sta tmp0
        lda ot_h,y
        lsr
        clc
        adc ob_y,x
        sta tmp1
        rts

; ---------------------------------------------------------------------
;  Balas enemigas
; ---------------------------------------------------------------------
; nueva bala en tmp0,tmp1 con velocidad tmp2(lo) tmp3(hi) x, tmp4/tmp5 y
new_bullet:
        stx nb_x
        ; zona de seguridad: nada nace pegado a la nave
        lda sdead
        bne @vel
        ldy diff
        lda ship_x
        clc
        adc #3
        sec
        sbc tmp0
        bcs :+
        eor #$FF
        adc #1
:       cmp dif_safe,y
        bcs @vel
        lda ship_y
        clc
        adc #8
        sec
        sbc tmp1
        bcs :+
        eor #$FF
        adc #1
:       cmp dif_safe,y
        bcs @vel
        ldx nb_x
        rts
@vel:   ldy diff                ; tope de balas a la vez según la dificultad
        lda bu_act
        cmp dif_bul,y
        bcc :+
        ldx nb_x
        rts
:       ; velocidad según dificultad: Fácil x0,75 · Hardcore x1,25
        lda diff
        cmp #1
        beq @free
        ldx #0
        jsr scale_v
        ldx #2
        jsr scale_v
@free:  ldx #NBUL-1             ; ¿ya hay una igual en el mismo sitio? (dos fuentes que
@dd:    lda bu_y,x              ;  disparan a la vez hacia la nave): sería un duplicado
        beq @ddn
        sec
        sbc tmp1
        clc
        adc #3
        cmp #7
        bcs @ddn
        lda bu_x,x
        sec
        sbc tmp0
        clc
        adc #2
        cmp #5
        bcs @ddn
        lda bu_vxh,x
        cmp tmp3
        bne @ddn
        lda bu_vyh,x
        cmp tmp5
        bne @ddn
        ldx nb_x
        rts
@ddn:   dex
        bpl @dd
        ldx #NBUL-1
@f:     lda bu_y,x
        beq @ok
        dex
        bpl @f
        ldx nb_x
        rts
@ok:    inc bu_act
        lda tmp0
        sta bu_x,x
        lda tmp1
        sta bu_y,x
        lda #$80
        sta bu_xf,x
        sta bu_yf,x
        lda tmp2
        sta bu_vxl,x
        lda tmp3
        sta bu_vxh,x
        lda tmp4
        sta bu_vyl,x
        lda tmp5
        sta bu_vyh,x
        ldx nb_x
        rts

; tmp2/3 (X=0) o tmp4/5 (X=2): v -= v/4 (Fácil) o v += v/4 (Hardcore)
scale_v:
        lda tmp3,x
        sta sc_h
        lda tmp2,x
        sta sc_l
        lda sc_h                ; v/4 con signo
        cmp #$80
        ror sc_h
        ror sc_l
        lda sc_h
        cmp #$80
        ror sc_h
        ror sc_l
        lda diff
        beq @sub
        lda tmp2,x
        clc
        adc sc_l
        sta tmp2,x
        lda tmp3,x
        adc sc_h
        sta tmp3,x
        rts
@sub:   lda tmp2,x
        sec
        sbc sc_l
        sta tmp2,x
        lda tmp3,x
        sbc sc_h
        sta tmp3,x
        rts

; bala apuntada a la nave desde tmp0,tmp1
fire_aimed:
        lda sdead
        beq :+
        rts
:       stx tmp6
        lda #0
        sta aim_sx
        sta aim_sy
        lda ship_x
        clc
        adc #3
        sec
        sbc tmp0
        bcs :+
        eor #$FF
        adc #1
        inc aim_sx
:       sta aim_dx
        lda ship_y
        clc
        adc #8
        sec
        sbc tmp1
        bcs :+
        eor #$FF
        adc #1
        inc aim_sy
:       sta aim_dy
        ; clasificar
        lsr
        lsr
        cmp aim_dx
        bcc :+
        ldy #0
        beq @cls
:       lda aim_dy
        lsr
        cmp aim_dx
        bcc :+
        ldy #1
        bne @cls
:       lda aim_dy
        cmp aim_dx
        bcc :+
        ldy #2
        bne @cls
:       lda aim_dx
        lsr
        cmp aim_dy
        bcs :+
        ldy #3
        bne @cls
:       ldy #4
@cls:   lda aim_vxl,y
        sta tmp2
        lda aim_vxh,y
        sta tmp3
        lda aim_vyl,y
        sta tmp4
        lda aim_vyh,y
        sta tmp5
        lda aim_sx
        beq :+
        lda #0
        sec
        sbc tmp2
        sta tmp2
        lda #0
        sbc tmp3
        sta tmp3
:       lda aim_sy
        beq :+
        lda #0
        sec
        sbc tmp4
        sta tmp4
        lda #0
        sbc tmp5
        sta tmp5
:       jsr new_bullet
        ldx tmp6
@r:     rts

aim_vxl: .byte $00,$70,$10,$50,$A0
aim_vxh: .byte $00,$00,$01,$01,$01
aim_vyl: .byte $B0,$90,$30,$D0,$50
aim_vyh: .byte $01,$01,$01,$00,$00

; bala recta hacia abajo desde tmp0,tmp1
fire_down:
        lda #0
        sta tmp2
        sta tmp3
        lda #$60
        sta tmp4
        lda #$02
        sta tmp5
        jmp new_bullet

; cuatro balas en cruz desde tmp0,tmp1
fire_cross:
        ldy #3
@c:     sty tmp6
        lda cr_xl,y
        sta tmp2
        lda cr_xh,y
        sta tmp3
        lda cr_yl,y
        sta tmp4
        lda cr_yh,y
        sta tmp5
        jsr new_bullet
        ldy tmp6
        dey
        bpl @c
        rts
cr_xl:  .byte $00,$00,$00,$00
cr_xh:  .byte $00,$00,$02,$FE
cr_yl:  .byte $00,$00,$00,$00
cr_yh:  .byte $02,$FE,$00,$00

bullets_update:
        lda #0
        sta bu_act
        ldx #NBUL-1
@l:     lda bu_y,x
        beq @n
        lda bu_xf,x
        clc
        adc bu_vxl,x
        sta bu_xf,x
        lda bu_x,x
        adc bu_vxh,x
        sta bu_x,x
        cmp #126
        bcs @k
        lda bu_yf,x
        clc
        adc bu_vyl,x
        sta bu_yf,x
        lda bu_y,x
        adc bu_vyh,x
        sta bu_y,x
        cmp #YOFF-4
        bcc @k
        cmp #YOFF+194
        bcs @k
        inc bu_act
        jmp @n
@k:     lda #0
        sta bu_y,x
@n:     dex
        bpl @l
        rts

; ---------------------------------------------------------------------
;  Objetivos de suelo
; ---------------------------------------------------------------------
targets_update:
        ldx #NTGT-1
@l:     lda tg_type,x
        bne :+
        jmp @n
:       lda tg_y,x
        cmp #YOFF
        bcc @nj
        cmp #YOFF+168
        bcs @nj
        dec tg_t,x
        beq :+
@nj:    jmp @n
:
        lda tg_type,x
        cmp #3
        beq @alt
        cmp #5
        beq @alt
        cmp #6
        beq @laser
        cmp #1
        bne @idle
        ; torreta apuntada
        ldy diff
        lda RANDOM
        and #31
        adc dif_turr,y
        sta tg_t,x
        lda tg_y,x
        clc
        adc #16
        cmp ship_y
        bcs @n
        jsr tg_center
        jsr fire_aimed
        jmp @n
@laser: lda #56
        sta tg_t,x
        jsr tg_center
        jsr fire_down
        jmp @n
@alt:   ; alterna metatile (pólipo abre/cierra, surtidor activo/inactivo)
        lda #60
        sta tg_t,x
        stx tmp6
        ldy tg_mt,x
        lda (mtalt),y
        jsr tg_write
        ldx tmp6
        ldy sector
        lda tg_mt,x
        cmp sec_open,y
        bne @n
        jsr tg_center
        lda tg_type,x
        cmp #3
        bne :+
        jsr fire_aimed
        jmp @n
:       jsr fire_down
        jmp @n
@idle:  lda #255
        sta tg_t,x
@n:     dex
        bmi :+
        jmp @l
:       rts

tg_center:
        lda tg_col,x
        asl
        asl
        asl
        asl
        clc
        adc #7
        sta tmp0
        lda tg_y,x
        clc
        adc #8
        sta tmp1
        rts

; ---------------------------------------------------------------------
;  Colisiones
; ---------------------------------------------------------------------
collisions:
        ; cajas compactas de los objetos aéreos impactables, una vez por cuadro
        ldx #0
        ldy #NOBJ-1
@cb:    lda ob_type,y
        cmp #T_CAP
        bcs @cbn
        sty tmp0
        tay
        lda ot_w,y
        sta tmp1
        lda ot_h,y
        ldy tmp0
        clc
        adc ob_y,y
        sta cb_y1,x
        lda ob_y,y
        sta cb_y0,x
        lda ob_x,y
        sta cb_x0,x
        clc
        adc tmp1
        sta cb_x1,x
        tya
        sta cb_o,x
        inx
@cbn:   dey
        bpl @cb
        stx cb_n
        ldx #0                  ; objetivos de suelo vivos y en pantalla
        ldy #NTGT-1
@tg:    lda tg_type,y
        beq @tgn
        lda tg_y,y
        cmp #YOFF-16
        bcc @tgn
        tya
        sta tl_l,x
        inx
@tgn:   dey
        bpl @tg
        stx tl_n
        ldx #NSHOT-1
@sl:    lda sh_y,x
        cmp #YOFF
        bcs :+
        jmp @sn
:       stx tmp7
        lda sh_x,x
        sta cx
        lda sh_y,x
        sta cy
        clc
        adc #6
        sta cy6
        ; contra objetos aéreos
        ldy cb_n
        bne :+
        jmp @on0
:       dey
@ol:    lda cx
        cmp cb_x0,y
        bcc @on
        cmp cb_x1,y
        bcs @on
        lda cy6
        cmp cb_y0,y
        bcc @on
        beq @on
        lda cb_y1,y
        cmp cy
        bcc @on
        beq @on
        ; impacto
        ldx tmp7
        lda #0
        sta sh_y,x
        sty cb_j
        ldx cb_o,y
        jsr hit_obj
        lda ob_type,x           ; si ha explotado, ya no tiene caja
        cmp #T_CAP
        bcc :+
        ldy cb_j
        lda #255
        sta cb_x0,y
        lda #0
        sta cb_x1,y
:       ldx tmp7
        jmp @sn
@on:    dey
        bpl @ol
@on0:
        ; contra objetivos de suelo (lista compacta; primero la columna)
        lda cx
        lsr
        lsr
        lsr
        lsr
        sta tmp1
        ldx tl_n
@tl:    dex
        bmi @tdone
        ldy tl_l,x
        lda tg_col,y
        cmp tmp1
        bne @tl
        lda tg_type,y
        beq @tl
        lda cy6
        cmp tg_y,y
        bcc @tl
        lda tg_y,y
        clc
        adc #16
        cmp cy
        bcc @tl
        ldx tmp7
        lda #0
        sta sh_y,x
        tya
        tax
        jsr hit_tgt
        ldx tmp7
        jmp @sn
@tdone:
        ; contra el jefe
        lda bstate
        cmp #2
        bne @sn0
        lda bossy               ; solo si el disparo está a la altura del jefe
        clc
        adc #56
        cmp cy
        bcc @sn0
        jsr boss_shot_test
        bcc @sn0
        ldx tmp7
        lda #0
        sta sh_y,x
@sn0:   ldx tmp7
@sn:    dex
        bmi :+
        jmp @sl
:       ; --- la nave
        lda sdead
        beq :+
        rts
:       lda ship_x
        clc
        adc #2
        sta cx
        lda ship_y
        clc
        adc #4
        sta cy
        ; balas
        lda sinv
        bne @caps
        ldx #NBUL-1
@bl:    lda bu_y,x
        beq @bn
        lda bu_x,x
        clc
        adc #2
        cmp cx
        bcc @bn
        lda cx
        clc
        adc #4
        cmp bu_x,x
        bcc @bn
        beq @bn
        lda bu_y,x
        clc
        adc #2
        cmp cy
        bcc @bn
        lda cy
        clc
        adc #7
        cmp bu_y,x
        bcc @bn
        beq @bn
        lda #0
        sta bu_y,x
        jmp kill_ship
@bn:    dex
        bpl @bl
@caps:  ; cuerpos y cápsulas
        ldx #NOBJ-1
@cl:    ldy ob_type,x
        cpy #T_EXP
        bcs @cn
        lda ob_x,x
        clc
        adc ot_w,y
        sec
        sbc #1
        cmp cx
        bcc @cn
        lda cx
        clc
        adc #4
        sbc ob_x,x
        bcc @cn
        beq @cn
        lda ob_y,x
        clc
        adc ot_h,y
        sec
        sbc #1
        cmp cy
        bcc @cn
        lda cy
        clc
        adc #7
        cmp ob_y,x
        bcc @cn
        beq @cn
        cpy #T_CAP
        bne @body
        lda #$FF
        sta ob_type,x
        jmp power_up
@body:  lda sinv
        bne @cn
        lda #1
        sta ob_hp,x
        jsr hit_obj
        jmp kill_ship
@cn:    dex
        bpl @cl
        rts

; daño al objeto X
hit_obj:
        dec ob_hp,x
        beq @kill
        lda #3
        sta ob_fl,x
        lda #2
        sta sfx2
        ldy ob_type,x
        lda ot_fire,y
        and #2
        beq @r
        lda ob_vx,x             ; orbe espejo: devuelve el disparo, como mucho
        bne @r                  ; una vez cada 40 cuadros (si no, el disparo doble
        lda #40                 ; crea dos balas idénticas)
        sta ob_vx,x
        jsr obj_center
        jsr fire_aimed
@r:     rts
@kill:  ldy ob_type,x
        lda ot_score,y
        jsr add_score
        ldy ob_type,x
        lda ot_fire,y
        and #4
        beq :+
        jsr obj_center
        jsr fire_cross
:       lda ob_drop,x
        sta tmp5
        jsr obj_center
        lda tmp0
        sec
        sbc #4
        sta ob_x,x
        lda tmp1
        sec
        sbc #4
        sta ob_y,x
        lda #T_EXP
        sta ob_type,x
        lda #0
        sta ob_t,x
        sta ob_fl,x
        lda #24
        sta sfx2
        lda tmp5
        beq :+
        lda ob_x,x
        sta tmp0
        lda ob_y,x
        sta tmp1
        jsr spawn_capsule
:       rts

; cápsula P en tmp0,tmp1
spawn_capsule:
        stx tmp6
        jsr find_obj
        bcs @r
        lda #T_CAP
        sta ob_type,x
        lda tmp0
        sta ob_x,x
        lda tmp1
        sta ob_y,x
        lda #0
        sta ob_t,x
        sta ob_fl,x
@r:     ldx tmp6
        rts

; explosión en tmp0,tmp1 (esquina)
spawn_explosion:
        stx tmp6
        jsr find_obj
        bcs @r
        lda #T_EXP
        sta ob_type,x
        lda tmp0
        sta ob_x,x
        lda tmp1
        sta ob_y,x
        lda #0
        sta ob_t,x
        sta ob_fl,x
@r:     ldx tmp6
        rts

; daño al objetivo de suelo X
hit_tgt:
        lda tg_type,x
        cmp #3
        bne @v
        ldy sector              ; pólipo cerrado: invulnerable
        lda tg_mt,x
        cmp sec_open,y
        beq @v
        lda #2
        sta sfx1
        rts
@v:     dec tg_hp,x
        beq @kill
        lda #2
        sta sfx2
        rts
@kill:  ldy tg_type,x
        lda tt_score,y
        jsr add_score
        ldy tg_type,x
        lda tt_flags,y
        sta tmp5
        ldy tg_mt,x             ; cráter cuadrado o redondo según el objetivo
        lda (mtcrat),y
        jsr tg_write
        jsr tg_center
        lda tmp5
        and #4
        beq :+
        jsr fire_cross
:       lda tmp0
        sec
        sbc #4
        sta tmp0
        lda tmp1
        sec
        sbc #4
        sta tmp1
        jsr spawn_explosion
        lda tmp5
        and #8
        beq :+
        jsr spawn_capsule
:       lda #0
        sta tg_type,x
        lda #20
        sta sfx2
        rts

power_up:
        lda power
        cmp #3
        bcs @max
        inc power
        lda #1
        sta hudchg
        lda #20
        sta sfx1
        rts
@max:   lda #$10
        jmp add_score

kill_ship:
.ifdef CHEAT
        rts
.endif
        lda invuln              ; truco activo: invencible
        beq :+
        rts
:
        lda #110
        sta sdead
        dec lives
        lda #1
        sta hudchg
        lda ship_x
        sta tmp0
        lda ship_y
        clc
        adc #4
        sta tmp1
        jsr spawn_explosion
        lda #40
        sta sfx2
        rts

; suma A (BCD centenas) a la puntuación
add_score:
        sed
        clc
        adc score+1
        sta score+1
        lda score+2
        adc #0
        sta score+2
        cld
check_extra:
        lda score+2
        cmp nextx
        bcc @n
        lda lives
        cmp #9
        bcs :+
        inc lives
:       sed
        lda nextx
        clc
        adc #$05
        sta nextx
        cld
@n:     lda #1
        sta hudchg
        rts

; suma 10 puntos
add_score10:
        sed
        lda score
        clc
        adc #$10
        sta score
        lda score+1
        adc #0
        sta score+1
        lda score+2
        adc #0
        sta score+2
        cld
        jmp check_extra

; ---------------------------------------------------------------------
        .segment "BSS"
cx:     .res 1
cy6:    .res 1
bu_act: .res 1
tl_l:   .res NTGT
tl_n:   .res 1
cb_o:   .res NOBJ
cb_n:   .res 1
cb_j:   .res 1
cb_x0:  .res NOBJ
cb_x1:  .res NOBJ
cb_y0:  .res NOBJ
cb_y1:  .res NOBJ
sc_l:   .res 1
sc_h:   .res 1
nb_x:   .res 1
cy:     .res 1
aim_sx: .res 1
aim_sy: .res 1
aim_dx: .res 1
aim_dy: .res 1
        .segment "CODE"
