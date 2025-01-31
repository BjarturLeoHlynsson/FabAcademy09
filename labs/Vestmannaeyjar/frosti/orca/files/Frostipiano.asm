;
; hello5.wave.asm
; Neil Gershenfeld MIT CBA 7/31/05
; PWM wavetable program
; 
; Modified by Ed Baafi and Carl Scheffler to play
; a tune (Mary Had a Little Lamb).
;
; Remodified by Halldor and Frosti in Fab Lab ; Vestmannaeyjar, Iceland
; to play different music tones depending on variable voltage 
;from distance meter

; Last modified: 31st of  May 2010
;
; Register definitions
;
.include "tn45def.inc"
.def temp = R16	; temporary storage
.def temp1 = R17 ; temporary storage
.def sample_count = R18 ; sample counter
.def sample_delay = R19 ; delay between samples
.def delay_count = R20 ; delay loop counter
.def cycle_count = R21 ; cycle counter
.def min_cycle = R22 ; cycle_count => cycle_count + min_cycle
.def note_count = R23 ; note counter
.def note_lo = R24 ; note low byte
;.def note_hi = R25 ; note high byte

.def sensor_value_high = R25	; temporary storage for sensor value
.def sensor_value_low = R26	; temporary storage for sensor value
	.DEF rd1l = R1 ; LSB 16-bit-number to be divided
	.DEF rd1h = R2 ; MSB 16-bit-number to be divided
	.DEF rd1u = R3 ; interim register
	.DEF rd2 = R4 ; 8-bit-number to divide with
	.DEF rel = R5 ; LSB result
	.DEF reh = R6 ; MSB result
	.DEF rmp = R27; multipurpose register for loading

;
; interrupt vectors
;
.cseg
.org 0
rjmp reset
;
; waveform
; first byte = number of samples
;
wave:
   .db 99,191,195,199,203,207,211,215,218,222
   .db 225,229,232,235,238,240,243,245,247,249
   .db 250,252,253,254,254,254,254,254,254,253
   .db 252,251,250,248,246,244,242,239,236,233
   .db 230,227,224,220,216,213,209,205,201,197
   .db 193,189,185,181,177,173,169,166,162,158
   .db 155,152,149,146,143,140,138,136,134,132
   .db 131,130,129,128,128,128,128,128,128,129
   .db 130,132,133,135,137,139,142,144,147,150
   .db 153,157,160,164,167,171,175,179,183,187
;
; notes
; first byte  = minimum number of cycles
; second byte = number of notes
; following notes are specified by the delay between samples
;   and then the number of cycles
;
notes:

;; Let me call you sweetheart
;.db 48,52
;.db 95,33,79,0,59,80,52,24,46,33,79,48,84,43,79,0,70,114,70,114
;.db 70,114,70,114,62,73,66,9,62,73,59,16,52,24,62,73,70,60,62,13

;.db 79,96,79,96,79,96,79,96,95,33,79,0,59,80,52,24,46,33,79,48

;.db 84,43,79,0,70,114,70,114,52,168,52,168,52,96,59,16,62,73,59,16
;.db 46,33,79,48,43,123,46,33,70,114,62,134,59,144,59,144

; Mary had a little lamb
.db 10,1
.db 60,250,110,10,90,80,70,18,62,25,62,25,62,85,70,18,70,18,70,72
.db 62,25,52,36,52,108,62,25,70,18,79,12,70,18,62,25,62,25,62,25
.db 62,25,70,18,70,18,62,25,70,18,79,156,62,25,70,18,79,12,70,18
.db 62,25,62,25,62,85,70,18,70,18,70,72,62,25,52,36,52,108,62,25
.db 70,18,79,12,70,18,62,25,62,25,62,25,62,25,70,18,70,18,62,25
.db 70,18,79,108,107,0,62,25,70,18,79,12,70,18,62,25,62,25,62,85
.db 70,18,70,18,70,126,62,25,52,36,52,36,52,36

;
; main program
;
reset:	   
   ;
   ; initialization
   ;
   ldi temp, low(RAMEND)
   out SPL, temp 	; set stack pointer to top of RAM
   ldi temp, (1<<CLKPCE)
   ldi temp1, ((0 << CLKPS3) | (0 << CLKPS2) | (0 << CLKPS1) | (0 << CLKPS0))
   out CLKPR, temp 	; write CLKPCE to change clock prescaler
   out CLKPR, temp1 ; set clock to 9.6MHz/1
   ldi temp, ((1 << COM0B0) | (1 << COM0B1) | (1 << WGM01) | (1 << WGM00))
   out TCCR0A, temp ; set OC0B on compare match and set fast PWM mode, 0xFF TOP
   ldi temp, (1 << CS00)
   out TCCR0B, temp ; set timer 0 prescalar to 1
   sbi DDRB, PB1 	; enable OC0B output pin
   ldi sample_delay, 10
   ldi cycle_count, 50
   ;
   ; main loop
   ;

;setup AD mælingu

   ; init A/D
  ;
   cbi ADMUX, REFS2 ; use Vcc as reference
   cbi ADMUX, REFS1 ; "
   cbi ADMUX, REFS0 ; "
   cbi ADMUX, ADLAR ; right-adjust result
   cbi ADMUX, MUX3 ; set MUX to ADC2 (PB4) here we decide what pin we use for measurement
   cbi ADMUX, MUX2 ; "
   sbi ADMUX, MUX1 ; "
   cbi ADMUX, MUX0 ; "
   sbi ADCSRA, ADEN ; enable A/D
   cbi ADCSRA, ADPS2 ; set prescaler to /2 (here we define at what speed we measure)
   cbi ADCSRA, ADPS1 ; "
   cbi ADCSRA, ADPS0 ; "



   main_loop:
      ;
         ;
	  
	 
 
 ; read number of notes and set note pointer
 
      ldi zl, low(notes*2)
      ldi zh, high(notes*2)
      lpm
      mov min_cycle, R0   ; Lesun fyrsta byte, sveiflufjöldi
      adiw zl, 1
      lpm
      mov note_count, R0  ; þetta er fjöldi nótna
      adiw zl, 1
      movw note_lo, zl
      ;
      ; loop over notes  löbbun eftir nótunum
      ;
      inc note_count
      note_loop:
	 ;
	 ; delay for silence between notes
	 ;
         ldi delay_count, 255
         inter_note_delay1:
	    ldi sample_delay, 255
	    inter_note_delay2:
	       dec sample_delay
	       brne inter_note_delay2
	    dec delay_count
	    brne inter_note_delay1
	    
         dec note_count
	     breq main_loop ; eru allar nótur komnar

         movw zl, note_lo
	 lpm				; hér er umrædd nóta lesin
	 mov sample_delay, R0

 ; read response
	         ;
	         sbi ADCSRA, ADSC ; start conversion
	         adloopup:
	            sbic ADCSRA, ADSC ; loop until complete
	            rjmp adloopup
	         ;
	         ; save conversion
	       
	         
	         ;
	         in sensor_value_low, ADCL ; get low byte from sensor
	         in sensor_value_high, ADCH ; get high byte from sensor
 	 

       ;Here we divide the results from the sensor Devision starts
	        ; Load the test numbers to the appropriate registers
	        ;
	           
	            mov rd1h,sensor_value_high ; use the high sensor value
	            mov rd1l,sensor_value_low ; use the low sensor value
	            ldi rmp,0x4 ; 0x4 to be divided with
	            mov rd2,rmp
	        ;
	        ; Divide rd1h:rd1l by rd2
	        ;
	        div8:
	            clr rd1u ; clear interim register
	            clr reh ; clear result (the result registers
	            clr rel ; are also used to count to 16 for the
	            inc rel ; division steps, is set to 1 at start)
	        ;
	        ; Here the division loop starts
	        ;
	        div8a:
	            clc ; clear carry-bit
	            rol rd1l ; rotate the next-upper bit of the number
	            rol rd1h ; to the interim register (multiply by 2)
	            rol rd1u
	            brcs div8b ; a one has rolled left, so subtract
	            cp rd1u,rd2 ; Division result 1 or 0?
	            brcs div8c ; jump over subtraction, if smaller
	        div8b:
	            sub rd1u,rd2; subtract number to divide with
	            sec ; set carry-bit, result is a 1
	            rjmp div8d ; jump to shift of the result bit
	        div8c:
	            clc ; clear carry-bit, resulting bit is a 0
	        div8d:
	            rol rel ; rotate carry-bit into result registers
	            rol reh
	            brcc div8a ; as long as zero rotate out of the result
	             ; registers: go on with the division loop
	        ; End of the division reached






	 mov sample_delay, rel
	 adiw note_lo, 1
         movw zl, note_lo
	 lpm
	 mov cycle_count, R0
	 adiw note_lo, 1
	 inc cycle_count
	 ldi temp, 2
	 ; 
	 ; loop over cycles
	 ;
	 cycle_loop:
	    dec cycle_count
	    brne continue_cycle

	       dec temp
	       breq note_loop
	       mov cycle_count, min_cycle
	       inc cycle_count
	
            continue_cycle:	
            ;
            ; read number of samples
            ;
            ldi zl, low(wave*2)
            ldi zh, high(wave*2)
            lpm
            mov sample_count, R0
	    ;
	    ; loop over samples
	    ;
            sample_loop:


	 

               adiw zl, 1 ; move to next sample
               lpm ; read sample
	
	
               out OCR0B, R0 ; update PWM
          
		       mov delay_count, sample_delay
               sample_delay_loop:
                  dec delay_count
                  brne sample_delay_loop
               dec sample_count ; decrease sample count
               brne sample_loop ; get next sample, ...
                  rjmp cycle_loop ; ... or repeat cycle if done
