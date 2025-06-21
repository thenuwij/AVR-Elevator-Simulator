// DESN2000 23T2 COMP Stream Project

.include "m2560def.inc"
.def temp =r22
.def require_floor = r3  
.def current_floor = r4
.def L_time = r5              ;time for timer to stop
.def H_time = r6			  ;time for timer to stop
.def counter = r7			  ;loop counter
.def row =r17				  ; keypad register setting
.def col =r18
.def mask =r19
.def temp2 =r20
.equ PORTLDIR = 0xF0
.equ INITCOLMASK = 0xEF
.equ INITROWMASK = 0x01
.equ ROWMASK = 0x0F
.equ two_se = 0x09
.def jude=r21
.def p1= r23				  ; Push button one for close door 
.equ emergency=0xE            ;the value of the * been pressed
.def emergency_flag = r8	  ;when star be press, emergency(0xE) will be store on it
.def pattern=r24			  ;store the storbe led bit change 

.equ button1 = 0b11111111

.dseg
	SecondCounter:	.byte 2			; Two-byte counter for counting seconds.
	TempCounter:	.byte 2			; Temp counter. Used to determine

.cseg
.org 0x0000
jmp RESET

.org INT1addr
jmp EXT_INT1

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

.macro do_lcd_command			;set the lcd common to PORTA(change enable bit) and PORTL(output mode)
	ldi r16, @0
	rcall lcd_command
	rcall lcd_wait
.endmacro

.macro do_lcd_data				;store the lcd data
	dec jude
	breq assci
	ldi r16, @0
	rjmp call_fun
assci:							;change the number to ASSCI
	ldi r16, @0
	add r16, temp
call_fun:
	rcall lcd_data
	rcall lcd_wait
.endmacro

RESET:
	ldi temp, low(RAMEND)		;set the stack
	out SPL, temp
	ldi temp, high(RAMEND)
	out SPH, temp

	ldi temp, PORTLDIR ; columns are outputs, rows are inputs
	STS DDRL, temp     ; cannot use out
	ser temp
	clr current_floor
	out DDRC, temp		; Make PORTC all outputs
	out DDRG, temp

	ser r16
	out DDRF, r16		;set the PORTA and PORTF to output
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

	lds r24, TempCounter		;Every time timer0 is executed, tempCouter is incremented by one
	lds r25, TempCounter+1
	adiw r25:r24, 1

	cp r24, L_time			; Check if (r25:r24) = 15625
	mov temp, H_time		; 15625 = 2*10^6/128
	cpc r25, temp
	brne NotSecond

	mov temp, L_time		;Check whether the timer time is 2 seconds or not
	cpi temp, two_se		; if not, it can not change current floor, it just can open/cloes door and run motor
	brne stop_count

	
move_next:                         ;move the lift to next required level level by level
	cp current_floor, require_floor   ; if(current_floor < require_floor)
	brge move_down
	inc current_floor
	mov temp, current_floor
	rcall convert_end				;function is chnage the current_floor(decimal) to binary and show it on led and lcd


final:
	clear TempCounter				
	lds r24, SecondCounter
	lds r25, SecondCounter+1
	adiw r25:r24, 2
	sts SecondCounter, r24
	sts SecondCounter+1, r25
	cbi PORTA, 1					;blink the strobe led(set 1)
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
move_down:             ; the movement of the lift when it moves downward
	dec current_floor
	mov temp, current_floor
	rcall convert_end
	rjmp final

stop_count:            ; counter++, it is a flag to check the timer time, if it is one, it can open/close door 1 second or stay 3 seconds
	inc counter
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
	
convert_end:   ; convert the DEC to BIN to show the current_floor
	ldi jude, 8
	cp jude, temp   ;if (current_floor > 8)
	brsh under_8

upper_8:         ; case when the current_floor greater than 8
	ldi r18, 0xff
	ldi r19, 0x3
	mov r20, temp
	sub r20, jude
	cpi r20, 2
	breq output1

loop1:
	lsr r19

output1:          ; display the current_floor 
	out PORTC, r18
	out PORTG, r19
	rjmp end

under_8:		;case when the current_floor smaller than 8
	ldi r18, 0xff
	ldi r19, 0
	sub jude, temp
	breq output2

loop2:
	lsr r18
	dec jude
	breq output2
	rjmp loop2

output2:		;display the current_floor
	out PORTC, r18
	out PORTG, r19

end:			;case when the emergency_happend
	ldi temp, 0x0E
	cp emergency_flag, temp
	breq energency_show
	rcall lcd_init
	ret

energency_show:  ; show the emergency on lcd
	rcall lcd_show
	sbi PORTA, 1
	in pattern, PORTA
	out PORTA, pattern
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

	ldi jude, 9
	do_lcd_data 'N'				;store the data to lcd
	do_lcd_data 'e'
	do_lcd_data 'x'
	do_lcd_data 't'
	do_lcd_command 0b00010100 ;shift right cursor 

	do_lcd_data 'S'
	do_lcd_data 't'
	do_lcd_data 'o'
	do_lcd_data 'p'
	do_lcd_command 0b00010100 ;shift right cursor
	mov temp, require_floor
	cpi temp, 10
	breq ten_floor2				;compare the scan keypad number and the 10
	do_lcd_data 48				;if keypad number equal the 10
	jmp current_show

ten_floor2:
	dec jude
	do_lcd_data 49
	do_lcd_data 48

current_show:
	do_lcd_command 0b11000000 ; change to second line address
	ldi jude, 13

	do_lcd_data 'C'				;store the data to lcd
	do_lcd_data 'u'
	do_lcd_data 'r'
	do_lcd_data 'r'
	do_lcd_data 'e'
	do_lcd_data 'n'
	do_lcd_data 't'
	do_lcd_command 0b00010100 ;shift right cursor 
	do_lcd_data 'F'
	do_lcd_data 'l'
	do_lcd_data 'o'
	do_lcd_data 'o'
	do_lcd_data 'r'
	do_lcd_command 0b00010100 ;shift right cursor

	mov temp, current_floor
	cpi temp, 10
	breq ten_floor				;compare the scan keypad number and the 10
	do_lcd_data 48				;if keypad number equal the 10
	ret							; jump to ten_flloor, store two number 1 and 0

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

lcd_command:				;set the lcd common to PORTA(change enable bit) and PORTL(output mode)
	out PORTF, r16
	rcall sleep_1ms
	lcd_set LCD_E
	rcall sleep_1ms
	lcd_clr LCD_E
	rcall sleep_1ms
	ret

lcd_data:					;load the data
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

motor_move:			;start the motor

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

motor_stop:      ; stop the motor

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


main:		; main function to control the lift

	rcall EXT_INT1_INIT					; enable push button 1 interrupt for close door
	
	clr temp
	out DDRB, temp
	ser temp
	out PORTB, temp
	ldi p1, 0

	clr emergency_flag
	clr counter
	rcall keypad_main      ; receive the signal from the keyboard 
	mov temp, require_floor  ; check wheter require_floor is emergeny button
	cpi temp, emergency
	breq emergency_stop

main_next:					; start the timer to move level by level
	ldi temp, low(15625)    ; timer will be 2 second
	mov L_time, temp
	ldi temp, high(15625)
	mov H_time, temp
	rcall excute			; initial the timer
	
halt:
	cp current_floor, require_floor   ;if(current_floor = require_floor) go to next step
	breq stop						  ; otherwise move lift to the require floor
	rjmp halt

stop:
	ldi temp, low(7812)                ; set the timer to be 1 second 
	mov L_time, temp
	ldi temp, high(7812)
	mov H_time, temp

stop_loop:
	mov temp, current_floor				;display the current floor
	rcall convert_end
	rcall motor_move					; start the motor for move 1 second

	cpi p1, 1							; check if close door button was pressed
	breq close_door_seting
	mov temp, counter
	cpi temp, 1
	breq stay_current_seting			; after 1 second go to next state
	rjmp stop_loop

stay_current_seting:					; state for the door of the lift to be opened
	ldi temp, low(23437)				; set timer to be 3 second
	mov L_time, temp
	ldi temp, high(23437)
	mov H_time, temp
	clr counter

stay_current:
	mov temp, current_floor				; display the current floor on led and lcd
	rcall convert_end
	rcall motor_stop					;stop the motor for 3 second

	cpi p1, 1							; Check if close door button was pressed 
	breq close_door_seting
	mov temp, counter
	cpi temp, 1
	breq close_door_seting              ; after the door be opened for 3 second move to next state
	rjmp stay_current

close_door_seting:						;state for door to be closed
	ldi temp, low(7812)					; set the timer to be 1 second
	mov L_time, temp
	ldi temp, high(7812)
	mov H_time, temp
	clr counter
	rcall excute

close_door:				
	mov temp, current_floor				; display the current floor on led and lcd
	rcall convert_end
	rcall motor_move					; start the motor for 1 second
	mov temp, counter
	cpi temp, 1							;after the door of the lift been closed move to next state
	breq go_back
	rjmp close_door

go_back:								;setting for the lift to recieve next operation
	clr p1
	rcall motor_stop					; stop the motor the door is closed
	clr counter						
	ldi temp, 0b00000000				; shut down the timer
	out TCCR0B, temp
	mov temp, current_floor				; display the current floor on led and lcd
	rcall convert_end
	rjmp main
		
emergency_stop:							; case when emergency happend
	rcall lcd_show						; show the emergency imformation on lcd
	mov emergency_flag, require_floor	
	ldi temp, 1
	mov require_floor, temp
	rjmp main_next

EXT_INT1_INIT:
	ldi r25, 0b00000010
	sts EICRA, r25
	sbi EIMSK, INT1
	sei
	ret

EXT_INT1:
	push temp
	in temp, SREG
	push temp

	in temp, PINB
	clr r26
	ldi r26, button1
	cp temp, r26
	BRNE epilogue1
	
	rcall sleep_12ms
	cp temp, r26
	BRNE epilogue1

	ldi p1, 1 
	ldi temp, 0
	out TCCR0B, temp


epilogue1:
	pop temp
	out SREG, temp
	pop temp

	reti

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

	do_lcd_data 'E'		;store the data
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

	do_lcd_command 0b00010100 ; shift the cursor

	do_lcd_data '0'
	do_lcd_data '0'
	do_lcd_data '0'
	ret

sleep_12ms:
	rcall sleep_1ms
	rcall sleep_1ms
	rcall sleep_1ms
	rcall sleep_1ms
	rcall sleep_1ms
	rcall sleep_1ms
	rcall sleep_1ms
	rcall sleep_1ms
	rcall sleep_1ms
	rcall sleep_1ms
	rcall sleep_1ms
	rcall sleep_1ms
	ret
