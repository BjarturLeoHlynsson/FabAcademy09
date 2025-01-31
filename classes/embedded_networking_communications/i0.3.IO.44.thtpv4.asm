;
; i0.3.IO.44.thtpv4.asm
; i0 three-wire I/O node demonstration code
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
.equ Web_port = 80 ; Web server port
.equ set_source_address_port = 1000 ; port to set board's source address
.equ set_destination_address_port = 1001 ; port to set board's destination address 
.equ toggle_port = 1002 ; port to toggle the light
.equ set_destination_flag = 1 ; status flag for setting destination address
.equ set_source_flag = 2 ; status flag for setting source address
.equ click_pin = PA0 ; i0 click pin
.equ click_count = 10 ; loop count to wait during click
.equ settle_count = 20 ; loop count to wait for click to settle
.equ delay_count = 30 ; loop count to wait between clicks
.equ char_delay_count = 15 ; loop count for character delay
.equ csma_count = 20 ; loop count for CSMA check
.equ button_bit = 2 ; button bit
.equ button_pin = PA2 ; button pin
.equ mosfet_pin = PA7 ; MOSFET pin
.equ LED_pin = PA3 ; LED pin
.equ END = 192 ; SLIP definitions
.equ ESC = 219 ; "
.equ ESC_END = 220 ; "
.equ ESC_ESC = 221 ; "
.equ eeprom_source_address = 0 ; EEPROM addresses
.equ eeprom_destination_address = eeprom_source_address + 4 ; "
;
; registers
;
.def zero = R1 ; 0
.def one = R2 ; 1
.def double_count = R3 ; double loop count
.def triple_space = R4 ; triple click spacing
.def check_lo = R5 ; lo checksum accumulator
.def check_hi = R6 ; hi checksum accumulator
.def check_carry = R7 ; checksum carry accumulator
.def bit_count = R16 ; bit counter
.def byte_count = R17 ; byte counter
.def txbyte = R18 ; transmit byte
.def rxbyte = R19 ; receive byte
.def temp = R20 ; temporary storage
.def temp1 = R21 ; temporary storage
.def temp2 = R22 ; temporary storage
.def temp3 = R23 ; temporary storage
.def flags = R24 ; status flags
.def click_space = R25 ; click spacing
.def count = R26 ; loop counter (X low)
.def count_hi = R27 ; loop counter (X high)
; R28, 29 used for Y pointer
; R30, 31 used for Z pointer
;
; macros
;
; copy
;
.macro copy
   ;
   ; copy bytes between two memory locations
   ; copy destination, source
   ;
   ldi zh, high(@1)
   ldi zl, low(@1)
   ld temp, z
   ldi zh, high(@0)
   ldi zl, low(@0)
   st z, temp
   .endmacro
;
; compare
;
.macro compare
   ;
   ; compare two memory locations
   ;
   ldi zh, high(@1)
   ldi zl, low(@1)
   ld temp, z
   ldi zh, high(@0)
   ldi zl, low(@0)
   ld temp1, z
   cp temp, temp1
   .endmacro
;
; compare_immediate
;
.macro compare_immediate
   ;
   ; compare memory location with a constant
   ;
   ldi zh, high(@0)
   ldi zl, low(@0)
   ld temp, z
   cpi temp, @1
   .endmacro
;
; store_immediate
;
.macro store_immediate
   ;
   ; store immediate constant to memory
   ;
   ldi temp, @1
   sts @0, temp
   .endmacro
;
; set_data
;
.macro set_data
   ;
   ; set Y registers to point to data
   ;
   ldi yh, high(@0*2)
   ldi yl, low(@0*2)
   .endmacro
;
; putslip
;
.macro putslip
   ;
   ; putslip
   ; click char in txbyte, with SLIP mapping
   ;
   ldi temp, END
   cpse txbyte, temp
   rjmp putslipchar
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
      rjmp endputslip
   ldi temp, ESC
   cpse txbyte, temp
   rjmp putslipchar
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
      rjmp endputslip
   putslipchar:
      ;
      ; ordinary char, no escape needed
      ;
      rcall putclick
      rcall char_delay
   endputslip:
      .endmacro
;
; read_eeprom
;
.macro read_eeprom
   ;
   ; read EEPROM location to register
   ;
   read_eeprom_loop: ; make sure EEPROM is ready for writing
      sbic EECR, EEPE
         rjmp read_eeprom_loop
   ldi temp, high(@1)
   out EEARH, temp
   ldi temp, low(@1)
   out EEARL, temp
   sbi EECR, EERE
   in @0, EEDR
   .endmacro
;
; write_eeprom
;
.macro write_eeprom
   ;
   ; write register to EEPROM
   ;
   write_eeprom_loop: ; make sure EEPROM is ready for writing
      sbic EECR, EEPE
         rjmp write_eeprom_loop
   cbi EECR, EEPM1
   cbi EECR, EEPM0
   ldi temp, high(@0)
   out EEARH, temp
   ldi temp, low(@0)
   out EEARL, temp
   out EEDR, @1
   sbi EECR, EEMPE
   sbi EECR, EEPE
   .endmacro
;
; write_sram_to_eeprom
;
.macro write_sram_to_eeprom
   ;
   ; write SRAM location to EEPROM
   ;
   write_sram_to_eeprom_loop: ; make sure EEPROM is ready for writing
      sbic EECR, EEPE
         rjmp write_sram_to_eeprom_loop
   cbi EECR, EEPM1
   cbi EECR, EEPM0
   ldi temp, high(@0)
   out EEARH, temp
   ldi temp, low(@0)
   out EEARL, temp
   ldi zh, high(@1)
   ldi zl, low(@1)
   ld temp, z
   out EEDR, temp
   sbi EECR, EEMPE
   sbi EECR, EEPE
   .endmacro
;
; code segment
;
.cseg
.org 0
rjmp reset
;
; init_packet
; initialize outgoing packet in SRAM
;
init_packet:
   .equ ip_header_size = 20
   .equ ip_header_size_before_checksum = 10
   .equ ip_header_size_after_checksum = 8
   .equ udp_header_size = 8
   .equ outgoing_ip_start = SRAM_START;
   .equ outgoing_ip_length = outgoing_ip_start + 2
   .equ outgoing_ip_checksum = outgoing_ip_start + 10
   .equ outgoing_source_address = outgoing_ip_start + 12
   .equ outgoing_destination_address = outgoing_ip_start + 16
   .equ outgoing_udp_start = outgoing_ip_start + 20
   .equ outgoing_source_port = outgoing_udp_start
   .equ outgoing_destination_port = outgoing_udp_start + 2
   .equ outgoing_udp_length = outgoing_udp_start + 4
   ldi zl, low(outgoing_ip_start)
   ldi zh, high(outgoing_ip_start)
   ;
   ; IP
   ;
   ldi temp, 0x45 ; version = 4 (4 bits), header length = 5 32-bit words (4 bits)
      st z+, temp
   ldi temp, 0 ; type of service
      st z+, temp
   ldi temp, 0 ; packet length high byte (to be calculated)
      st z+, temp
   ldi temp, 0 ; packet length low byte (to be calculated)
      st z+, temp
   ldi temp, 0 ; identification (high byte)
      st z+, temp
   ldi temp, 0 ; identification (low byte)
      st z+, temp
   ldi temp, 0 ; flag (3 bits), fragment offset (13 bits) (high byte)
      st z+, temp
   ldi temp, 0 ; flag (3 bits), fragment offset (13 bits) (low byte)
      st z+, temp
   ldi temp, 255 ; time to live
      st z+, temp
   ldi temp, 17 ; protocol = 17 for UDP
      st z+, temp
   ldi temp, 0 ; header checksum (to be calculated)
      st z+, temp
   ldi temp, 0 ; header checksum (to be calculated)
      st z+, temp
   read_eeprom temp, eeprom_source_address ; source address byte 1
     st z+, temp
   read_eeprom temp, eeprom_source_address+1 ; source address byte 2
     st z+, temp
   read_eeprom temp, eeprom_source_address+2 ; source address byte 3
     st z+, temp
   read_eeprom temp, eeprom_source_address+3 ; source address byte 4
     st z+, temp
   read_eeprom temp, eeprom_destination_address ; destination address byte 1
     st z+, temp
   read_eeprom temp, eeprom_destination_address+1 ; destination address byte 2
     st z+, temp
   read_eeprom temp, eeprom_destination_address+2 ; destination address byte 3
     st z+, temp
   read_eeprom temp, eeprom_destination_address+3 ; destination address byte 4
     st z+, temp
   ;
   ; UDP
   ;
   ldi temp, 0 ; source port
      st z+, temp
   ldi temp, 0 ; source port
      st z+, temp
   ldi temp, 0 ; destination port
      st z+, temp
   ldi temp, 0 ; destination port
      st z+, temp
   ldi temp, 0 ; payload length high byte (to be calculated)
      st z+, temp
   ldi temp, 0 ; payload length low byte (to be calculated)
      st z+, temp
   ldi temp, 0 ; payload checksum (not used)
      st z+, temp
   ldi temp, 0 ; payload checksum (not used)
      st z+, temp
   ;
   ; null-terminated data messages
   ;
   empty_message:
      .db 0
   on_message:
      .db "HTTP/1.1 200 OK",13,10,"Content-Type: text/html",13,10,13,10,"<center><H1>light is on",13,10,0
   off_message:
      .db "HTTP/1.1 200 OK",13,10,"Content-Type: text/html",13,10,13,10,"<center><H1>light is off",13,10,0
   ret   
;
; get_I0_packet
; read an I0 packet to SRAM following starting SLIP END character,
; removing SLIP mapping
;
get_packet:
   .equ incoming_start = outgoing_ip_start + ip_header_size + udp_header_size
   .equ incoming_source_address = incoming_start + 12
   .equ incoming_destination_address = incoming_source_address + 4
   .equ incoming_destination_port = incoming_destination_address + 6
   ;
   ; set Z to point to start of SRAM
   ;
   ldi zl, low(incoming_start)
   ldi zh, high(incoming_start)
   clr byte_count
   get_packet_mainloop:
      ;
      ; wait for a click
      ;
      clr count
      ldi count_hi, 1
      get_packet_waitloop:
         add count, one
	      adc count_hi, zero
            breq get_packet_timeout ; time-out if loop count overflows
         sbic PINA, click_pin ; check i0 pin for click
	         rjmp get_packet_waitloop
      ;
      ; read next byte
      ;
      rcall getclick
      ;
      ; return if byte count overflows
      ;
      inc byte_count
         breq get_packet_timeout
      ;
      ; check for SLIP escape
      ;
      cpi rxbyte, ESC
      brne get_packet_store_byte
         ;
	      ; found escape, read next character after next click
	      ;
         get_packet_waitloop1:
            sbic PINA, click_pin ; check i0 pin for click
	            rjmp get_packet_waitloop1
         rcall getclick
	      cpi rxbyte, ESC_ESC
	      brne get_packet_END
	      ;
	      ; store an ESC
	      ;
	      ldi rxbyte, ESC
         st z+, rxbyte
	      rjmp get_packet_mainloop
	get_packet_END:
	   ;
	   ; store an END
	   ;
	   ldi rxbyte, END
      st z+, rxbyte
	   rjmp get_packet_mainloop
      ;
      ; store byte
      ;
      get_packet_store_byte:
         st z+, rxbyte
      ;
      ; go back for next byte if not END
      ;
      ldi temp, END
      cpse rxbyte, temp
         rjmp get_packet_mainloop
      ret
   get_packet_timeout:
      clr byte_count
      ret
;
; click_duration
; delay during click
;
click_duration:
   ldi temp, click_count
   click_duration_loop:
      dec temp
      brne click_duration_loop
   ret
;
; click_delay
; delay between clicks
;
click_delay:
   ldi temp, delay_count
   click_delay_loop:
      dec temp
      brne click_delay_loop
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
; getclick
; input an i0 byte following first click
;
getclick:
   ;
   ; delay for first click to settle
   ;
   ldi count, settle_count
   getclick_settle_start:
      dec count
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
      ldi count, settle_count
      getclick_settle:
         dec count
         nop ; to even out timing for breq
         brne getclick_settle
      ;
      ; time arrivial of next click
      ;
      ldi count, settle_count
      getclick_time:
         inc count
         breq getclick_timeout ; check for overflow
         sbic PINA, click_pin ; check for click
            rjmp getclick_time
      ;
      ; determine bit delay
      ;
      mov double_count, count
      add double_count, count
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
         mov count, click_space
         getclick_space:
            dec count
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
; packet_delay
; delay between packets
;
packet_delay:
   ldi temp, 255
   packet_delayloop:
      ldi temp1, 255
      packet_delayloop1:
         dec temp1
         brne packet_delayloop1
      dec temp
      brne packet_delayloop
   ret
;
; print_packet
; send a packet, calculating header checksum and doing SLIP encoding
; Y registers point to data
;
print_packet:
   ;
   ; count data length and store in packet
   ;
   mov zl, yl
   mov zh, yh
   clr count
   clr count_hi
   count_data_loop:
      adiw count, 1
      lpm temp, z+
      cpi temp, 0
      brne count_data_loop
   sbiw count,1 ; don't count the null termination
   adiw count, udp_header_size
   sts outgoing_udp_length, count_hi
   sts outgoing_udp_length+1, count
   adiw count, ip_header_size
   sts outgoing_ip_length, count_hi
   sts outgoing_ip_length+1, count
   ;
   ; find the IP header checksum and store in packet
   ;
   ldi zh, high(outgoing_ip_start)
   ldi zl, low(outgoing_ip_start)
   ldi count, ip_header_size
   clr check_lo
   clr check_hi
   clr check_carry
   ip_checksum_loop:
      adiw zl, 1
      ld temp, z
      dec count
      sbiw zl, 1
      ld temp1, z
      add check_lo, temp
      adc check_hi, temp1
      adc check_carry, zero
      adiw zl, 2
      dec count
      brne ip_checksum_loop
   add check_lo, check_carry
   adc check_hi, zero
   com check_lo
   com check_hi
   sts outgoing_ip_checksum, check_hi
   sts outgoing_ip_checksum+1, check_lo
   ;
   ; CSMA check
   ;
   print_packet_CSMA:
      ldi temp, csma_count
	   print_packet_CSMA_loop:
         sbis PINA, click_pin
            rjmp print_packet_CSMA_delay
         dec temp
	      brne print_packet_CSMA_loop
            rjmp print_packet_CSMA_continue
      print_packet_CSMA_delay:
         ldi temp, csma_count
	      print_packet_CSMA_delay_loop:
            dec temp
	         brne print_packet_CSMA_delay_loop
         rjmp print_packet_CSMA
      print_packet_CSMA_continue:
   ;
   ; send the packet
   ;
   ldi txbyte, END ; SLIP start
   rcall putclick
   rcall char_delay
   ldi zh, high(outgoing_ip_start)
   ldi zl, low(outgoing_ip_start)
   ldi count, (ip_header_size + udp_header_size)
   print_header_loop: ; IP + UDP header
      ld txbyte, z
      putslip
      adiw zl, 1
      dec count
      brne print_header_loop
   mov zl, yl
   mov zh, yh
   print_data_loop: ; data
      lpm txbyte, z+
      cpi txbyte, 0
         breq print_data_continue
      putslip
      rjmp print_data_loop
   print_data_continue:
   ldi txbyte, END ; SLIP end
   rcall putclick
   rcall char_delay
   ret
;
; handle button actions
;
button_pressed:
   ;
   ; is there a pending set source packet?
   ; 
   sbrc flags, set_source_flag
      rjmp button_pressed_set_source_address
   ;
   ; is there a pending set destination packet?
   ; 
   sbrc flags, set_destination_flag
      rjmp button_pressed_set_destination_address
   ;
   ; is the destination address not set?
   ;
   compare_immediate outgoing_destination_address, 255
      breq button_pressed_send_set_destination
   rjmp button_pressed_send_packet
   ;
   ; otherwise send a set destination packet
   ;
   button_pressed_send_set_destination:
      ;
      ; blink the light to acknowledge
      ;
      rcall blink
      rcall blink
      ;
      ; set up and send set destination packet
      ;
      store_immediate outgoing_source_port, high(set_destination_address_port)
      store_immediate outgoing_source_port+1, low(set_destination_address_port)
      store_immediate outgoing_destination_port, high(set_destination_address_port)
      store_immediate outgoing_destination_port+1, low(set_destination_address_port)
      set_data(empty_message)
      rcall print_packet
      ret
   button_pressed_set_source_address:
      ;
      ; blink the light to acknowledge
      ;
      rcall blink
      rcall blink
      ;
      ; set source address to destination address from last received packet
      ;
      copy outgoing_source_address, incoming_destination_address
      copy outgoing_source_address+1, incoming_destination_address+1
      copy outgoing_source_address+2, incoming_destination_address+2
      copy outgoing_source_address+3, incoming_destination_address+3
      ;
      ; save source address to EEPROM
      ;
      write_sram_to_eeprom eeprom_source_address, outgoing_source_address
      write_sram_to_eeprom eeprom_source_address+1, outgoing_source_address+1
      write_sram_to_eeprom eeprom_source_address+2, outgoing_source_address+2
      write_sram_to_eeprom eeprom_source_address+3, outgoing_source_address+3
      ;
      ; clear flags and return
      ;
      clr flags
      ret
   button_pressed_set_destination_address:
      ;
      ; blink the light to acknowledge
      ;
      rcall blink
      rcall blink
      ;
      ; set destination address to source address from last received packet
      ;
      copy outgoing_destination_address, incoming_source_address
      copy outgoing_destination_address+1, incoming_source_address+1
      copy outgoing_destination_address+2, incoming_source_address+2
      copy outgoing_destination_address+3, incoming_source_address+3
      ;
      ; save destination address to EEPROM
      ;
      write_sram_to_eeprom eeprom_destination_address, outgoing_destination_address
      write_sram_to_eeprom eeprom_destination_address+1, outgoing_destination_address+1
      write_sram_to_eeprom eeprom_destination_address+2, outgoing_destination_address+2
      write_sram_to_eeprom eeprom_destination_address+3, outgoing_destination_address+3
      ;
      ; clear flags and return
      ;
      clr flags
      ret
   button_pressed_send_packet:
      ;
      ; blink the light to acknowledge
      ;
      rcall blink
      ;
      ; set up and send toggle packet
      ;
      store_immediate outgoing_source_port, high(toggle_port)
      store_immediate outgoing_source_port+1, low(toggle_port)
      store_immediate outgoing_destination_port, high(toggle_port)
      store_immediate outgoing_destination_port+1, low(toggle_port)
      set_data(empty_message)
      rcall print_packet
      ret
;
; blink the light
;
blink:
   in temp, PORTA
   ldi temp1, ((1 << LED_pin) | (1 << mosfet_pin))
   eor temp, temp1
   out PORTA, temp
   rcall packet_delay
   in temp, PORTA
   ldi temp1, ((1 << LED_pin) | (1 << mosfet_pin))
   eor temp, temp1
   out PORTA, temp
   rcall packet_delay
   ret
;
; send the Web page
;
send_Web_page:
   ;
   ; blink the light to acknowledge
   ;
   rcall blink
   rcall blink
   ;
   ; set up and send Web page
   ;
   store_immediate outgoing_source_port, high(Web_port)
   store_immediate outgoing_source_port+1, low(Web_port)
   store_immediate outgoing_destination_port, high(Web_port)
   store_immediate outgoing_destination_port+1, low(Web_port)
   sbis PORTA, LED_pin
      rjmp Web_send_on
   Web_send_off:
      set_data(off_message)
      rjmp Web_send_continue
   Web_send_on:
      set_data(on_message)
   Web_send_continue:
      rcall print_packet
   ret
;
; toggle the light
;
toggle_light:
   in temp, PORTA
   ldi temp1, ((1 << LED_pin) | (1 << mosfet_pin))
   eor temp, temp1
   out PORTA, temp
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
   ; init click pin for input with pull-up
   ;
   sbi PORTA, click_pin
   cbi DDRA, click_pin
   ;
   ; init button for input with pull-up
   ;
   sbi PORTA, button_pin
   cbi DDRA, button_pin
   ;
   ; init LED for output
   ;
   sbi PORTA, LED_pin
   sbi DDRA, LED_pin
   ;
   ; init MOSFET pin for output
   ;
   cbi PORTA, mosfet_pin
   sbi DDRA, mosfet_pin
   ;
   ; init registers
   ;
   clr zero ; 0
   clr one ; 1
   inc one ; "
   ;
   ; set source address if not assigned
   ;
   read_eeprom temp, eeprom_source_address
   cpi temp, 255
      brne source_address_assigned
   source_address_not_assigned:
      ;
      ; turn on light, start counter, and wait for button to be pressed
      ;
      cbi PORTA, LED_pin
      clr temp1
      clr temp2
      clr temp3
      source_address_not_assigned_loop:
         add temp1, one
   	   adc temp2, zero
	      adc temp3, zero
         sbic PINA, button_bit
            rjmp source_address_not_assigned_loop
      ;
      ; wait for button to be released
      ;
      source_address_not_button_release:
         sbis PINA, button_bit
            rjmp source_address_not_button_release
      ;
      ; move address to EEPROM, acknowledge and turn off light
      ;
      write_eeprom eeprom_source_address+3, temp1
      write_eeprom eeprom_source_address+2, temp2
      write_eeprom eeprom_source_address+1, temp3
      ldi temp1, 169
      write_eeprom eeprom_source_address, temp1
      rcall blink
      rcall blink
      sbi PORTA, LED_pin
   source_address_assigned:
      ;
      ; init the packet
      ;
      rcall init_packet
   ;
   ; start event loop
   ;
   clr flags ; clear status flags
   mainloop:
      ;
      ; wait for the button to be pressed or a click to arrive
      ;
      waitloop:
         sbis PINA, click_pin ; check i0 pin for click
            rjmp click
         sbic PINA, button_bit ; check for button
            rjmp waitloop
      ;
      ; button pressed
      ;
      button:
         ;
         ; wait for button to be released
         ;
         button_release:
            sbis PINA, button_bit
               rjmp button_release
	      rcall button_pressed
         rjmp mainloop
      ;
      ; click arrived
      ;
      click:
	      ;
	      ; check for i0 SLIP start of packet (END character)
	      ;
	      rcall getclick
	      ldi temp, END
	      cpse rxbyte, temp
       ;
	    ; not start of packet, go back and wait for next char
	    ;
	    rjmp mainloop
    ;
	 ; found start, get rest of i0 packet
	 ;
    rcall get_packet
	 ;
	 ; return to mainloop if byte_count is zero
	 ;
	 tst byte_count
	    breq mainloop
	 ;
	 ; valid packet received, check for address assignment packets
	 ;
	 clr flags ; clear status flags
	 check_set_destination_address_port:
	    compare_immediate incoming_destination_port, high(set_destination_address_port)
	       brne check_set_source_address_port
	    compare_immediate incoming_destination_port+1, low(set_destination_address_port)
	       brne check_set_source_address_port
	    sbr flags, (1 << set_destination_flag)
	    rcall blink
	    rcall blink
       rjmp mainloop
	 check_set_source_address_port:
	    compare_immediate incoming_destination_port, high(set_source_address_port)
	       brne check_address
	    compare_immediate incoming_destination_port+1, low(set_source_address_port)
	       brne check_address
            sbr flags, (1 << set_source_flag)
	    rcall blink
	    rcall blink
       rjmp mainloop
	 ;
	 ; check to see if incoming destination address matches
	 ;
	 check_address:
	    mainloop_test_1:
 	       compare outgoing_source_address, incoming_destination_address
	       breq mainloop_test_2
	          rjmp mainloop
	    mainloop_test_2:
	       compare outgoing_source_address+1, incoming_destination_address+1
	       breq mainloop_test_3
	          rjmp mainloop
	    mainloop_test_3:
	       compare outgoing_source_address+2, incoming_destination_address+2
	       breq mainloop_test_4
	          rjmp mainloop
	    mainloop_test_4:
	       compare outgoing_source_address+3, incoming_destination_address+3
	       breq address_matches
	          rjmp mainloop
    ;
	 ; address matches, check port
	 ;
	 address_matches:
	    check_Web_port:
	       compare_immediate incoming_destination_port, high(Web_port)
	          brne check_toggle_port
	       compare_immediate incoming_destination_port+1, low(Web_port)
	          brne check_toggle_port
	       rcall send_Web_page
          rjmp mainloop
	    check_toggle_port:
	       compare_immediate incoming_destination_port, high(toggle_port)
	          brne port_not_assigned
	       compare_immediate incoming_destination_port+1, low(toggle_port)
	          brne port_not_assigned
	       rcall toggle_light
          rjmp mainloop
       port_not_assigned:
	       rjmp mainloop
