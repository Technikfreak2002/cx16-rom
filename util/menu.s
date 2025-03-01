; System menu

.macpack cbm

.include "io.inc"
.include "kernal.inc"
.include "banks.inc"

.export util_menu
.import util_control
.import util_hexedit

VERA_TILEMAP = $1b000

.segment "MENUZP" : zeropage
ptr:
	.res 2

.segment "MENUBSS"
screen_width:
	.res 1
screen_height:
	.res 1
selection:
	.res 1
temp:
	.res 1

.segment "MENU"

.proc util_menu: near
	; initialize variables
	stz selection

	jsr setup_screen
	jmp show_menu

	jmp util_control
.endproc

.proc setup_screen: near
	jsr screen        ;get current screen dimensions
	stx screen_width  ;get current screen dimensions
	sty screen_height ;get current screen dimensions

	; put it back into PETSCII upper/gfx mode
	lda #$8f
	jsr bsout
	lda #$8e
	jsr bsout
	; clear screen
	lda #$93
	jsr bsout

	; we'll keep the current petscii colors

	rts
.endproc

.proc show_menu: near
	lda #<VERA_TILEMAP
	sta VERA_ADDR_L
	lda #>VERA_TILEMAP
	sta VERA_ADDR_M
	lda #($20 | ^VERA_TILEMAP)
	sta VERA_ADDR_H

	ldx #0
@mt:
	lda menu_title,x
	beq @title_cont
	sta VERA_DATA0
	inx
	bra @mt
@title_cont:
	lda screen_width
	dec
	sta temp
	; write out the rest of the top line of the screen
	lda #$40
@mtl:
	sta VERA_DATA0
	inx
	cpx temp
	bcc @mtl
	; upper right corner
	lda #$6e
	sta VERA_DATA0
	; now draw the bottom border
	lda #<VERA_TILEMAP
	sta VERA_ADDR_L
	lda screen_height
	dec
	clc
	adc #>VERA_TILEMAP
	sta VERA_ADDR_M
	lda #$6d
	sta VERA_DATA0
	lda #$40
	ldx #1
@mbl:
	sta VERA_DATA0
	inx
	cpx temp
	bcc @mbl
	; bottom right corner
	lda #$7d
	sta VERA_DATA0

	; now do left line
	lda #<VERA_TILEMAP
	sta VERA_ADDR_L
	lda #(>VERA_TILEMAP) + 1 ; row 1
	sta VERA_ADDR_M
	lda #($90 | ^VERA_TILEMAP) ; auto increment 256 (one row)
	sta VERA_ADDR_H

	lda #$42
	ldx #2 ; offset by 1
@mll:
	sta VERA_DATA0
	inx
	cpx screen_height
	bcc @mll

	; now do right line
	lda screen_width
	dec
	asl
	adc #<VERA_TILEMAP
	sta VERA_ADDR_L
	lda #(>VERA_TILEMAP) + 1 ; row 1
	sta VERA_ADDR_M

	lda #$42
	ldx #2 ; offset by 1
@mrl:
	sta VERA_DATA0
	inx
	cpx screen_height
	bcc @mrl

	lda #($20 | ^VERA_TILEMAP) ; auto increment 2
	sta VERA_ADDR_H

	ldx #0
@itemloop:
	txa
	asl
	tay

	lda menuitems,y
	sta ptr
	lda menuitems+1,y
	beq @enditems
	sta ptr+1

	lda #(<VERA_TILEMAP) + 2 ; first character in row
	sta VERA_ADDR_L
	txa
	clc
	adc #(>VERA_TILEMAP) + 1 ; row
	sta VERA_ADDR_M

	; invert text if selected
	stz temp
	lda #$80
	cpx selection
	bne :+
	sta temp
:	ldy #0
@iterloop:
	lda (ptr),y
	beq @enditer
	ora temp
	sta VERA_DATA0
	iny
	bne @iterloop

@enditer:
	iny
	iny
	lda #$20
	ora temp
@spaceiter:
	sta VERA_DATA0
	iny
	cpy screen_width
	bne @spaceiter

	inx
	bra @itemloop
@enditems:
	; handle keystrokes
keys:
	jsr getin
	beq keys
	cmp #13 ; return
	beq go
	cmp #$91
	beq up
	cmp #$11
	beq down
	cmp #27
	beq esc
	bra keys
go:
	lda selection
	asl
	tax
	jmp (menu_jumptable,x)
up:
	lda selection
	dec
	bmi keys
	sta selection
	jmp show_menu
down:
	lda selection
	inc
	cmp #MENUITEM_CNT
	bcs keys
	sta selection
	jmp show_menu
esc:
	jmp to_basic

.endproc

to_basic:
	lda #$93 ; clear screen
	jsr bsout
	rts

menu_title:
	.byte $70,$40
	scrcode "X16 MENU"
	.byte 0

MENUITEM_CNT = 3

menuitems:
	.word menu0, menu1, menu2, 0

menu_jumptable:
	.word util_control, util_hexedit, to_basic

menu0:
	scrcode "CONTROL PANEL"
	.byte 0
menu1:
	scrcode "HEXEDIT"
	.byte 0
menu2:
	scrcode "EXIT TO BASIC"
	.byte 0
