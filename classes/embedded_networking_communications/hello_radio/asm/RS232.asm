; Copyright (c) 2008 Charlie DeTar
; 
; "MIT License":
;
; Permission is hereby granted, free of charge, to any person
; obtaining a copy of this software and associated documentation
; files (the "Software"), to deal in the Software without
; restriction, including without limitation the rights to use,
; copy, modify, merge, publish, distribute, sublicense, and/or sell
; copies of the Software, and to permit persons to whom the
; Software is furnished to do so, subject to the following
; conditions:
; 
; The above copyright notice and this permission notice shall be
; included in all copies or substantial portions of the Software.
; 
; THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
; EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
; OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
; NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
; HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
; WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
; FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
; OTHER DEALINGS IN THE SOFTWARE.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;  
;
; Software RS232 routines.  These routines assume there is no 
; line driver (they don't perform bit inversion), so the logical 1 
; (defined as -12 volts per RS232) is 0 volts, and the logical 0
; (defined as 12 volts per RS232) is Vcc.  This works.  Thanks to
; Neil Gershenfeld for this trick.
;
;
; Requires the following register definitions:
;    temp - clobbered by putchar and getchar
;     
; Requires the following .equ's:
;    CLOCKSPEED in hz
;
; To use, define routines which implement the macros here, providing pin
; and port values and a register to use for serial data.  For example:
;
; putchar:
;    rs232_putchar PORTA, PA3, R16 ; note PORT
;    ret
;
; getchar:
;    rs232_getchar PINA, PA2, R16 ; note PIN
;    ret
;
; Baud rates must be set prior to including this file, like so:
;
;   .include "RS232_bauds.asm"
;   .set RS232_BAUD_RATE = RS232_115200
;   .include "RS232.asm"
;


;
; Like AVR application note's bit_delay, but doesn't clobber temp.
; pushing and popping temp eats 4 cycles (where each
; loop eats 3), so decrease loop count by 2 (reclaiming
; 6 cycles) and add 2 nops.
;
rs232_bit_delay:
   push temp ; eats 2 cycles
   ldi temp, RS232_BAUD_RATE - 2 ; 6 cycles less delay
   rs232_bit_delay_loop:
      dec temp
      brne rs232_bit_delay_loop
   nop 
   nop ; eat 2 cycles
   pop temp ; eats 2 more
   ret
;
; putchar macro - use to construct a putchar routine.
;
; Arguments:
;  @0, @1 - PORT and pin values, e.g. "PORTA, PA3"
;  @2 - register to read byte to send from, e.g. "R23"
;
; example:
; putchar:
;    rs232_putchar PORTA, PA3, R23
;    ret
;
.macro rs232_putchar
   ldi temp, 9 + RS232_stop_bits; 1 + 8 + sb
   com @2; invert everything
   sec ; set start bit
   rs232_putchar0:
      brcc rs232_putchar1 ; if carry set
      sbi @0, @1; send a '0'
      rjmp rs232_putchar2; else
   rs232_putchar1:
      cbi @0, @1 ; send a '1'
      nop ; even out timing
   rs232_putchar2:
      rcall rs232_bit_delay ; one bit delay
      rcall rs232_bit_delay
      lsr @2 ; get next bit
      dec temp ; if not all bits sent
      brne rs232_putchar0 ; set next bit
.endmacro
;
; getchar macro - use to construct a getchar routine.
;
; Arguments:
;  @0, @1 - serial rx PIN and number, e.g. "PINA, PA3"
;  @2 - register for received data.
;
; Example:
; getchar:
;    rs232_getchar PINA, PA3, R23
;
.macro rs232_getchar
   ldi temp, 8 + RS232_stop_bits ; 8 data bit + 1 stop bit
   rs232_getchar1:
      sbis @0, @1 ; wait for start bit
      rjmp rs232_getchar1
      rcall rs232_bit_delay ; 0.5 bit delay
   rs232_getchar2:
      rcall rs232_bit_delay ; 1 bit delay
      rcall rs232_bit_delay ;
      clc ; clear carry
      sbis @0, @1 ; if RX pin high skip
         sec ; otherwise set carry
      dec temp
      breq rs232_getchar3 ; return if all bits read
      ror @2 ; otherwise shift bit into receive byte
      rjmp rs232_getchar2 ; go get next bit
   rs232_getchar3:
.endmacro
