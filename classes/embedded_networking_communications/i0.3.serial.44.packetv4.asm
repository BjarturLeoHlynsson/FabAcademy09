;
; i0.3.serial.44.packetv4.asm
; i0 three-wire half-duplex packet bridge demonstration code
; IPv4 version
; 2-16-2 encoding
;
; Neil Gershenfeld
; CBA MIT 11/22/09
;
; (c) Massachusetts Institute of Technology 2009
; Permission granted for experimental and personal use;
; license for commercial sale available from MIT.
;
.include "tn44def.inc"
;
; definitions
;
.equ click_pin = PA0 ; i0 click pin
.equ led_pin = PA1 ; LED pin
.equ tx_pin = PA6; transmit pin
.equ rx_pin = PA7; receive pin
.equ click_count = 10 ; loop count to wait during click
.equ settle_count = 20 ; loop count to wait for click to settle
.equ delay_count = 30 ; loop count to wait between clicks
.equ char_delay_count = 15 ; loop count for character delay
.equ csma_count = 20 ; loop count for CSMA check
.equ ramstart = 0x60 ; beginning of SRAM
.equ END = 192 ; SLIP definitions
.equ ESC = 219 ; "
.equ ESC_END = 220 ; "
.equ ESC_ESC = 221 ; "
;
; registers
;
.def zero = R1 ; 0
.def one = R2 ; 1
.def double_count = R3 ; double loop count
.def triple_space = R4 ; triple click spacing
.def count_lo = R5 ; click low count
.def count_hi = R6 ; click high count
.def bit_count = R16; bit counter
.def temp = R17; temporary storage
.def temp1 = R18; temporary storage
.def txbyte = R19; transmit byte
.def rxbyte = R20; receive byte
.def click_space = R21 ; click spacing
.def loop_count = R22 ; loop counter
.def byte_count = R23 ; packet byte count
; R30, 31 used for Z pointer
;
; macros
;
.macro point_to
   ;
   ; point_to memory_location
   ;
   ldi zh, high(@0)
   ldi zl, low(@0)
   .endmacro
;
; code segment
;
.cseg
.org 0
rjmp reset
;
; click_duration
;
click_duration:
   ldi temp, click_count
   click_duration_loop:
      dec temp
      brne click_duration_loop
   ret
;
; click_delay
;
click_delay:
   ldi temp, delay_count
   click_delay_loop:
      dec temp
      brne click_delay_loop
   ret
;
; bitdelay
; serial bit delay
;
.equ b = 25 ; 115200 baud (20 MHz clock /1)
;.equ b = 170 ; 19200 baud (20 MHz clock /1)
bitdelay:
   ldi temp, b
   bitloop:
      dec temp
      brne bitloop
   ret
;
; char_delay
; delay between characters
;
char_delay:
   ldi temp, char_delay_count
   char_delay_loop:
      dec temp
      brne char_delay_loop
   ret   
;
; getclick
; input an I0 byte following first click
;
getclick:
   ;
   ; delay for first click to settle
   ;
   ldi loop_count, settle_count
   getclick_settle_start:
      dec loop_count
      nop ; to even out timing for breq
      brne getclick_settle_start
   ;
   ; time arrivial of second start click
   ;
   ldi click_space, (settle_count+1) ; +1 for overhead
   getclick_time_start:
      inc click_space
         breq getclick_timeout ; check for overflow
      sbic PINA, click_pin ; check for click
         rjmp getclick_time_start
   mov triple_space, click_space
   add triple_space, click_space
   add triple_space, click_space
   ;
   ; decode data clicks
   ;
   clr rxbyte
   ldi bit_count, 8
   getclick_bitloop:
      ;
      ; delay for click to settle
      ;
      ldi loop_count, settle_count
      getclick_settle:
         dec loop_count
         nop ; to even out timing for breq
         brne getclick_settle
      ;
      ; time arrivial of next click
      ;
      ldi loop_count, settle_count
      getclick_time:
         inc loop_count
         breq getclick_timeout ; check for overflow
         sbic PINA, click_pin ; check for click
            rjmp getclick_time
      ;
      ; determine bit delay
      ;
      mov double_count, loop_count
      add double_count, loop_count
      cp double_count, triple_space
      brsh getclick_zero
         ;
         ; one bit
         ;
         sec ; set carry
         ror rxbyte ; shift in carry
         ;
         ; even out 0/1 timing
         ;
         mov loop_count, click_space
         getclick_space:
            dec loop_count
            nop ; to even out timing for breq
            brne getclick_space
         ;
         ; decrement counter and output if byte received
         ;
         dec bit_count
      	brne getclick_bitloop
   	     rjmp getclick_end
      getclick_zero:
         ;
         ; zero bit
         ; 
         clc ; clear carry
         ror rxbyte ; shift in carry
         ;
         ; decrement counter and output if byte received
         ;
         dec bit_count
         brne getclick_bitloop
      getclick_end:
         ;
	      ; wait for stop clicks and return
	      ;
         getclick_end_0_up:
            sbis PINA, click_pin
	            rjmp getclick_end_0_up
         getclick_end_1_down:
            sbic PINA, click_pin
	            rjmp getclick_end_1_down
         getclick_end_1_up:
            sbis PINA, click_pin
	            rjmp getclick_end_1_up
         getclick_end_2_down:
            sbic PINA, click_pin
	            rjmp getclick_end_2_down
         getclick_end_2_up:
            sbis PINA, click_pin
	            rjmp getclick_end_2_up
	      ret
      getclick_timeout:
         ldi rxbyte, 0
	      ret
;
; getchar
; assumes no line driver (doesn't invert bits)
;
getchar:
   ldi bit_count,9 ; 8 data bit + 1 stop bit
   getchar1:
      sbis PINA, rx_pin ; wait for start bit
      rjmp getchar1
   rcall bitdelay ; 0.5 bit delay
   getchar2:
      rcall bitdelay ; 1 bit delay
      rcall bitdelay ;
      clc ; clear carry
      sbis PINA, rx_pin ; if RX pin high skip
         sec ; otherwise set carry
      dec bit_count
      breq getchar3 ; return if all bits read
      ror rxbyte ; otherwise shift bit into receive byte
      rjmp getchar2 ; go get next bit
   getchar3:
      ret
;
; putclick
; send char in txbyte clicks
;
putclick:
   ldi bit_count, 8
   sec; set start bit
   ;
   ; set click pin to output
   ;
   sbi DDRA, click_pin
   ;
   ; send start clicks
   ;
   cbi PORTA, click_pin
   rcall click_duration
   sbi PORTA, click_pin
   rcall click_delay
   cbi PORTA, click_pin
   rcall click_duration
   sbi PORTA, click_pin
   rcall click_delay
   ;
   ; send data clicks
   ;
   putclick0:
      lsr txbyte; get next bit
         brcc putclick1 ; if carry set, send a 1 click
      cbi PORTA, click_pin
      rcall click_duration
      sbi PORTA, click_pin
      rcall click_delay
      sbi PORTA, click_pin
      rcall click_duration
      sbi PORTA, click_pin
      rcall click_delay
      rjmp putclick2; otherwise ...
   putclick1:
      sbi PORTA, click_pin ; ... send a 0 click
      rcall click_duration
      sbi PORTA, click_pin
      rcall click_delay
      cbi PORTA, click_pin
      rcall click_duration
      sbi PORTA, click_pin
      rcall click_delay
   putclick2:
      dec bit_count; if not all bits sent
      brne putclick0; send next bit
   ;
   ; send stop clicks
   ;
   cbi PORTA, click_pin
   rcall click_duration
   sbi PORTA, click_pin
   rcall click_delay
   cbi PORTA, click_pin
   rcall click_duration
   sbi PORTA, click_pin
   rcall click_delay
   ;
   ; set click pin to input with pull-up
   ;
   cbi DDRA, click_pin
   ;
   ; return
   ;
   ret
;
; putchar
; assumes no line driver (doesn't invert bits)
;
.equ sb = 1; number of stop bits
putchar:
   ldi bit_count, 9+sb; 1+8+sb
   com txbyte; invert everything
   sec; set start bit
   putchar0:
      brcc putchar1; if carry set
      sbi PORTA, tx_pin ; send a '0'
      rjmp putchar2; else
   putchar1:
       cbi PORTA, tx_pin ; send a '1'
       nop ; even out timing
   putchar2:
       rcall bitdelay; one bit delay
       rcall bitdelay
       lsr txbyte; get next bit
       dec bit_count; if not all bits sent
       brne putchar0; send next bit
   ret;
;
; put_i0_slip
; send char in txbyte with SLIP mapping to i0
;
put_i0_slip:
   put_i0_slip_END:
      ldi temp, END
      cpse txbyte, temp
         rjmp put_i0_slip_ESC
      ;
      ; END char
      ;
      mov temp, txbyte
      ldi txbyte, ESC
      rcall putclick
      rcall char_delay
      ldi txbyte, ESC_END
      rcall putclick
      rcall char_delay
      mov txbyte, temp
      ret
   put_i0_slip_ESC:
      ldi temp, ESC
      cpse txbyte, temp
         rjmp put_i0_slip_char
      ;
      ; ESC char
      ;
      mov temp, txbyte
      ldi txbyte, ESC
      rcall putclick
      rcall char_delay
      ldi txbyte, ESC_ESC
      rcall putclick
      rcall char_delay
      mov txbyte, temp
      ret
   put_i0_slip_char:
      ;
      ; ordinary char, no escape needed
      ;
      mov temp, txbyte
      rcall putclick
      rcall char_delay
      mov txbyte, temp
      ret
;
; put_serial_slip
; send char in txbyte with SLIP mapping to serial
;
put_serial_slip:
   put_serial_slip_END:
      ldi temp, END
      cpse txbyte, temp
         rjmp put_serial_slip_ESC
      ;
      ; END char
      ;
      mov temp, txbyte
      ldi txbyte, ESC
      rcall putchar
      rcall char_delay
      ldi txbyte, ESC_END
      rcall putchar
      rcall char_delay
      mov txbyte, temp
      ret
   put_serial_slip_ESC:
      ldi temp, ESC
      cpse txbyte, temp
         rjmp put_serial_slip_char
      ;
      ; ESC char
      ;
      mov temp, txbyte
      ldi txbyte, ESC
      rcall putchar
      rcall char_delay
      ldi txbyte, ESC_ESC
      rcall putchar
      rcall char_delay
      mov txbyte, temp
      ret
   put_serial_slip_char:
      ;
      ; ordinary char, no escape needed
      ;
      mov temp, txbyte
      rcall putchar
      rcall char_delay
      mov txbyte, temp
      ret
;
; put_i0_packet
; send i0 packet
;
put_i0_packet:
   ;
   ; CSMA check
   ;
   put_i0_packet_CSMA:
      ldi temp, csma_count
	   put_i0_packet_CSMA_loop:
         sbis PINA, click_pin
            rjmp put_i0_packet_CSMA_delay
         dec temp
	      brne put_i0_packet_CSMA_loop
            rjmp put_i0_packet_CSMA_continue
      put_i0_packet_CSMA_delay:
         ldi temp, csma_count
	      put_i0_packet_CSMA_delay_loop:
            dec temp
	         brne put_i0_packet_CSMA_delay_loop
         rjmp put_i0_packet_CSMA
      put_i0_packet_CSMA_continue:
   ;
   ; send start
   ;
   ldi txbyte, END
   rcall putclick
   rcall char_delay
   ;
   ; send packet with SLIP mapping
   ;
   point_to(ramstart)
   mov loop_count, byte_count
   put_i0_packet_loop:
      ld txbyte, z+
      rcall put_i0_slip
      dec loop_count
      brne put_i0_packet_loop
   ;
   ; send end
   ;
   ldi txbyte, END
   rcall putclick
   rcall char_delay
   ;
   ; return
   ;
   ret   
;
; put_serial_packet
; send serial packet
;
put_serial_packet:
   ;
   ; send start
   ;
   ldi txbyte, END
   rcall putchar
   rcall char_delay
   ;
   ; send packet with SLIP mapping
   ;
   point_to(ramstart)
   mov loop_count, byte_count
   put_serial_packet_loop:
      ld txbyte, z+
      rcall put_serial_slip
      dec loop_count
      brne put_serial_packet_loop
   ;
   ; send end
   ;
   ldi txbyte, END
   rcall putchar
   rcall char_delay
   ;
   ; return
   ;
   ret   
;
; get_i0_packet
; read an i0 packet to SRAM following starting SLIP END character,
; removing SLIP mapping
;
get_i0_packet:
   ;
   ; set Z to point to start of SRAM
   ;
   point_to(ramstart)
   clr byte_count
   get_i0_packet_mainloop:
      ;
      ; wait for start click
      ;
      clr count_lo
      mov count_hi, one
      get_i0_packet_waitloop:
         add count_lo, one
         adc count_hi, zero
         breq get_i0_packet_timeout ; time-out if loop count overflows
         sbic PINA, click_pin ; check i0 pin for click
         rjmp get_i0_packet_waitloop
      ;
      ; read next byte
      ;
      rcall getclick
      ;
      ; check for SLIP escape
      ;
      cpi rxbyte, ESC
      brne get_i0_packet_store_byte
         ;
      	; found escape, read next character after next click
         ;
         get_i0_packet_waitloop1:
            sbic PINA, click_pin ; check i0 pin for click
	         rjmp get_i0_packet_waitloop1
         rcall getclick
	      cpi rxbyte, ESC_ESC
            brne get_i0_packet_END
	      ;
	      ; store an ESC
	      ;
	      ldi rxbyte, ESC
         st z+, rxbyte
         inc byte_count ; check for byte count overflow
            breq get_i0_packet_timeout
	      rjmp get_i0_packet_mainloop
	   get_i0_packet_END:
	      ;
	      ; store an END
	      ;
	      ldi rxbyte, END
         st z+, rxbyte
         inc byte_count ; check for byte count overflow
            breq get_i0_packet_timeout
	      rjmp get_i0_packet_mainloop
      ;
      ; store byte
      ;
      get_i0_packet_store_byte:
         st z+, rxbyte
         inc byte_count ; check for byte count overflow
            breq get_i0_packet_timeout
      ;
      ; go back for next byte if not END
      ;
      ldi temp, END
      cpse rxbyte, temp
         rjmp get_i0_packet_mainloop
      dec byte_count ; drop END
      ret
   get_i0_packet_timeout:
      clr byte_count
      ret
;
; get_serial_packet
; read a serial packet to SRAM following starting SLIP END character,
; removing SLIP mapping
;
get_serial_packet:
   ;
   ; set Z to point to start of SRAM
   ;
   point_to(ramstart)
   clr byte_count
   get_serial_packet_mainloop:
      ;
      ; wait for start bit
      ;
      clr count_lo
      mov count_hi, one
      get_serial_packet_waitloop:
         add count_lo, one
	      adc count_hi, zero
	      breq get_serial_packet_timeout ; time-out if loop count overflows
         sbis PINA, rx_pin ; check serial pin for start bit
	         rjmp get_serial_packet_waitloop
      ;
      ; read next byte
      ;
      rcall getchar
      ;
      ; check for SLIP escape
      ;
      cpi rxbyte, ESC
         brne get_serial_packet_store_byte
      ;
      ; found escape, read next character after next start bit
      ;
      get_serial_packet_waitloop1:
         sbis PINA, rx_pin ; check serial pin for start bit
	         rjmp get_serial_packet_waitloop1
      rcall getchar
	   cpi rxbyte, ESC_ESC
	   brne get_serial_packet_END
	   ;
	   ; store an ESC
	   ;
	   ldi rxbyte, ESC
      st z+, rxbyte
      inc byte_count ; check for byte count overflow
      breq get_serial_packet_timeout
	      rjmp get_serial_packet_mainloop
	get_serial_packet_END:
	   ;
	   ; store an END
	   ;
	   ldi rxbyte, END
         st z+, rxbyte
         inc byte_count ; check for byte count overflow
         breq get_serial_packet_timeout
	         rjmp get_serial_packet_mainloop
      ;
      ; store byte
      ;
      get_serial_packet_store_byte:
         st z+, rxbyte
         inc byte_count ; check for byte count overflow
         breq get_serial_packet_timeout
      ;
      ; go back for next byte if not END
      ;
      ldi temp, END
      cpse rxbyte, temp
         rjmp get_serial_packet_mainloop
      dec byte_count ; drop END
      rjmp get_serial_packet_return
   get_serial_packet_timeout:
      ;
      ; time-out, clear byte count
      ;
      clr byte_count
   get_serial_packet_return:
      ;
      ; return
      ;
      ret
;
; main program
;
reset:
   ;
   ; set fuse low byte to 0x7E for 20 MHz resonator
   ;
   ; set clock divider to /1
   ;
   ldi temp, (1 << CLKPCE)
   ldi temp1, (0 << CLKPS3) | (0 << CLKPS2) | (0 << CLKPS1) | (0 << CLKPS0)
   out CLKPR, temp
   out CLKPR, temp1
   ;
   ; set stack pointer to top of RAM
   ;
   ldi temp, high(RAMEND)
   out SPH, temp
   ldi temp, low(RAMEND)
   out SPL, temp
   ;
   ; init RS-232 pin for output
   ;
   cbi PORTA, tx_pin
   sbi DDRA, tx_pin
   ;
   ; init click pin for input with pull-up
   ;
   sbi PORTA, click_pin
   cbi DDRA, click_pin
   ;
   ; init LED pin
   ;
   sbi PORTA, led_pin
   sbi DDRA, led_pin
   ;
   ; init registers
   ;
   clr zero
   clr one
   inc one
   ;
   ; start main loop
   ;
   main_loop:
      ;
      ; wait for i0 or serial bytes
      ;
      wait_loop:
         sbis PINA, click_pin ; check i0 pin for click
            rjmp i0_to_serial
         sbis PINA, rx_pin ; check serial pin for start bit
            rjmp wait_loop
      serial_to_i0:
         ;
         ; read from serial, write to i0
         ;
         cbi PORTA, led_pin ; turn on LED
 	      ;
	      ; check for serial SLIP start of packet (END character)
	      ;
	      rcall getchar
	      ldi temp, END
	      cpse rxbyte, temp
         ;
	      ; not start of packet, go back and wait for next char
	      ;
	      rjmp main_loop
         ;
	      ; found start, get rest of serial packet and send to i0
	      ;
         rcall get_serial_packet
         rcall put_i0_packet
         sbi PORTA, led_pin ; turn off LED
         rjmp main_loop ; return to main loop
      i0_to_serial:
         ;
	      ; read from i0, write to serial
	      ;
         cbi PORTA, led_pin ; turn on LED
 	      ;
	      ; check for i0 SLIP start of packet (END character)
	      ;
	      rcall getclick
	      ldi temp, END
	      cpse rxbyte, temp
         ;
	      ; not start of packet, go back and wait for next char
	      ;
	      rjmp main_loop
         ;
	      ; found start, get rest of i0 packet and send to serial
	      ;
         rcall get_i0_packet
         rcall put_serial_packet
         sbi PORTA, led_pin ; turn off LED
         rjmp main_loop ; return to main loop
