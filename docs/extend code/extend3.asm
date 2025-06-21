/*
 * extend3.asm
 *
 *  Created: 3/08/2023 4:33:15 PM
 *   Author: Oswald
 */ 
.include "m2560def.inc"
.def temp =r22
.def require_floor = r3
.def current_floor = r4
.def L_time = r5
.def H_time = r6
.def stop_time = r7
.def row =r17
.def col =r18
.def mask =r19
.def temp2 =r20
.equ PORTLDIR = 0xF0
.equ INITCOLMASK = 0xEF
.equ INITROWMASK = 0x01
.equ ROWMASK = 0x0F
.equ two_se = 0x09
.def jude=r21
.equ emergency=0xE
.def emergency_flag = r23


.dseg
	SecondCounter:	.byte 2			; Two-byte counter for counting seconds.
	TempCounter:	.byte 2			; Temp counter. Used to determine

.cseg
.org 0x0000
jmp RESET

.org OVF0addr
	jmp Timer0OVF
.org 0x72

;The macro clears a word(2 bytes) in a memory
;the parameter @0 is the memory address for that word
.macro clear
	ldi YL, LOW(@0)				; load the memory address to Y
	ldi YH, HIGH(@0)
	clr temp
	st Y+, temp					; clear the two bytes at @0 in SRAM
	st Y, temp
.endmacro

.macro do_lcd_command
	ldi r16, @0
	rcall lcd_command
	rcall lcd_wait
.endmacro

.macro do_lcd_data
	dec jude
	breq assci
	ldi r16, @0
	rjmp call_fun
assci:
	ldi r16, @0
	add r16, temp
call_fun:
	rcall lcd_data
	rcall lcd_wait
.endmacro

RESET:
	ldi temp, low(RAMEND)
	out SPL, temp
	ldi temp, high(RAMEND)
	out SPH, temp
	ldi temp, PORTLDIR ; columns are outputs, rows are inputs
	STS DDRL, temp     ; cannot use out
	ser temp
	clr current_floor
	out DDRC, temp ; Make PORTC all outputs
	out DDRG, temp

	ser r16
	out DDRF, r16
	out DDRA, r16
	clr r16
	out PORTF, r16
	out PORTA, r16

	rjmp main

Timer0OVF:						; set the timer0 interrupt
	in temp, SREG				; In case the flag inside SREG is cleared by interrupt
	push temp					; so, we store SREG to the stack
	push YH
	push YL
	push r25
	push r24

	lds r24, TempCounter
	lds r25, TempCounter+1
	adiw r25:r24, 1

	cp r24, L_time			; Check if (r25:r24) = 15625
	mov temp, H_time		; 15625 = 2*10^6/128
	cpc r25, temp
	brne NotSecond

	mov temp, L_time
	cpi temp, two_se
	brne stop_count

	
move_next:
	cp current_floor, require_floor
	brge move_down
	inc current_floor
	mov temp, current_floor
	rcall convert_end


final:
	clear TempCounter
	lds r24, SecondCounter
	lds r25, SecondCounter+1
	adiw r25:r24, 2
	sts SecondCounter, r24
	sts SecondCounter+1, r25
	rjmp EndIf

NotSecond:
	sts TempCounter, r24		
	sts TempCounter+1, r25

EndIF:
	pop r24
	pop r25
	pop YL
	pop YH
	pop temp
	out SREG, temp
	reti
move_down: 
	dec current_floor
	mov temp, current_floor
	rcall convert_end
	rjmp final

stop_count:
	inc stop_time
	rjmp final

; main keeps scanning the keypad to find which key is pressed.
keypad_main:
	ldi mask, INITCOLMASK ; initial column mask
	clr col ; initial column

colloop:
	STS PORTL, mask ; set column to mask value
	; (sets column 0 off)
	ldi temp, 0xFF ; implement a delay so the
	; hardware can stabilize
	
delay:
	dec temp
	brne delay
	LDS temp, PINL ; read PORTL. Cannot use in 
	andi temp, ROWMASK ; read only the row bits
	cpi temp, 0xF ; check if any rows are grounded
	breq nextcol ; if not go to the next column
	ldi mask, INITROWMASK ; initialise row check
	clr row ; initial row
	
rowloop:      
	mov temp2, temp
	and temp2, mask ; check masked bit
	brne skipconv ; if the result is non-zero,
	; we need to look again
	rcall convert ; if bit is clear, convert the bitcode
	ret
	
skipconv:
	inc row ; else move to the next row
	lsl mask ; shift the mask to the next bit
	jmp rowloop          

nextcol:     
	cpi col, 3 ; check if we are on the last column
	breq keypad_main ; if so, no buttons were pushed,
	; so start again.
	; else shift the column mask:
	sec ; We must set the carry bit
	rol mask ; and then rotate left by a bit,
	; shifting the carry into
	; bit zero. We need this to make
	; sure all the rows have
	; pull-up resistors
	inc col ; increment column value
	jmp colloop ; and check the next column
	; convert function converts the row and column given to a
	; binary number and also outputs the value to PORTC.
	; Inputs come from registers row and col and output is in
	; temp.
	
convert:
	cpi col, 3 ; if column is 3 we have a letter
	breq letters
	cpi row, 3 ; if row is 3 we have a symbol or 0
	breq symbols
	mov temp, row ; otherwise we have a number (1-9)
	lsl temp ; temp = row * 2
	add temp, row ; temp = row * 3
	add temp, col ; add the column address
	; to get the offset from 1
	inc temp ; add 1. Value of switch is
	; row*3 + col + 1.
	jmp floor_num
	
letters:
	ldi temp, 0xA
	add temp, row ; increment from 0xA by the row value
	jmp convert_end
	
symbols:
	cpi col, 0 ; check if we have a star
	breq star
	cpi col, 1 ; or if we have zero
	breq zero
	ldi temp, 0xF ; we'll output 0xF for hash
	jmp convert_end
	
star:
	ldi temp, 0xE ; we'll output 0xE for star
	jmp floor_num
	
zero:
	ldi temp, 10 ; set to ten

floor_num :
	mov require_floor, temp
	ret
	
convert_end:
	ldi jude, 8
	cp jude, temp
	brsh under_8

upper_8:
	ldi r18, 0xff
	ldi r19, 0x3
	mov r20, temp
	sub r20, jude
	cpi r20, 2
	breq output1

loop1:
	lsr r19

output1:
	out PORTC, r18
	out PORTG, r19
	rjmp end

under_8:
	ldi r18, 0xff
	ldi r19, 0
	sub jude, temp
	breq output2

loop2:
	lsr r18
	dec jude
	breq output2
	rjmp loop2

output2:
	out PORTC, r18
	out PORTG, r19

end:
	cpi emergency_flag, 0x0E
	breq energency_show
	rcall lcd_init
	ret

energency_show:
	rcall lcd_show
	ret


lcd_init:
	ser r16
	out DDRF, r16
	out DDRA, r16
	clr r16
	out PORTF, r16
	out PORTA, r16

	do_lcd_command 0b00111000 ; 2x5x7
	rcall sleep_5ms
	do_lcd_command 0b00111000 ; 2x5x7
	rcall sleep_1ms
	do_lcd_command 0b00111000 ; 2x5x7
	do_lcd_command 0b00111000 ; 2x5x7
	do_lcd_command 0b00001000 ; display off?
	do_lcd_command 0b00000001 ; clear display
	do_lcd_command 0b00000110 ; increment, no display shift
	do_lcd_command 0b00001100 ; Cursor on, bar, no blink
	do_lcd_command 0b11000000 ; change to second line address
	ldi jude, 13

	do_lcd_data 'F'
	do_lcd_data 'l'
	do_lcd_data 'o'
	do_lcd_data 'o'
	do_lcd_data 'r'
	do_lcd_command 0b00010100 ;shift right cursor 
	do_lcd_data 'r'
	do_lcd_data 'e'
	do_lcd_data 'q'
	do_lcd_data 'u'
	do_lcd_data 'e'
	do_lcd_data 's'
	do_lcd_data 't'
	do_lcd_command 0b00010100 ;shift right cursor

	cpi temp, 10
	breq ten_floor
	do_lcd_data 48
	ret

ten_floor:
	dec jude
	do_lcd_data 49
	do_lcd_data 48
	ret


.equ LCD_RS = 7
.equ LCD_E = 6
.equ LCD_RW = 5
.equ LCD_BE = 4

.macro lcd_set
	sbi PORTA, @0
.endmacro
.macro lcd_clr
	cbi PORTA, @0
.endmacro

;
; Send a command to the LCD (r16)
;

lcd_command:
	out PORTF, r16
	rcall sleep_1ms
	lcd_set LCD_E
	rcall sleep_1ms
	lcd_clr LCD_E
	rcall sleep_1ms
	ret

lcd_data:
	out PORTF, r16
	lcd_set LCD_RS
	rcall sleep_1ms
	lcd_set LCD_E
	rcall sleep_1ms
	lcd_clr LCD_E
	rcall sleep_1ms
	lcd_clr LCD_RS
	ret

lcd_wait:
	push r16
	clr r16
	out DDRF, r16
	out PORTF, r16
	lcd_set LCD_RW
lcd_wait_loop:
	rcall sleep_1ms
	lcd_set LCD_E
	rcall sleep_1ms
	in r16, PINF
	lcd_clr LCD_E
	sbrc r16, 7
	rjmp lcd_wait_loop
	lcd_clr LCD_RW
	ser r16
	out DDRF, r16
	pop r16
	ret

excute:
	clear TempCounter				; set the temp counter to 0
	clear SecondCounter				; set the second counter to 0
	ldi temp, 0b00000000
	out TCCR0A, temp				
	ldi temp, 0b00000010			
	out TCCR0B, temp				; Prescaling value = 8
	ldi temp, 1<<TOIE0				; =128 microseconds
	sts TIMSK0, temp				; T/C0 interrupt enable
	sei		
	ret

motor_move:

	; Set OC3B (PE4) as output for motor control
    ldi temp, 0b00010000
    out DDRE, temp

    ; Set the initial duty cycle to 20% (51/255)
	clr temp
    sts OCR3BH, temp
	ldi temp, 255
    sts OCR3BL, temp

    ; Initialize Timer 3 for phase correct PWM mode with prescaler 1
    ldi temp, (1 << CS30)   
    sts TCCR3B, temp
    ldi temp, (1 << WGM30) | (1 << COM3B1)    ; Fast PWM, prescaler = 1
    sts TCCR3A, temp
	ret

motor_stop:

	; Set OC3B (PE4) as output for motor control
    ldi temp, 0b00010000
    out DDRE, temp

    ; Set the initial duty cycle to 20% (51/255)
	clr temp
    sts OCR3BH, temp
	ldi temp, 0
    sts OCR3BL, temp

    ; Initialize Timer 3 for phase correct PWM mode with prescaler 1
    ldi temp, (1 << CS30)   
    sts TCCR3B, temp
    ldi temp, (1 << WGM30) | (1 << COM3B1)    ; Fast PWM, prescaler = 1
    sts TCCR3A, temp
	ret

.equ F_CPU = 16000000
.equ DELAY_1MS = F_CPU / 4 / 1000 - 4
; 4 cycles per iteration - setup/call-return overhead

sleep_1ms:
	push r24
	push r25
	ldi r25, high(DELAY_1MS)
	ldi r24, low(DELAY_1MS)
delayloop_1ms:
	sbiw r25:r24, 1
	brne delayloop_1ms
	pop r25
	pop r24
	ret

sleep_5ms:
	rcall sleep_1ms
	rcall sleep_1ms
	rcall sleep_1ms
	rcall sleep_1ms
	rcall sleep_1ms
	ret


main:
	clr stop_time
	rcall keypad_main
	mov temp, require_floor
	cpi temp, emergency
	breq emergency_stop

main_next:
	ldi temp, low(15625)
	mov L_time, temp
	ldi temp, high(15625)
	mov H_time, temp
	rcall excute
	
halt:
	cp current_floor, require_floor
	breq stop
	rjmp halt

stop:
	;ldi temp, 0b00000000
	;sts TIMSK0, temp
	ldi temp, low(7812)
	mov L_time, temp
	ldi temp, high(7812)
	mov H_time, temp
	;clr require_floor
	;rcall excute

stop_loop:
	mov temp, current_floor
	rcall convert_end
	rcall motor_move
	mov temp, stop_time
	cpi temp, 1
	breq stay_current_seting
	rjmp stop_loop

stay_current_seting:
	ldi temp, low(23437)
	mov L_time, temp
	ldi temp, high(23437)
	mov H_time, temp
	clr stop_time

stay_current:
	mov temp, current_floor
	rcall convert_end
	rcall motor_stop
	mov temp, stop_time
	cpi temp, 1
	breq close_door_seting
	rjmp stay_current

close_door_seting:
	ldi temp, low(7812)
	mov L_time, temp
	ldi temp, high(7812)
	mov H_time, temp
	clr stop_time

close_door:
	mov temp, current_floor
	rcall convert_end
	rcall motor_move
	mov temp, stop_time
	cpi temp, 1
	breq go_back
	rjmp close_door

go_back:
	rcall motor_stop
	clr stop_time
	ldi temp, 0b00000000			
	out TCCR0B, temp
	mov temp, current_floor
	rcall convert_end
	rjmp main

emergency_stop:
	rcall lcd_show
	mov emergency_flag, require_floor
	ldi temp, 1
	mov require_floor, temp
	rjmp main_next
	


lcd_show:
	do_lcd_command 0b00111000 ; 2x5x7
	rcall sleep_5ms
	do_lcd_command 0b00111000 ; 2x5x7
	rcall sleep_1ms
	do_lcd_command 0b00111000 ; 2x5x7
	do_lcd_command 0b00111000 ; 2x5x7
	do_lcd_command 0b00001000 ; display off?
	do_lcd_command 0b00000001 ; clear display
	do_lcd_command 0b00000110 ; increment, no display shift
	do_lcd_command 0b00001100 ; Cursor on, bar, no blink

	do_lcd_data 'E'
	do_lcd_data 'm'
	do_lcd_data 'e'
	do_lcd_data 'r'
	do_lcd_data 'g'
	do_lcd_data 'e'
	do_lcd_data 'n'
	do_lcd_data 'c'
	do_lcd_data 'y'

	do_lcd_command 0b11000000 ;change to DD RAM addresss

	do_lcd_data 'c'
	do_lcd_data 'a'
	do_lcd_data 'l'
	do_lcd_data 'l'

	do_lcd_command 0b00010100

	do_lcd_data '0'
	do_lcd_data '0'
	do_lcd_data '0'
	ret

programe_stop:
	rjmp programe_stop
