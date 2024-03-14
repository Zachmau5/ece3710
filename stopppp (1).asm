; Project: Lab 5, Stop Watch w/Serial Interface (stopwatch.asm)
; Description: The student should be able to write, debug and test a program that
; uses timer and the serial port interrupts without busy/wait loops.

; Authors: 
; Andrew Coffel: andrewchoffel@mail.weber.edu
; Zachary Hallett: zacharyhallett@mail.weber.edu

; Course: ECE 3710 Section #2
; VER       Date        Description
; 0.1       2/28/2024   Created Project

$include (c8051f020.inc)  ; Include the microcontroller-specific definitions

DSEG at 30h
old_button:     	DS 1
count:          	DS 1
running:        	DS 1    ; Use running.0 to determine the running state
prescaler_count: 	DS 1  ; Add this line to define the prescaler counter

CSEG
org 0h
	mov			wdtcn,#0DEh 	; disable watchdog
	mov			wdtcn,#0ADh
	mov			xbr2,#40h		; enable port output
	mov			xbr0,#04h		; enable uart 0
	mov			oscxcn,#67H		; turn on external crystal
	mov			tmod,#20H		; wait 1ms using T1 mode 2
	mov			th1,#256-167	; 2MHz clock, 167 counts = 1ms
	setb		tr1
	SETB    P2.7            		; Set P2.7 as input (reset button)
  SETB    P2.6            		; Set P2.6 as input (start/stop button)
	MOV			prescaler_count, #10


wait1:
	jnb		tf1,wait1
	clr		tr1				; 1ms has elapsed, stop timer
	clr		tf1

wait2:
	mov			a,oscxcn		; now wait for crystal to stabilize
	jnb			acc.7,wait2
	mov			oscicn,#8		; engage! Now using 22.1184MHz
	mov			scon0,#50H		; 8-bit, variable baud, receive enable
	mov			th1,#-6			; 9600 baud
	setb		tr1				; start baud clock
	MOV			T2CON, #00h
	MOV			TH2, #HIGH(-18432)
	MOV			TL2, #LOW(-18432)
	MOV     RCAP2H, #HIGH(-18432) 	; High byte of reload value
  MOV     RCAP2L, #LOW(-18432)  	; Low byte of reload value
	setb    TR2                   	; Start Timer 2	
  MOV     IE, #0C0h         		; Enable Timer 2 and Serial interrupts
  MOV     SCON0, #50H     			; Setup UART for 8-bit data, 1 stop bit
  MOV     TH1, #-6        			; Set baud rate for UART           		; Start timer for UART
  CLR			A
	jmp 		loopy
	

org 0023h
; Serial Interface Interrupt
ser_int:
    JBC     RI, RX_INT
    JBC     TI, TX_INT
    RETI

org 002Bh
; Timer 2 Interrupt for Stopwatch Functionality
Timer2_int:
    CLR     TF2    ; Clear Timer 2 Overflow Flag
    LJMP    T2_INT

	; Main Loop
main:   
    JMP    main

org 100h

; RX Interrupt Service Routine
RX_INT: 
    CLR     RI                    	; Clear Receive Interrupt flag
    MOV     A, SBUF0               	; Move received byte into accumulator
    CJNE    A, #'R', NOT_R        	; Check if 'R' was received
    MOV     A, #01h     			; Load 1 into A
	MOV     running, A  			; Set 'running' to 1
	SJMP    RX_END

NOT_R:
    CJNE    A, #'S', NOT_S        	; Check if 'S' was received
    MOV     A, #00h     			; Load 0 into A
	MOV     running, A  			; Set 'running' to 0
    SJMP    RX_END

NOT_S:
    CJNE    A, #'C', RX_END       	; Check if 'C' was received
	MOV     A, #00h     			; Load 0 into A
	MOV     running, A  			; Set 'running' to 0
    MOV     count, #0x00          	; Reset the stopwatch count
    CALL    DISP_LED              	; Update the display immediately
RX_END:
    RETI

; TX Interrupt Service Routine
TX_INT:
    CLR     TI                    	; Clear Transmit Interrupt flag
    RETI

; Timer 2 Interrupt Service Routine for Stopwatch
T2_INT:
    CLR		TI
	CALL    Check_buttons      		; Check the state of the buttons
    MOV     A, running         		; Load 'running' into A
    JZ      NOT_RUNNING        		; If Z flag is set (A was 0), jump to NOT_RUNNING
    MOV     A, count
	  DJNZ	prescaler_count, NOT_RUNNING;  where do I jump
	  MOV		prescaler_count, #10
    ADD     A, #1              		; Add 1 to the BCD count for tenths of seconds
    DA      A               		; Adjust for BCD
    MOV     count, A

DISPLAY_UPDATE:
    CALL    DISP_LED

NOT_RUNNING:
    RETI

; Button Check Routine
Check_buttons:
    MOV     A, P2                  ; Load the current state of the buttons
    CPL     A                      ; Invert since buttons are active-low
    MOV     B, A                   ; Copy current state to B
    XRL     A, old_button          ; Find changed buttons
    ANL     A, B                   ; Find buttons that are pressed
    MOV     old_button, B          ; Update old_button state
    JNB     B.6, NOT_START_STOP    ; Check if start/stop button is pressed
    MOV     A, running             ; Load 'running' into A
    CPL     A                      ; Complement A (toggle the running state)
    MOV     running, A             ; Store back to 'running'

NOT_START_STOP:
    JNB     B.7, NO_RESET          ; Check if reset button is pressed
    MOV     A, #01h                ; Load 0 into A, preparing to stop the stopwatch and reset count. when =1, just starts. KEEP FOR TROUBLESHOOTING
    MOV     running, A             ; Stop the stopwatch by setting 'running' to 0
    CALL    DISP_LED               ; Update LED display immediately

NO_RESET:
    RET


;------DISPLAY LED SUBROUTINE--------
DISP_LED:
    MOV     A, count 			   	; Load the count into A
	SWAP 		A
	CPL 		A
    MOV     P3, A         			; Display tenths on P3.0 to P3.3 (assuming lower nibble controls these LEDs)
    RET
END