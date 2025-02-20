;
; Lab6_Ver1.asm
;
; Created: 11/17/2024 8:10:24 PM
; Author : Anguyen2057
;


;***********************************************************
;*
;*	This is the skeleton file for Lab 6 of ECE 375
;*
;*	 Author: An Nguyen - Main
;*	   Date: 11/18/2024
;*
;***********************************************************

.include "m32U4def.inc"			; Include definition file

;***********************************************************
;*	Internal Register Definitions and Constants
;***********************************************************
.def	mpr = r16				; Multipurpose register
.def	waitcnt = r17			; Wait Loop Counter
.def	ilcnt = r18				; Inner Loop Counter
.def	olcnt = r19				; Outer Loop Counter
.def	temp = r23				; An - To store things temporarily if needed
.def	speed_level = r24		; Counter for right whisker hits
.def	duty_cycle = r25		; Counter for left whisker hits

.equ	WTime = 10				; Time to wait in a wait loop

.equ	EngEnR = 5				; right Engine Enable Bit
.equ	EngEnL = 6				; left Engine Enable Bit
.equ	EngDirR = 4				; right Engine Direction Bit
.equ	EngDirL = 7				; left Engine Direction Bit
.equ	OCR1A = 0x88
.equ	OCR1B = 0x8A

;***********************************************************
;*	Start of Code Segment
;***********************************************************
.cseg							; beginning of code segment

;***********************************************************
;*	Interrupt Vectors
;***********************************************************
.org	$0000
		rjmp	INIT			; reset interrupt

		; place instructions in interrupt vectors here, if needed
.org	$0002
		rcall	Decrease_Speed			; Call HitRight function
		reti

.org	$0004
		rcall	Increase_Speed			; Call HitLeft function
		reti

.org	$0008
		rcall	Full_Speed			; Test Call LCDClr function
		reti

.org	$0056					; end of interrupt vectors

;***********************************************************
;*	Program Initialization
;***********************************************************
INIT:
		; Initialize the Stack Pointer
		ldi mpr, high(RAMEND)	; Load high byte of RAMEND
		out SPH, mpr			; Set high byte of stack pointer
		ldi mpr, low(RAMEND)	; Load low byte of RAMEND
		out SPL, mpr			; Set low byte of stack pointer

		; Configure I/O ports
		; Initialize Port B for output
		ldi		mpr, 0xFF;(1<<EngEnL) | (1<<EngEnR) | (1<<EngDirL) | (1<<EngDirR)
		out		DDRB, mpr		; Set DDR register for Port B
		ldi		mpr, 0xFF
		out		PORTB, mpr		; Set the default output for Port B

		;  Initialize Port D for input
		ldi		mpr, 0x00
		out		DDRD, mpr		; Set DDR register for Port D
		ldi		mpr, 0x0F
		out		PORTD, mpr		; Set Port D to Input with Hi


		; Configure External Interrupts, if needed
		; Set the Interrupt Sense Control to falling edge
		ldi		mpr, (1<<ISC01) | (0<<ISC00) | (1<<ISC11) | (0<<ISC10) | (1<<ISC31) | (0<<ISC30)
		sts		EICRA, mpr		; Use sts, EICRA in extended I/O space



		; Configure the External Interrupt Mask
		ldi		mpr, (1<<INT0) | (1<<INT1) | (1<<INT3)
		out		EIMSK, mpr


		; Configure 16-bit Timer/Counter 1A and 1B
		; Duty Cycles
		ldi		duty_cycle, 0





		; Fast PWM, 8-bit mode, no prescaling
		ldi		mpr, (1<<WGM10) | (1<<COM1A1) | (1<<COM1B1) ;| (1<<COM1A0) | (1<<COM1B0)
		sts		TCCR1A, mpr

		ldi		mpr, (1<<WGM12) | (1<<CS10)
		sts		TCCR1B, mpr


		sts		OCR1A, duty_cycle
		sts		OCR1B, duty_cycle

		
		

		; Set TekBot to Move Forward (1<<EngDirR|1<<EngDirL) on Port B
		ldi		mpr, (1<<EngDirR) | (1<<EngDirL)
		

		; Set initial speed, display on Port B pins 3:0
		clr		speed_level
		ldi		speed_level, 0x0F
		or		mpr, speed_level
		out		PORTB, mpr

		; Enable global interrupts (if any are used)
		sei

;***********************************************************
;*	Main Program
;***********************************************************
MAIN:
		; poll Port D pushbuttons (if needed)


								; if pressed, adjust speed
								; also, adjust speed indication

		rjmp	MAIN			; return to top of MAIN

;***********************************************************
;*	Functions and Subroutines
;***********************************************************

;-----------------------------------------------------------
; Func:	Template function header
; Desc:	Cut and paste this and fill in the info at the
;		beginning of your functions
;-----------------------------------------------------------
FUNC:	; Begin a function with a label

		; If needed, save variables by pushing to the stack

		; Execute the function here

		; Restore any saved variables by popping from stack

		ret						; End a function with RET



;-----------------------------------------------------------
; Func: Display Bits
; Desc: 
;		
;-----------------------------------------------------------
Display_Bits:

		sts		OCR1A, duty_cycle
		sts		OCR1B, duty_cycle

		mov		temp, speed_level			; Copy value in speed level to temp
		andi	temp, 0x0F					; Mask upper 4 bits
		
		in		ilcnt, PORTB				; Load current PortB value to ilcnt
		andi	ilcnt, 0xF0					; Mask lower 4 bits

		or		ilcnt, temp					; Combine those remaining bits
		out		PORTB, ilcnt				; Print the values


		ret


;-----------------------------------------------------------
; Func: Full Speed
; Desc: 
;		
;-----------------------------------------------------------
Full_Speed:
		push	mpr							; Save mpr register
		push	waitcnt						; Save wait register
		in		mpr, SREG					; Save program state to mpr
		push	mpr							; Save program state from mpr to the stack

		ldi		speed_level, 0x0F
		ldi		duty_cycle, 0

		pop		mpr							; Save program state to mpr from the stack
		out		SREG, mpr					; Save program state from mpr
		pop		waitcnt						; Restore wait register
		pop		mpr							; Restore value of mpr 


		rcall	Display_Bits

		ldi		mpr, (1<<INTF0) | (1<<INTF1) | (1<<INTF3)
		out		EIFR, mpr

		ret

;-----------------------------------------------------------
; Func: Decrease Speed
; Desc: 
;		
;-----------------------------------------------------------
Decrease_Speed:
		push	mpr							; Save mpr register
		push	waitcnt						; Save wait register
		in		mpr, SREG					; Save program state to mpr
		push	mpr							; Save program state from mpr to the stack
		
		ldi		mpr, 17
		add		duty_cycle, mpr
		brcc	Done_Inc_Duty
		ldi		duty_cycle, 255

Done_Inc_Duty:
		ldi		mpr, 0x01					; Clear ZERO flag just in case

		ldi		mpr, 1
		sub		speed_level, mpr
		brpl	Done_Dec_Speed
		clr		speed_level

Done_Dec_Speed:




		ldi		waitcnt, WTime				; Wait for 1 second 
		rcall	Wait						; Call wait function

		pop		mpr							; Save program state to mpr from the stack
		out		SREG, mpr					; Save program state from mpr
		pop		waitcnt						; Restore wait register
		pop		mpr							; Restore value of mpr 

		rcall	Display_Bits

		ldi		mpr, (1<<INTF0) | (1<<INTF1) | (1<<INTF3)
		out		EIFR, mpr

		ret


;-----------------------------------------------------------
; Func: Increase Speed
; Desc: 
;		
;-----------------------------------------------------------
Increase_Speed:
		push	mpr							; Save mpr register
		push	waitcnt						; Save wait register
		in		mpr, SREG					; Save program state to mpr
		push	mpr							; Save program state from mpr to the stack
		
		
		ldi		mpr, 17
		sub		duty_cycle, mpr
		brcc	Done_Dec_Duty
		clr		duty_cycle
Done_Dec_Duty:

		ldi		mpr, 1
		add		speed_level, mpr
		cpi		speed_level, 15
		brsh	Set_Max_Speed
		rjmp	Done_Inc_Speed

Set_Max_Speed:
		ldi		speed_level, 15

Done_Inc_Speed:
	
		ldi		mpr, 0x01					; Clear Zero flag created from cpi speed_level, 15


		ldi		waitcnt, WTime				; Wait for 1 second 
		rcall	Wait						; Call wait function

		pop		mpr							; Save program state to mpr from the stack
		out		SREG, mpr					; Save program state from mpr
		pop		waitcnt						; Restore wait register
		pop		mpr							; Restore value of mpr 

		rcall	Display_Bits

		ldi		mpr, (1<<INTF0) | (1<<INTF1) | (1<<INTF3)
		out		EIFR, mpr

		ret


;-----------------------------------------------------------
; Func: Wait
; Desc: Cut and paste this and fill in the info at the
;		beginning of your functions
;-----------------------------------------------------------
Wait:									; Begin a function with a label
		push	waitcnt					; Save wait register
		push	ilcnt					; Save ilcnt register
		push	olcnt					; Save olcnt register

Loop:	ldi		olcnt, 224				; load olcnt register
OLoop:	ldi		ilcnt, 237				; load ilcnt register
ILoop:	dec		ilcnt					; decrement ilcnt
		brne	ILoop					; Continue Inner Loop
		dec		olcnt					; decrement olcnt
		brne	OLoop					; Continue Outer Loop
		dec		waitcnt					; Decrement wait
		brne	Loop					; Continue Wait loop

		pop		olcnt					; Restore olcnt register
		pop		ilcnt					; Restore ilcnt register
		pop		waitcnt					; Restore wait register

		ret		


;***********************************************************
;*	Stored Program Data
;***********************************************************
		; Enter any stored data you might need here

;***********************************************************
;*	Additional Program Includes
;***********************************************************
;.include "LCDDriver.asm"		; Include the LCD Driver

