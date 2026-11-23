; =====================================================================
;  boss.s · llegada, combate y destrucción de los jefes
; =====================================================================

; fin del mapa: la pantalla está vacía; se cargan charset y paleta del jefe
boss_begin:
        lda #2
        sta mapst
        lda #6
        sta brow
        lda #0
        sta bossy
        lda #$FF
        sta bring6
        ldx sector
        lda boss_csa_lo,x
        sta ptr0
        lda boss_csa_hi,x
        sta ptr0+1
        lda boss_csa_n,x
        ldx #>CS_BA
        jsr copy_cs
        ldx sector
        lda boss_csb_lo,x
        sta ptr0
        lda boss_csb_hi,x
        sta ptr0+1
        lda boss_csb_n,x
        ldx #>CS_BB
        jsr copy_cs
        ldx sector
        lda boss_pal_lo,x
        sta ptr0
        lda boss_pal_hi,x
        sta ptr0+1
        ldy #0
        lda (ptr0),y
        sta cur_bk
        iny
        lda (ptr0),y
        sta cur_p0
        iny
        lda (ptr0),y
        sta cur_p1
        iny
        lda (ptr0),y
        sta cur_p2
        sta basep2
        ; puntos débiles
        ldx sector
        lda boss_wp_lo,x
        sta ptr0
        lda boss_wp_hi,x
        sta ptr0+1
        lda boss_wp_n,x
        sta wp_n
        sta bwpleft
        ldx #0
        ldy #0
@w:     lda (ptr0),y
        clc
        adc #8                  ; el jefe empieza en la columna 2
        sta wp_x,x
        iny
        lda (ptr0),y
        sta wp_y,x
        iny
        lda (ptr0),y
        sta wp_w,x
        iny
        lda (ptr0),y
        sta wp_h,x
        iny
        lda (ptr0),y
        sta wp_hp,x
        iny
        lda (ptr0),y
        sta wp_core,x
        iny
        txa
        asl
        asl
        asl
        asl
        adc #40
        sta wp_t,x
        inx
        cpx wp_n
        bne @w
        lda #1
        sta bstate
        lda #<txt_warning
        sta ptr0
        lda #>txt_warning
        sta ptr0+1
        jsr hud_msg
        lda #180
        sta msgt
        lda #TRK_DRONE          ; el dron de siempre para el jefe (con fundido)
        jsr music_request
        rts

boss_fight_start:
        lda #1
        sta sstop
        lda #2
        sta bstate
        lda #120
        sta bspawn
        rts

boss_update:
        lda bstate
        cmp #2
        beq @fight
        cmp #3
        bne :+
        jmp @dying
:       cmp #4
        bne :+
        jmp @clear
:       rts
@fight:
        lda bflash
        beq :+
        dec bflash
        bne :+
        lda basep2
        sta cur_p2
:       ; disparos de los puntos débiles
        ldx #0
@wl:    lda wp_hp,x
        beq @wn
        dec wp_t,x
        bne @wn
        ldy bwpleft
        lda wp_rate,y
        ldy diff
        clc
        adc dif_wp,y
        sta wp_t,x
        jsr wp_center
        lda wp_core,x
        beq @aim
        ; núcleo: abanico de tres
        stx tmp6
        jsr fire_down
        lda #$00
        sta tmp2
        lda #$01
        sta tmp3
        lda #$D0
        sta tmp4
        lda #$01
        sta tmp5
        jsr new_bullet
        lda #$00
        sta tmp2
        lda #$FF
        sta tmp3
        jsr new_bullet
        ldx tmp6
        jmp @wn
@aim:   jsr fire_aimed
@wn:    inx
        cpx wp_n
        bne @wl
        ; refuerzos
        dec bspawn
        bne @r
        lda #220
        sta bspawn
        ldx #0
        lda sp_left
        beq :+
        inx
        lda sp_left+1
        bne @r
:       lda sector
        asl
        sta tmp0
        lda frame
        and #1
        ora tmp0
        sta sp_type,x
        lda RANDOM
        and #63
        adc #24
        sta sp_x,x
        lda #2
        sta sp_left,x
        lda #20
        sta sp_itv,x
        lda #0
        sta sp_t,x
        sta sp_i,x
        sta sp_drop,x
        lda RANDOM
        sta sp_p,x
        lda bwpleft             ; con un solo punto vivo, sale cápsula
        cmp #2
        bcs @r
        lda #1
        sta sp_drop,x
@r:     rts

@dying:
        dec btimer
        beq @gone
        lda btimer
        and #7
        bne :+
        lda RANDOM
        and #127
        cmp #104
        bcc *+4
        lda #60
        clc
        adc #8
        sta tmp0
        lda RANDOM
        and #31
        clc
        adc bossy
        clc
        adc #8
        sta tmp1
        jsr spawn_explosion
        lda #16
        sta sfx2
:       lda btimer
        and #4
        beq :+
        lda #$0E
        sta cur_p2
        rts
:       lda basep2
        sta cur_p2
        rts
@gone:  ; borrar las filas del jefe del anillo
        lda #6
        sta tmp4
@er:    lda bring6
        sec
        sbc #6
        clc
        adc tmp4
        and #31
        tax
        lda ring_lo,x
        sta ptr0
        lda ring_hi,x
        sta ptr0+1
        lda #0
        ldy #31
:       sta (ptr0),y
        dey
        bpl :-
        dec tmp4
        bpl @er
        lda basep2
        sta cur_p2
        lda #$50
        jsr add_score
        lda #4
        sta bstate
        lda #170
        sta btimer
        lda #<txt_clear
        sta ptr0
        lda #>txt_clear
        sta ptr0+1
        jsr hud_msg
        lda #170
        sta msgt
        rts
@clear:
        dec btimer
        bne @cr
        lda sector
        cmp #4
        bne :+
        lda #1
        sta victory
        rts
:       inc sector
        jsr level_init_next
@cr:    rts

; siguiente sector sin rellenar pantalla (sigue el scroll desde vacío)
level_init_next:
        ; vaciar objetos pero conservar balas fuera
        jsr level_init
        lda #1
        sta hudchg
        rts

wp_center:
        lda wp_w,x
        lsr
        clc
        adc wp_x,x
        sta tmp0
        lda wp_h,x
        lsr
        clc
        adc wp_y,x
        clc
        adc bossy
        sta tmp1
        rts

; disparo sh (índice en tmp7) contra los puntos débiles. C=1 si impacta
boss_shot_test:
        ldx #0
@l:     lda wp_hp,x
        beq @n
        lda wp_core,x
        beq @v
        lda bwpleft
        cmp #2
        bcs @n                  ; el núcleo se protege mientras queden otros
@v:     lda cx
        sec
        sbc wp_x,x
        cmp wp_w,x
        bcs @n
        lda wp_y,x
        clc
        adc bossy
        sta tmp0
        lda cy
        clc
        adc #6
        cmp tmp0
        bcc @n
        lda tmp0
        clc
        adc wp_h,x
        cmp cy
        bcc @n
        ; impacto
        lda #$0E
        sta cur_p2
        lda #3
        sta bflash
        lda #2
        sta sfx2
        stx tmp4
        jsr add_score10
        ldx tmp4
        dec wp_hp,x
        bne @hit
        ; punto destruido
        jsr wp_center
        lda tmp0
        sec
        sbc #4
        sta tmp0
        lda tmp1
        sec
        sbc #4
        sta tmp1
        jsr spawn_explosion
        lda #$10
        jsr add_score
        lda #30
        sta sfx2
        dec bwpleft
        bne @hit
        lda #3
        sta bstate
        lda #150
        sta btimer
@hit:   sec
        rts
@n:     inx
        cpx wp_n
        beq :+
        jmp @l
:       clc
        rts

; cadencia de disparo según puntos vivos (índice = vivos)
wp_rate: .byte 40,40,55,70,85,95
