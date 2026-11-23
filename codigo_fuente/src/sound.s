; =====================================================================
;  sound.s · POKEY
;
;  Pantallas (título, GAME OVER, victoria): dos voces de 16 bits a 1,79 MHz
;     bajo en canales 1+2, melodía en 3+4                     AUDCTL = $78
;  Fases: bajo de 16 bits en 3+4, melodía de 8 bits en el canal 2,
;     efectos en el canal 1                                    AUDCTL = $28
;  Jefes: el dron (16 bits en 3+4), efectos en el canal 1     AUDCTL = $28
;
;  Ningún cambio de música es en seco: la pista que suena se funde,
;  y la nueva entra desde silencio (fundido de entrada en el juego).
; =====================================================================

TRK_NONE  = 0
TRK_TITLE = 1
TRK_GO    = 2
TRK_PHASE = 3
TRK_DRONE = 4
ATT_MAX   = 12

; pide una pista (A); la VBI hace el fundido y el cambio
music_request:
        sta trk_req
        rts

; funde lo que suena y espera al silencio (pantallas, fin de partida)
music_fade_wait:
        lda #TRK_NONE
        sta trk_req
:       jsr wait_vbi
        lda trk_cur
        bne :-
        rts

; arranca una pista ya mismo, desde silencio (solo tras music_fade_wait)
music_now:
        sta trk_req
        sta trk_cur
        jmp trk_init

sound:
        lda mode
        beq :+
    .ifdef NOSFX
        lda #0                  ; (versión para grabar la música sin efectos)
        sta AUDC1
    .else
        jsr sfx_tick
    .endif
:       jsr fader
        lda trk_cur
        cmp #TRK_DRONE
        bne :+
        jmp drone_tick
:       cmp #TRK_NONE
        bne :+
        rts
:       jmp song_tick

; ---------------------------------------------------------------------
fader:
        inc fcnt
        lda trk_req
        cmp trk_cur
        beq @in
        lda trk_cur             ; nada sonando: cambio inmediato
        beq @switch
        lda song_done           ; una canción que ya acabó sola
        bne @switch
        lda fcnt
        and #3
        bne @r
        inc sv_att
        lda sv_att
        cmp #ATT_MAX
        bcc @r
@switch:
        jsr music_silence
        lda trk_req
        sta trk_cur
        jmp trk_init
@in:    lda sv_att              ; fundido de entrada
        beq @r
        lda fcnt
        and #3
        bne @r
        dec sv_att
@r:     rts

music_silence:
        lda #0
        sta AUDC2
        sta AUDC3
        sta AUDC4
        lda mode
        bne :+
        sta AUDC1
:       rts

; prepara la pista trk_cur
trk_init:
        lda #0
        sta song_done
        lda trk_cur
        cmp #TRK_DRONE
        beq @drone
        cmp #TRK_TITLE
        beq @title
        cmp #TRK_GO
        beq @go
        cmp #TRK_PHASE
        beq @phase
        rts
@title: lda #0
        ldx #0
        jmp song_start
@go:    lda #1
        ldx #0
        jmp song_start
@phase: lda #2
        ldx #1
        jsr song_start
        lda #ATT_MAX            ; entra desde silencio
        sta sv_att
        rts
@drone: lda #<mus_boss
        sta mbass
        sta mlead
        lda #>mus_boss
        sta mbass+1
        sta mlead+1
        lda #$28
        sta AUDCTL
        lda #0
        sta AUDC3
        lda #ATT_MAX
        sta sv_att
        rts

; ---------------------------------------------------------------------
;  Efectos (solo en juego): un único canal, la explosión manda
; ---------------------------------------------------------------------
sfx_tick:
        lda sfx2
        beq @shot
        dec sfx2
        lda sfx2
        eor #$FF
        and #$3F
        adc #30
        sta AUDF1
        lda sfx2
        lsr
        cmp #15
        bcc :+
        lda #15
:       ora #$80
        sta AUDC1
        rts
@shot:  lda sfx1
        beq @off
        dec sfx1
        lda sfx1
        asl
        asl
        eor #$3F
        clc
        adc #20
        sta AUDF1
        lda sfx1
        cmp #9
        bcc :+
        lda #8
:       ora #$A0
        sta AUDC1
        rts
@off:   lda #0
        sta AUDC1
        rts

; ---------------------------------------------------------------------
;  Dron de los jefes
; ---------------------------------------------------------------------
drone_tick:
        ldy #1
        lda (mbass),y
        cmp #$FF
        bne @play
        lda mlead               ; vuelta al principio del ciclo (sin costura)
        sta mbass
        lda mlead+1
        sta mbass+1
        lda (mbass),y
@play:  sta AUDF4
        dey
        lda (mbass),y
        sta AUDF3
        lda mbass
        clc
        adc #2
        sta mbass
        bcc :+
        inc mbass+1
:       lda #6
        sec
        sbc sv_att
        bcs :+
        lda #0
:       ora #$A0
        sta AUDC4
        rts

; ---------------------------------------------------------------------
;  Canciones: pares (nota, cuadros); nota 0 silencio, bit 7 = se apaga
;  del todo; $FF,1 = repetir · $FF,0 = fin
; ---------------------------------------------------------------------
; A = canción (0 título, 1 game over, 2 fases), X = 0 pantallas / 1 juego
song_start:
        stx sv_game
        tax
        lda song_b_lo,x
        sta sv_p
        sta sv_s
        lda song_b_hi,x
        sta sv_p+1
        sta sv_s+1
        lda song_l_lo,x
        sta sv_p+2
        sta sv_s+2
        lda song_l_hi,x
        sta sv_p+3
        sta sv_s+3
        lda #0
        sta sv_t
        sta sv_t+1
        sta sv_end
        sta sv_end+1
        sta song_done
        sta sv_att
        sta AUDC2
        sta AUDC3
        sta AUDC4
        lda sv_game
        bne :+
        sta AUDC1
        lda #$78                ; canales 1 y 3 a 1,79 MHz, 1+2 y 3+4 unidos
        sta AUDCTL
        rts
:       lda #$28                ; canal 3 a 1,79 MHz, 3+4 unidos; 1 y 2 a 64 kHz
        sta AUDCTL
        rts

song_tick:
        ldx #0
        jsr sv_voice
        ldx #1
        jsr sv_voice
        lda sv_end
        and sv_end+1
        beq :+
        lda #1
        sta song_done
:       lda beep_t              ; BEEP del truco: tapa la melodía un momento
        beq :+
        dec beep_t
        lda #<888               ; ~1 kHz en 16 bits
        sta AUDF3
        lda #>888
        sta AUDF4
        lda #$AA
        sta AUDC4
:       rts

; X = voz (0 bajo, 1 melodía)
sv_voice:
        lda sv_end,x
        beq :+
        lda #0
        jmp sv_vol
:       txa
        asl
        tay                     ; Y = 2*voz (punteros)
        lda sv_t,x
        beq :+
        jmp @run
:       ; siguiente evento
        lda sv_p,y
        sta sptr
        lda sv_p+1,y
        sta sptr+1
        sty st7
        ldy #0
        lda (sptr),y
        cmp #$FF
        bne @ev
        iny
        lda (sptr),y
        bne @loop
        lda #1
        sta sv_end,x
        lda #0
        jmp sv_vol
@loop:  ldy st7
        lda sv_s,y
        sta sv_p,y
        sta sptr
        lda sv_s+1,y
        sta sv_p+1,y
        sta sptr+1
        ldy #0
        lda (sptr),y
@ev:    sta sv_n,x
        iny
        lda (sptr),y
        sta sv_t,x
        lda #0
        sta sv_age,x
        ldy st7
        lda sv_p,y
        clc
        adc #2
        sta sv_p,y
        bcc :+
        lda sv_p+1,y
        adc #0
        sta sv_p+1,y
:       ; frecuencia
        lda sv_n,x
        and #$7F
        beq @run
        tay
        dey
        lda sv_game             ; en juego la melodía es de 8 bits
        beq @n16
        cpx #1
        bne @n16
        lda nt8,y
        sta sv_fl,x
        jmp @run
@n16:   lda nt_lo,y
        sta sv_fl,x
        lda nt_hi,y
        sta sv_fh,x
@run:   dec sv_t,x
        inc sv_age,x
        lda sv_n,x
        and #$7F
        bne :+
        lda #0
        jmp sv_vol
:       lda sv_fl,x
        sta st5
        lda sv_fh,x
        sta st6
        ; salida de la frecuencia
        lda sv_game
        bne @fg
        ; pantallas: vibrato suave en notas largas de la melodía
        cpx #1
        bne @nov
        lda sv_age,x
        cmp #14
        bcc @nov
        lda frame
        and #4
        beq @nov
        lda st6                ; + N/128 (alto*2)
        asl
        clc
        adc st5
        sta st5
        lda st6
        adc #0
        sta st6
@nov:   txa
        asl
        asl
        tay                     ; voz 0 -> AUDF1/2, voz 1 -> AUDF3/4
        lda st5
        sta AUDF1,y
        lda st6
        sta AUDF2,y
        jmp @env
@fg:    cpx #0
        bne @f8
        lda st5                ; juego, bajo -> 3+4
        sta AUDF3
        lda st6
        sta AUDF4
        jmp @env
@f8:    lda st5                ; juego, melodía -> canal 2
        sta AUDF2
@env:   ; envolvente
        lda sv_age,x
        cpx #0
        beq @eb
        lsr                     ; melodía: baja 1 cada 4 cuadros
        lsr
        sta st4
        lda sv_n,x
        bmi @fade
        ldy sv_game
        lda lead_top,y
        sec
        sbc st4
        bcc @f5
        cmp lead_min,y
        bcs @rel
@f5:    lda lead_min,y
        jmp @rel
@eb:    lsr                     ; bajo: baja 1 cada 8 cuadros
        lsr
        lsr
        sta st4
        lda sv_n,x
        bmi @fade
        lda #10
        sec
        sbc st4
        bcc @f6
        cmp #6
        bcs @rel
@f6:    lda #6
        jmp @rel
@fade:  lda sv_age,x            ; nota final: se apaga del todo
        lsr
        lsr
        lsr
        lsr
        sta st4
        lda #10
        sec
        sbc st4
        bcs sv_vol
        lda #0
        jmp sv_vol
@rel:   ldy sv_t,x              ; separa notas: últimos 2 cuadros más flojos
        cpy #2
        bcs sv_vol
        sec
        sbc #3
sv_vol: sec                     ; atenuación general (fundidos)
        sbc sv_att
        bcs :+
        lda #0
:       ora #$A0
        ldy sv_game
        bne @vg
        cpx #0
        bne :+
        sta AUDC2               ; pantallas: bajo
        rts
:       sta AUDC4               ; pantallas: melodía
        rts
@vg:    cpx #0
        bne :+
        sta AUDC4               ; juego: bajo
        rts
:       sta AUDC2               ; juego: melodía
        rts

lead_top: .byte 10,8            ; la melodía en juego, algo más baja (deja oír los efectos)
lead_min: .byte 5,4

        .segment "BSS"
sv_p:   .res 4
sv_s:   .res 4
sv_t:   .res 2
sv_n:   .res 2
sv_age: .res 2
sv_fl:  .res 2
sv_fh:  .res 2
sv_end: .res 2
sv_att: .res 1
sv_game: .res 1
song_done: .res 1
trk_req: .res 1
trk_cur: .res 1
fcnt:   .res 1
beep_t: .res 1
        .segment "CODE"
