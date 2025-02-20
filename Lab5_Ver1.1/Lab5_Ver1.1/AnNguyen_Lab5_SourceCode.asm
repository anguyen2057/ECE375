;
; Lab5_Ver1.1.asm
;
; Created: 11/11/2024 5:54:09 PM
; Author : Anguyen2057
;


;***********************************************************
;*	This is the skeleton file for Lab 5 of ECE 375
;*
;*	 Author: An Nguyen
;*	   Date: 11/11/2024
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
.def	right_counter = r24		; Counter for right whisker hits
.def	left_counter = r25		; Counter for left whisker hits

.equ	WTime = 100				; Time to wait in a wait loop

.equ	WskrR = 0				; Right Whisker Input Bit
.equ	WskrL = 1				; Left Whisker Input Bit

.equ	EngEnR = 5				; Right Engine Enable Bit
.equ	EngEnL = 6				; Left Engine Enable Bit
.equ	EngDirR = 4				; Right Engine Direction Bit
.equ	EngDirL = 7				; Left Engine Direction Bit


;/////////////////////////////////////////////////////////////
;These macros are the values to make the TekBot Move.
;/////////////////////////////////////////////////////////////

.equ	MovFwd = (1<<EngDirR|1<<EngDirL)	; Move Forward Command
.equ	MovBck = $00						; Move Backward Command
.equ	TurnR = (1<<EngDirL)				; Turn Right Command
.equ	TurnL = (1<<EngDirR)				; Turn Left Command
.equ	Halt = (1<<EngEnR|1<<EngEnL)		; Halt Command


;***********************************************************
;*	Start of Code Segment
;***********************************************************
.cseg							; Beginning of code segment

;***********************************************************
;*	Interrupt Vectors
;***********************************************************
.org	$0000					; Beginning of IVs
		rjmp 	INIT			; Reset interrupt

		; Set up interrupt vectors for any interrupts being used
.org	$0002
		rcall	HitRight		; Call HitRight function
		reti

.org	$0004
		rcall	HitLeft			; Call HitLeft function
		reti

.org	$0008
		rcall	Clear_Counter	; Test Call LCDClr function
		reti

		; This is just an example:
;.org	$002E					; Analog Comparator IV
;		rcall	HandleAC		; Call function to handle interrupt
;		reti					; Return from interrupt

.org	$0056					; End of Interrupt Vectors

;***********************************************************
;*	Program Initialization
;***********************************************************
INIT:							; The initialization routine
		; Initialize Stack Pointer
		ldi mpr, high(RAMEND)	; Load high byte of RAMEND
		out SPH, mpr			; Set high byte of stack pointer
		ldi mpr, low(RAMEND)	; Load low byte of RAMEND
		out SPL, mpr			; Set low byte of stack pointer

		; Initialize Port B for output
		ldi		mpr, (1<<EngEnL) | (1<<EngEnR) | (1<<EngDirL) | (1<<EngDirR)
		out		DDRB, mpr		; Set DDR register for Port B
		ldi		mpr, 0x00
		out		PORTB, mpr		; Set the default output for Port B

		; Initialize Port D for input
		ldi		mpr, 0x00
		out		DDRD, mpr		; Set DDR register for Port D
		ldi		mpr, 0x0F
		out		PORTD, mpr		; Set Port D to Input with Hi

		; Initialize external interrupts
		; Set the Interrupt Sense Control to falling edge
		ldi		mpr, (1<<ISC01) | (0<<ISC00) | (1<<ISC11) | (0<<ISC10) | (1<<ISC31) | (0<<ISC30)
		sts		EICRA, mpr		; Use sts, EICRA in extended I/O space

		; Configure the External Interrupt Mask
		ldi		mpr, (1<<INT0) | (1<<INT1) | (1<<INT3)
		out		EIMSK, mpr

		; Clear queue to EIFR
		ldi		mpr, (1<<INTF0) | (1<<INTF1) | (1<<INTF3)
		out		EIFR, mpr

		; Initialize LCD
		rcall LCDInit			; Initialize LCD
		rcall LCDBacklightOn	; Turn on LCD backlight
		rcall LCDClr			; Clear LCD initially


		; Clear the Hit Counter
		clr right_counter		;
		clr left_counter		;

		; Turn on interrupts
			; NOTE: This must be the last thing to do in the INIT function
		; Enable global interrupts
		sei

;***********************************************************
;*	Main Program
;***********************************************************
MAIN:							; The Main program

		; TODO
		ldi		mpr, MovFwd		; Load FWD command
		out		PORTB, mpr		; Send FWD command to PORTB (motors)


		rjmp	MAIN			; Create an infinite while loop to signify the
								; end of the program.

;***********************************************************
;*	Functions and Subroutines
;***********************************************************

;-----------------------------------------------------------
;	You will probably want several functions, one to handle the
;	left whisker interrupt, one to handle the right whisker
;	interrupt, and maybe a wait function
;------------------------------------------------------------

;-----------------------------------------------------------
; Func: Template function header
; Desc: Cut and paste this and fill in the info at the
;		beginning of your functions
;-----------------------------------------------------------
FUNC:							; Begin a function with a label

		; Save variable by pushing them to the stack

		; Execute the function here

		; Restore variable by popping them from the stack in reverse order

		ret						; End a function with RET


;-----------------------------------------------------------
; Func: Clear
; Desc: Cut and paste this and fill in the info at the
;		beginning of your functions
;-----------------------------------------------------------
Clear_Counter:									; Begin a function with a label
		push	mpr							; Save mpr register
		push	waitcnt						; Save wait register
		in		mpr, SREG					; Save program state to mpr
		push	mpr							; Save program state from mpr to the stack

		clr		right_counter				;
		clr		left_counter				;

		pop		mpr							; Save program state to mpr from the stack
		out		SREG, mpr					; Save program state from mpr
		pop		waitcnt						; Restore wait register
		pop		mpr							; Restore value of mpr 

		rcall	LCDBacklightOff				;
		rcall	LCDClr						;

		ret									; Return from subroutine

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

;-----------------------------------------------------------
; Func: Display
; Desc: Display the strings on to the LCD
;-----------------------------------------------------------
Display:							; Begin a function with a label
    ; Load string 1 into the data memory
		mov		mpr, right_counter
		rcall	Convert

;		ldi		ZL, LOW(STRING1_BEG << 1)		; Load low byte of string 1 address
;		ldi		ZH, HIGH(STRING1_BEG << 1)		; Load high byte of string 1 address

		ldi		YL, LOW(0x0100)
		ldi		YH, HIGH(0x0100)				; Point to start of Line 1 in SRAM

		mov		mpr, olcnt
		st		Y+, mpr				; Store the byte into SRAM
		mov		mpr, ilcnt
		st		Y, mpr				; Store the byte into SRAM

;		rcall	CopyToSRAM						; Copy name to Line 1

	; Load string 2 into the data memory
		mov		mpr, left_counter
		rcall	Convert
		
;		ldi    ZL, LOW(STRING2_BEG << 1)   ; Load low byte of string 2 address
;		ldi    ZH, HIGH(STRING2_BEG << 1)  ; Load high byte of string 2 address

		ldi    YL, LOW(0x0110)
		ldi    YH, HIGH(0x0110)        ; Point to start of Line 2 in SRAM

		mov		mpr, olcnt
		st		Y+, mpr				; Store the byte into SRAM
		mov		mpr, ilcnt
		st		Y, mpr				; Store the byte into SRAM

;		rcall  CopyToSRAM        ; Copy message to Line 2

		rcall  LCDWrite                ; Write both lines to the LCD

		ret                            ; Return from function


;-----------------------------------------------------------
; Func: Convert
; Desc: Convert from Binary to ASCII
;-----------------------------------------------------------
Convert:
		ldi		temp, 10
		clr		olcnt
Div_Loop:
		cp		mpr, temp
		brlo	Div_Done
		sub		mpr, temp
		inc		olcnt
		rjmp	Div_Loop

Div_Done:
		mov		ilcnt, mpr
		; Now olcnt holds Tens
		; Now ilcnt holds Units

		ldi		mpr, 0x30
		add		olcnt, mpr
		ldi		temp, 0x30
		add		ilcnt, temp

		ret

;-----------------------------------------------------------
; Func: HitRight
; Desc: Cut and paste this and fill in the info at the
;		beginning of your functions
;-----------------------------------------------------------
HitRight:									; Begin a function with a label

		rcall LCDBacklightOn				; Turn on LCD backlight

		push	mpr							; Save mpr register
		push	waitcnt						; Save wait register
		in		mpr, SREG					; Save program state to mpr
		push	mpr							; Save program state from mpr to the stack

		; Count right hits and Display on LCD
		inc		right_counter				;


		; Move Backwards for a second
		ldi		mpr, MovBck					; Load Move Backward command
		out		PORTB, mpr					; Send command to port
		ldi		waitcnt, WTime				; Wait for 1 second (Change the time wait?)
		rcall	Wait						; Call wait function

		; Turn left for a second
		ldi		mpr, TurnL					; Load Turn Left Command
		out		PORTB, mpr					; Send command to port
		ldi		waitcnt, WTime				; Wait for 1 second
		rcall	Wait						; Call wait function

		; Move Forward again
		ldi		mpr, MovFwd					; Load Move Forward command
		out		PORTB, mpr					; Send command to port

		

		pop		mpr							; Save program state to mpr from the stack
		out		SREG, mpr					; Save program state from mpr
		pop		waitcnt						; Restore wait register
		pop		mpr							; Restore value of mpr 

		rcall	Display

		ldi		mpr, (1<<INTF0) | (1<<INTF1) | (1<<INTF3)
		out		EIFR, mpr

		ret									; Return from subroutine

;-----------------------------------------------------------
; Func: HitLeft
; Desc: Cut and paste this and fill in the info at the
;		beginning of your functions
;-----------------------------------------------------------
HitLeft:									; Begin a function with a label

		rcall LCDBacklightOn				; Turn on LCD backlight

		push	mpr							; Save mpr register
		push	waitcnt						; Save wait register
		in		mpr, SREG					; Save program state to mpr
		push	mpr							; Save program state from mpr to the stack

		; Count left hits and Display on LCD
		inc		left_counter				;


		; Move Backwards for a second
		ldi		mpr, MovBck					; Load Move Backward command
		out		PORTB, mpr					; Send command to port
		ldi		waitcnt, WTime				; Wait for 1 second 
		rcall	Wait						; Call wait function

		; Turn right for a second
		ldi		mpr, TurnR					; Load Turn Left Command
		out		PORTB, mpr					; Send command to port
		ldi		waitcnt, WTime				; Wait for 1 second
		rcall	Wait						; Call wait function

		; Move Forward again
		ldi		mpr, MovFwd					; Load Move Forward command
		out		PORTB, mpr					; Send command to port


		pop		mpr							; Save program state to mpr from the stack
		out		SREG, mpr					; Save program state from mpr
		pop		waitcnt						; Restore wait register
		pop		mpr							; Restore value of mpr 

		rcall	Display

		ldi		mpr, (1<<INTF0) | (1<<INTF1) | (1<<INTF3)
		out		EIFR, mpr

		ret									; Return from subroutine

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

;-----------------------------------------------------------
; An example of storing a string. Note the labels before and
; after the .DB directive; these can help to access the data
;-----------------------------------------------------------
STRING1_BEG:
.DB		"Hit Right :", 0				; Declaring data in ProgMem

STRING2_BEG:
.DB		"Hit Left  :", 0				; Declaring data in ProgMem

STRING_END:

;***********************************************************
;*	Additional Program Includes
;***********************************************************
.include "LCDDriver.asm"		; Include the LCD Driver








