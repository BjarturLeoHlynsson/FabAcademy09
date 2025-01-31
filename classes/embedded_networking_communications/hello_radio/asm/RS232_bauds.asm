;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Baud rate definitions
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; by Charlie DeTar (2008)

; See Atmel application note AVR305
;
;  def get_bit_delay(fclock, baud): return (float(fclock) / baud - 23) / 6
;


; 1MHz clock
.if (CLOCKSPEED == 1000000)
   .set RS232_110 = 1511
   .set RS232_300 = 551
   .set RS232_600 = 273
   .set RS232_1200 = 135
   .set RS232_2400 = 65
   .set RS232_4800 = 30
   .set RS232_9600 = 13
   .set RS232_14400 = 7
   .set RS232_19200 = 4
   .set RS232_28800 = 1

; 8MHz clock
.elif (CLOCKSPEED == 8000000)
   .set RS232_110 = 12117
   .set RS232_300 = 4440
   .set RS232_600 = 2218
   .set RS232_1200 = 1107
   .set RS232_2400 = 551
   .set RS232_4800 = 273
   .set RS232_9600 = 135
   .set RS232_14400 = 88
   .set RS232_19200 = 65
   .set RS232_28800 = 42
   .set RS232_38400 = 30
   .set RS232_56000 = 19
   .set RS232_57600 = 19
   .set RS232_115200 = 7

; 10MHz clock
.elif (CLOCKSPEED == 10000000)
   .set RS232_110 = 15148
   .set RS232_300 = 5552
   .set RS232_600 = 2774
   .set RS232_1200 = 1385
   .set RS232_2400 = 691
   .set RS232_4800 = 343
   .set RS232_9600 = 170
   .set RS232_11400 = 142
   .set RS232_19200 = 83
   .set RS232_28800 = 54
   .set RS232_38400 = 40
   .set RS232_56000 = 26
   .set RS232_57600 = 25
   .set RS232_115200 = 11

; 20MHz clock
.elif (CLOCKSPEED == 20000000)
   .set RS232_110 = 30299
   .set RS232_300 = 11107
   .set RS232_600 = 5551
   .set RS232_1200 = 2773
   .set RS232_2400 = 1385
   .set RS232_4800 = 690
   .set RS232_9600 = 343
   .set RS232_14400 = 227
   .set RS232_19200 = 169
   .set RS232_28800 = 111
   .set RS232_38400 = 82
   .set RS232_56000 = 55
   .set RS232_57600 = 54
   .set RS232_115200 = 25

.endif

; defaults:
.set RS232_BAUD_RATE = RS232_9600
.set RS232_STOP_BITS = 1
