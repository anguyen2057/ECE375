;
; Lab7_Main2.asm
;
; Created: 12/3/2024 4:40:02 AM
; Author : Anguyen2057
;


;***********************************************************
;*
;*	This is the TRANSMIT skeleton file for Lab 7 of ECE 375
;*
;*  	Rock Paper Scissors
;* 	Requirement:
;* 	1. USART1 communication
;* 	2. Timer/counter1 Normal mode to create a 1.5-sec delay
;***********************************************************
;*
;*	 Author: Enter your name
;*	   Date: Enter Date
;*
;***********************************************************

.include "m32U4def.inc"         ; Include definition file

;***********************************************************
;*  Internal Register Definitions and Constants
;*	Register r20-r22 are reserved
;***********************************************************
.def    mpr = r16               ; Multi-Purpose Register
.def	temp = r17				; Tempo Register
.def	gesture_send = r18		; Hold the sending gesture code
.def	ready_flag = r19		; 


.def	gesture_receive = r23
.def	counter = r24
.def	counter2 = r25


; Use this signal code between two boards for their game ready
.equ    SendReady = 0b11111111


;***********************************************************
;*  Preload Value = 0x48E5
;*  Prescaler = 256 => timer increment time = 256/8MHz = 32 micro seconds
;*  => total timer count to get 1.5 secs = 1.5/ 32 microsec = 46875
;*  which is okay since Timer/Counter1 is 16 bits
;*  => Preload value = 65536 - 46875 = 18661 = 0x48E5
;***********************************************************
.equ PRELOAD_HIGH = 0x48       ; High byte of preload value
.equ PRELOAD_LOW  = 0xE5       ; Low byte of preload value


.equ ROCK_CODE = 0x01
.equ PAPER_CODE = 0x02
.equ SCISSORS_CODE = 0x03



;***********************************************************
;*  Start of Code Segment
;***********************************************************
.cseg                           ; Beginning of code segment

;***********************************************************
;*  Interrupt Vectors
;***********************************************************
.org	$0000						; Beginning of IVs
		rjmp	INIT				; Reset interrupt

.org	$0002
		rcall	Input_4				; Call PD7 function
		reti

.org	$0004
		rcall	Input_7				; Call PD4 function
		reti

.org	$0028
		rcall	WAIT_1_Half			; $0028 TIMER1 OVF Timer/Counter1 Overflow page 63 DATASHEET
		reti

.org	$0032
		rcall	USART_Receive		; USART1, Rx complete interrupt
		reti

.org	$0056						; End of Interrupt Vectors

;***********************************************************
;*  Program Initialization
;***********************************************************
INIT:
	;Stack Pointer (VERY IMPORTANT!!!!)
		ldi mpr, high(RAMEND)	; Load high byte of RAMEND
		out SPH, mpr			; Set high byte of stack pointer
		ldi mpr, low(RAMEND)	; Load low byte of RAMEND
		out SPL, mpr			; Set low byte of stack pointer


	;I/O Ports

		; Initialize Port B for output
		ldi		mpr, 0xFF
		out		DDRB, mpr		; Set DDR register for Port B
		ldi		mpr, 0x00
		out		PORTB, mpr		; Set the default output for Port B

		; Initialize Port D for input
		ldi		mpr, 0x00
		out		DDRD, mpr		; Set DDR register for Port D
		ldi		mpr, 0x03
		out		PORTD, mpr		; Set Port D to Input with Hi

		ldi		mpr, (1<<PD3)	; Set Port D pin 2 (RXD1) for input
		out		DDRD, mpr		; and Port D pin 3 (TXD1) for output

		; Set the Interrupt Sense Control to falling edge
		ldi		mpr, (1<<ISC01) | (0<<ISC00) | (1<<ISC11) | (0<<ISC10)
		sts		EICRA, mpr		; Use sts, EICRA in extended I/O space

		; Configure the External Interrupt Mask
		ldi		mpr, (1<<INT0) | (1<<INT1)
		out		EIMSK, mpr



	;USART1

		; Set double data rate
		ldi		mpr, (1 << U2X1)
		sts		UCSR1A, mpr

		; Set baudrate at 2400bps
		; UBRR1 = 416 = 0x01A0 => high = 0x01 and low = 0xA0
		ldi     mpr, high(0x01A0)	; Set Baud Rate to 2400 bps
		sts     UBRR1H, mpr			; Double-Speed => divider becomes 8
		ldi		mpr, low(0x01A0)	; Look at Slide 96 in Chap 5
		sts		UBRR1L, mpr


		; Set frame format: 8-bit data, 2 stop bits
		ldi     mpr, (1 << UCSZ11) | (1 << UCSZ10) | (1 << USBS1)
		sts     UCSR1C, mpr

		;Enable receiver and transmitter
		ldi     mpr, (1 << RXEN1) | (1 << TXEN1) | (1 << RXCIE1) | (0 << UCSZ12)	; Enable RX and TX
		sts     UCSR1B, mpr


		
		;Set frame format: 8 data bits, 2 stop bits

	;TIMER/COUNTER1
		;Set Normal mode
		ldi		mpr, 0x00			; Normal mode (WGM bits all 0)
		sts		TCCR1A, mpr
		ldi		mpr, (1 << CS12)	; Prescaler = 256
		sts		TCCR1B, mpr


	;Other
		; Initialize LCD
		rcall LCDInit			; Initialize LCD
		rcall LCDBacklightOn	; Turn on LCD backlight
		rcall LCDClr			; Clear LCD initially

		clr		temp
		clr		ready_flag
		clr		gesture_receive
		clr		gesture_send

		rcall	Begin

		sei


;***********************************************************
;*  Main Program
;***********************************************************
MAIN:

	;TODO: ???

		rjmp	MAIN

;***********************************************************
;*	Functions and Subroutines
;***********************************************************
Begin:
		ldi ZL, LOW(STRING_START1 << 1)
		ldi ZH, HIGH(STRING_START1 << 1)
		ldi YL, LOW(0x0100)				; Line 1 SRAM address
		ldi YH, HIGH(0x0100)
		rcall CopyToSRAM

		ldi ZL, LOW(STRING_START2 << 1)
		ldi ZH, HIGH(STRING_START2 << 1)
		ldi YL, LOW(0x0110)     ; Line 2 SRAM address
		ldi YH, HIGH(0x0110)
		rcall CopyToSRAM

		rcall  LCDWrite 


		ret


;-----------------------------------------------------------
; Func: 
; Desc: 
;	
;-----------------------------------------------------------
Game_Start:
		rcall	LCDClr
		ldi		ZL, LOW(STRING_START3 << 1)
		ldi		ZH, HIGH(STRING_START3 << 1)
		ldi		YL, LOW(0x0100)				; Line 1 SRAM address
		ldi		YH, HIGH(0x0100)
		rcall	CopyToSRAM

		rcall	LCDWrite 


		ldi		mpr, SendReady
		cp		gesture_receive, mpr
		brne	LETGO
		cp		gesture_send, mpr
		brne	LETGO
		rcall	Count_Down

LETGO:
		ret

;-----------------------------------------------------------
; Func: 
; Desc: 
;		
;-----------------------------------------------------------
Input_4:
		cpi READY_FLAG, 1			; Check if READY_FLAG is set
		brne PD4_DISABLED			; Exit if PD7 has not been pressed


		cpi temp, 3					; Check if temp exceeds 2
		brlt CONTINUE
		ldi temp, 0					; Reset to 0 if out of bounds
CONTINUE:

		rcall LCDClr				; Clear LCD before updating

		; Load string 1 into the data memory
		ldi    ZL, LOW(STRING_START3 << 1)			; Load low byte of string 1 address
		ldi    ZH, HIGH(STRING_START3 << 1)			; Load high byte of string 1 address

		ldi    YL, LOW(0x0100)
		ldi    YH, HIGH(0x0100)						; Point to start of Line 1 in SRAM

		rcall  CopyToSRAM			; Copy name to Line 1


		cpi		temp, 0
		breq	ROCK1

		cpi		temp, 1
		breq	PAPER1

		cpi		temp, 2
		breq	SCISSORS1


ROCK1:
		; Load string 2 into the data memory
		ldi    ZL, LOW(STRING_ROCK_0 << 1)			; Load low byte of string 2 address
		ldi    ZH, HIGH(STRING_ROCK_0 << 1)			; Load high byte of string 2 address

		ldi    YL, LOW(0x0110)
		ldi    YH, HIGH(0x0110)		; Point to start of Line 2 in SRAM

		rcall  CopyToSRAM			; Copy message to Line 2

		ldi		gesture_send, ROCK_CODE

		rjmp DONE1

PAPER1:
		; Load string 2 into the data memory
		ldi    ZL, LOW(STRING_PAPER_1 << 1)			; Load low byte of string 2 address
		ldi    ZH, HIGH(STRING_PAPER_1 << 1)		; Load high byte of string 2 address

		ldi    YL, LOW(0x0110)
		ldi    YH, HIGH(0x0110)		; Point to start of Line 2 in SRAM

		rcall  CopyToSRAM			; Copy message to Line 2

		ldi		gesture_send, PAPER_CODE

		rjmp DONE1

SCISSORS1:
		; Load string 2 into the data memory
		ldi    ZL, LOW(STRING_SCISSORS_2 << 1)		; Load low byte of string 2 address
		ldi    ZH, HIGH(STRING_SCISSORS_2 << 1)		; Load high byte of string 2 address

		ldi    YL, LOW(0x0110)
		ldi    YH, HIGH(0x0110)		; Point to start of Line 2 in SRAM

		rcall  CopyToSRAM			; Copy message to Line 2

		ldi		gesture_send, SCISSORS_CODE

		rjmp DONE1



DONE1:
		rcall LCDWrite
		inc temp					; Increment the gesture state
		rcall	USART_Transmit


PD4_DISABLED:
		ret







;-----------------------------------------------------------
; Func: 
; Desc: 
;		
;-----------------------------------------------------------
Input_7:

		cpi		ready_flag, 0			; Check if READY_FLAG is 0
		brne	PD7_ALREADY_PRESSED	; Skip if already pressed

		cpi		gesture_receive, SendReady
		breq	NEXT

		rcall	LCDClr
		ldi		ZL, LOW(STRING_START4 << 1)
		ldi		ZH, HIGH(STRING_START4 << 1)

		ldi		YL, LOW(0x0100)			; SRAM address for line 1

		ldi		YH, HIGH(0x0100)
		rcall	CopyToSRAM
		rcall	LCDWrite
		rjmp	NEXT2

NEXT:
		rcall	LCDClr
		ldi		ZL, LOW(STRING_START3 << 1)
		ldi		ZH, HIGH(STRING_START3 << 1)
		ldi		YL, LOW(0x0100)				; Line 1 SRAM address
		ldi		YH, HIGH(0x0100)
		rcall	CopyToSRAM

		rcall	LCDWrite 
		rcall	Count_Down
NEXT2:

		ldi		gesture_send, SendReady
		rcall	USART_Transmit
		ldi		Counter2, 2


PD7_ALREADY_PRESSED:

		ret






;-----------------------------------------------------------
; Func: 
; Desc: 
;		
;-----------------------------------------------------------
USART_Transmit:
		push	mpr
		push	temp

		lds		mpr, UCSR1A
		sbrs	mpr, UDRE1
		rjmp	USART_Transmit

		sts		UDR1, gesture_send

		cp		gesture_receive, gesture_send
		brne	IS_DISABLED1

		ldi		ready_flag, 1
		cpi		READY_FLAG, 1		; Check if READY_FLAG is set
		brne	IS_DISABLED1		; Exit if PD7 has not been pressed



IS_DISABLED1:
		pop		temp
		pop		mpr
		ret


;-----------------------------------------------------------
; Func: 
; Desc: 
;		
;-----------------------------------------------------------
USART_Receive:

		push	mpr
		push	temp
		
		lds		temp, UDR1

		mov		gesture_receive, temp

		cp		gesture_receive, gesture_send
		brne	IS_DISABLED

		ldi		ready_flag, 1
		cpi		READY_FLAG, 1		; Check if READY_FLAG is set
		brne	IS_DISABLED			; Exit if PD7 has not been pressed



		; Code for what to do with the received data
		; Test to turn off LCD back light on the other board with delay
		rcall	Game_Start

		cpi		gesture_send, SendReady
		breq	NOT_READY
		cpi		gesture_receive, SendReady
		breq	NOT_READY
		;rcall	COMPARE_RPS

	
NOT_READY:
IS_DISABLED:
		pop		temp
		pop		mpr

		ret





;-----------------------------------------------------------
; Func: 
; Desc: 
;		
;-----------------------------------------------------------
Display_Top_Choices:
		push	mpr
		push	temp

		rcall	LCDClr
		cpi		gesture_send, ROCK_CODE
		breq	PRINT_ROCK

		cpi		gesture_send, PAPER_CODE
		breq	PRINT_PAPER

		cpi		gesture_send, SCISSORS_CODE
		breq	PRINT_SCISSORS

PRINT_ROCK:
		ldi		ZL, LOW(STRING_ROCK_0 << 1)
		ldi		ZH, HIGH(STRING_ROCK_0 << 1)
		ldi		YL, LOW(0x0100)					; Line 1 SRAM address
		ldi		YH, HIGH(0x0100)
		rcall	CopyToSRAM
		rcall	LCDWrite
		RJMP	END_CHOICE1

PRINT_PAPER:
		ldi		ZL, LOW(STRING_PAPER_1 << 1)
		ldi		ZH, HIGH(STRING_PAPER_1 << 1)
		ldi		YL, LOW(0x0100)					; Line 1 SRAM address
		ldi		YH, HIGH(0x0100)
		rcall	CopyToSRAM
		rcall	LCDWrite
		RJMP	END_CHOICE1

PRINT_SCISSORS:
		ldi		ZL, LOW(STRING_SCISSORS_2 << 1)
		ldi		ZH, HIGH(STRING_SCISSORS_2 << 1)
		ldi		YL, LOW(0x0100)					; Line 1 SRAM address
		ldi		YH, HIGH(0x0100)
		rcall	CopyToSRAM
		rcall	LCDWrite

END_CHOICE1:
		pop		temp
		pop		mpr

		ret




;-----------------------------------------------------------
; Func: 
; Desc: 
;		
;-----------------------------------------------------------
Display_Bottom_Choices:
		push	mpr
		push	temp
		; Print other choice
		cpi		gesture_receive, ROCK_CODE
		breq	PRINT_ROCK1

		cpi		gesture_receive, PAPER_CODE
		breq	PRINT_PAPER1

		cpi		gesture_receive, SCISSORS_CODE
		breq	PRINT_SCISSORS1

PRINT_ROCK1:
		ldi		ZL, LOW(STRING_ROCK_0 << 1)
		ldi		ZH, HIGH(STRING_ROCK_0 << 1)
		ldi		YL, LOW(0x0110)					; Line 1 SRAM address
		ldi		YH, HIGH(0x0110)
		rcall	CopyToSRAM
		rcall	LCDWrite
		RJMP	END_CHOICE2


PRINT_PAPER1:
		ldi		ZL, LOW(STRING_PAPER_1 << 1)
		ldi		ZH, HIGH(STRING_PAPER_1 << 1)
		ldi		YL, LOW(0x0110)					; Line 1 SRAM address
		ldi		YH, HIGH(0x0110)
		rcall	CopyToSRAM
		rcall	LCDWrite
		RJMP	END_CHOICE2

PRINT_SCISSORS1:
		ldi		ZL, LOW(STRING_SCISSORS_2 << 1)
		ldi		ZH, HIGH(STRING_SCISSORS_2 << 1)
		ldi		YL, LOW(0x0110)					; Line 1 SRAM address
		ldi		YH, HIGH(0x0110)
		rcall	CopyToSRAM
		rcall	LCDWrite

END_CHOICE2:
		cpi		Counter2, 0
		breq	Continue1

		ldi		mpr, 4
		rcall	Count_Down

		cpi		Counter2, 1
		brne	Continue1
		rcall	COMPARE_RPS
Continue1:
		cpi		Counter2, 0
		brne	Continue2
		clr		ready_flag;, 0x00
		clr		gesture_send;, 0x00
		clr		gesture_receive;, 0x00



		rjmp	INIT


Continue2:
		dec		Counter2
		pop		temp
		pop		mpr

		ret



;-----------------------------------------------------------
; Func: 
; Desc: 
;		
;-----------------------------------------------------------
COMPARE_RPS:
		rcall	LCDClr
		cp		gesture_receive, gesture_send		; Compare player's gesture with opponent's
		breq	DISPLAY_DRAW						; If equal, it's a draw

    ; Check player's win conditions
		cpi		gesture_send, ROCK_CODE
		breq	CHECK_ROCK

		cpi		gesture_send, PAPER_CODE
		breq	CHECK_PAPER

		cpi		gesture_send, SCISSORS_CODE
		breq	CHECK_SCISSORS

CHECK_ROCK:
		cpi		gesture_receive, SCISSORS_CODE		; Rock beats Scissors
		breq	DISPLAY_WIN
		rjmp	DISPLAY_LOSE						; Otherwise, player loses

CHECK_PAPER:
		cpi		gesture_receive, ROCK_CODE      ; Paper beats Rock
		breq	DISPLAY_WIN
		rjmp	DISPLAY_LOSE					; Otherwise, player loses

CHECK_SCISSORS:
		cpi		gesture_receive, PAPER_CODE		; Scissors beat Paper
		breq	DISPLAY_WIN
		rjmp	DISPLAY_LOSE					; Otherwise, player loses

DISPLAY_WIN:
		; Load "You Win" message and display it
		ldi		ZL, LOW(STRING_WIN << 1)
		ldi		ZH, HIGH(STRING_WIN << 1)
		ldi		YL, LOW(0x0100)					; Line 1 SRAM address
		ldi		YH, HIGH(0x0100)
		rcall	CopyToSRAM
		rcall	LCDWrite
		rjmp	END_COMPARE

DISPLAY_LOSE:
		; Load "You Lose" message and display it
		ldi		ZL, LOW(STRING_LOSE << 1)
		ldi		ZH, HIGH(STRING_LOSE << 1)
		ldi		YL, LOW(0x0100)					; Line 1 SRAM address
		ldi		YH, HIGH(0x0100)
		rcall	CopyToSRAM
		rcall	LCDWrite
		rjmp	END_COMPARE

DISPLAY_DRAW:
		; Load "Draw" message and display it
		ldi		ZL, LOW(STRING_DRAW << 1)
		ldi		ZH, HIGH(STRING_DRAW << 1)
		ldi		YL, LOW(0x0100)					; Line 1 SRAM address
		ldi		YH, HIGH(0x0100)
		rcall	CopyToSRAM
		rcall	LCDWrite

END_COMPARE:

		ret





;-----------------------------------------------------------
; Func: Display Bits
; Desc: 
;		
;-----------------------------------------------------------
Display_Bits:
		andi	mpr, 0xF0		; Mask lower 4 bits as LCD use PB3:0

		in		temp, PORTB		; Load current PortB value to temp
		andi	temp, 0x0F		; Mask higher 4 bits

		or		mpr, temp		;  Combine those remaining bits
		out		PORTB, mpr		; Print the values

		ret


;-----------------------------------------------------------
; Func: 
; Desc: 
;		
;-----------------------------------------------------------
Count_Down:
    
		ldi		counter, 4				; Set countdown value (4 steps for LEDs)
		ldi		mpr, 0b11110000			; Initial LED pattern (PB7-PB4)
		out		PORTB, mpr				; Display initial LEDs

		; Enable Timer/Counter1 Overflow Interrupt
		ldi		mpr, (1 << TOIE1)		; Set Timer/Counter1 overflow interrupt enable
		sts		TIMSK1, mpr

		; Load preload value for 1.5 seconds
		ldi		mpr, PRELOAD_HIGH
		sts		TCNT1H, mpr
		ldi		mpr, PRELOAD_LOW
		sts		TCNT1L, mpr
	
		ret



;-----------------------------------------------------------
; Func: 
; Desc: 
;		
;-----------------------------------------------------------
WAIT_1_Half:
		push	mpr
		push	temp

		; Shift LEDs
		in		mpr, PORTB				; Load current LED state
		lsr		mpr						; Shift LEDs to the right
		out		PORTB, mpr				; Update LEDs

		; Decrement counter
		dec		counter
		tst		counter				; Test if counter == 0
		brne	TIMER_CONTINUE		; If not zero, continue countdown

		; Countdown finished
		clr		mpr					; Clear LEDs
		out		PORTB, mpr

		; Disable Timer/Counter1 Overflow Interrupt
		ldi		mpr, 0x00
		sts		TIMSK1, mpr


		; Transmit gesture to the other board
		;rcall	USART_Transmit      ; Send gesture_send to other board


		rcall	Display_Top_Choices
		rcall	Display_Bottom_Choices

		; Set flag indicating transmission complete
		ldi		ready_flag, 1

		rjmp	DONE2




TIMER_CONTINUE:
		; Reload timer preload value for 1.5-second delay
		ldi		mpr, PRELOAD_HIGH
		sts		TCNT1H, mpr
		ldi		mpr, PRELOAD_LOW
		sts		TCNT1L, mpr


DONE2:
		pop		temp
		pop		mpr

		ret
;-----------------------------------------------------------
; Func: CopyToSRAM
; Desc: Copies a string from Program Memory to Data Memory
;-----------------------------------------------------------
CopyToSRAM:

		lpm		mpr, Z+				; Load a byte from program memory
									; Pointer register r30 increment
		st		Y+, mpr				; Store the byte into SRAM
		tst		mpr					; Check if end of string (null terminator)
		brne	CopyToSRAM			; If not end, continue copying

		ret							; Return when done

;***********************************************************
;*	Stored Program Data
;***********************************************************




;-----------------------------------------------------------
; An example of storing a string. Note the labels before and
; after the .DB directive; these can help to access the data
;-----------------------------------------------------------
STRING_START1:
.DB		"Welcome! ", 0		; Declaring data in ProgMem
STRING_START2:
.DB		"Please press PD7 ", 0
STRING_START3:
.DB		"Start Game:", 0
STRING_START4:
.DB		"Waiting for Opponent!", 0

STRING_ROCK_0:
.DB		"ROCK ", 0
STRING_PAPER_1:
.DB		"PAPER", 0
STRING_SCISSORS_2:
.DB		"SCISSORS ", 0
STRING_WIN:
.DB		"YOU WIN! ", 0
STRING_LOSE:
.DB		"YOU LOSE ", 0
STRING_DRAW:
.DB		"DRAW ", 0
STRING_END:

;***********************************************************
;*	Additional Program Includes
;***********************************************************
.include "LCDDriver.asm"		; Include the LCD Driver


