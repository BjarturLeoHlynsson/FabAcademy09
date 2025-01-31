;
;  "Messager" -- send short text messages (160 characters) using IA4421 or
;                equivalent radio chip. 
;
;  At startup, begin listening for radio packets.  If a valid packet arrives,
;  store it in SRAM, then read it from SRAM and send it over serial to an 
;  attached computer.
;
;  If an interrupt occurs on the serial RX pin, stop listening to the radio and
;  receive the serial message.  Store it in SRAM, then put the radio in
;  transmit mode and send the message out. 
;
;
; Charlie DeTar, 2008
;

.device ATtiny44

;
; Constants
; 
.equ RAMSTART = 0x0060 ; beginning of SRAM
.equ PACKET_LENGTH = 160
.equ PACKET_START = RAMSTART

;
; Registers
;

                   ;    = R16
.def temp               = R17; temporary var
.def temp1              = R18; temporary var
.def serial_byte        = R19; byte for serial read/write
.def spi_byte           = R20; byte for SPI read/write
.def packet_byte_count  = R21; 
                   ;    = R22;
                   ;    = R23;
                   ;    = R24;
                   ;    = R25;
                   ; XL = R26
                   ; XH = R27
                   ; YL = R28
                   ; YH = R29
                   ; ZL = R30
                   ; ZH = R31

;
; Pins
;

; Port A 

; These IA_ definitions are required for the IA4421_code.asm macros and
; routines.
.equ IA_NSEL = PA0
.equ IA_NSEL_PORT = PORTA
.equ IA_NSEL_DDR = DDRA

.equ IA_MOSI = PA6
.equ IA_MOSI_PORT = PORTA
.equ IA_MOSI_DDR = DDRA

.equ IA_MISO = PA5
.equ IA_MISO_PORT = PORTA
.equ IA_MISO_DDR = DDRA
.equ IA_MISO_PIN = PINA

.equ IA_SCK = PA4
.equ IA_SCK_PORT = PORTA
.equ IA_SCK_DDR = DDRA

; Serial pins
.equ TX   = PA7
.equ TX_PORT = PORTA
.equ TX_DDR = DDRA

.equ RX   = PB2
.equ RX_PORT = PORTB
.equ RX_DDR = DDRB
.equ RX_PIN = PINB

;
;  Code segment
;
.cseg
.org 0
rjmp reset
.org 2  ; EXT INT0 (PB2) interrupt, serial receive
rjmp serial_receive_interrupt

.set CLOCKSPEED = 8000000 ; 8MHz
.include "delays_8MHz.asm"

.include "IA4421_config.asm"
.include "IA4421_code.asm"

;
; Serial getchar/putchar
;
.include "RS232_bauds.asm"
.set RS232_BAUD_RATE = RS232_9600
.include "RS232.asm"

putchar:
    rs232_putchar TX_PORT, TX, serial_byte
    ret

getchar:
    rs232_getchar RX_PIN, RX, serial_byte
    ret

;
; Radio routines
;

serial_packet_to_sram:
    ldi XL, low(PACKET_START)
    ldi XH, high(PACKET_START)
    ldi packet_byte_count, PACKET_LENGTH

    serial_packet_to_sram_loop:
        rcall getchar
        st X+, serial_byte
        dec packet_byte_count
        brne serial_packet_to_sram_loop
    ret

; Listens for a valid packet from the radio, and blocks until one arrives.
; Stores the packet to SRAM.
radio_packet_to_sram:
    ldi XL, low(PACKET_START)
    ldi XH, high(PACKET_START)

    ldi packet_byte_count, PACKET_LENGTH

    ; check framing
    ia_read_fifo
    cpi spi_byte, 1
    brne radio_packet_to_sram_clear
    ia_read_fifo
    cpi spi_byte, 2
    brne radio_packet_to_sram_clear
    ia_read_fifo
    cpi spi_byte, 3
    brne radio_packet_to_sram_clear
    ia_read_fifo
    cpi spi_byte, 4
    brne radio_packet_to_sram_clear

    radio_packet_to_sram_loop:
        ia_read_fifo
        st X+, spi_byte
        dec packet_byte_count
        brne radio_packet_to_sram_loop
    reset_fifo_synchron_latch
    ret
    ; if framing fails, reset latches and start listening again.
    radio_packet_to_sram_clear:
        reset_fifo_synchron_latch ; tell radio to look for synch bytes again
        rjmp radio_packet_to_sram

; Send the packet stored in SRAM along the serial line.
send_packet_to_serial:
    ldi XL, low(PACKET_START)
    ldi XH, high(PACKET_START)

    ldi packet_byte_count, PACKET_LENGTH
    send_packet_to_serial_loop:
        ld serial_byte, X+
        rcall putchar
        dec packet_byte_count
        brne send_packet_to_serial_loop
    ret

; Turn on transmitter, send preamble and framing bytes, then send 
; the packet stored in SRAM to the radio.
send_packet_to_radio:
    ldi XL, low(PACKET_START)
    ldi XH, high(PACKET_START)
    ldi packet_byte_count, PACKET_LENGTH

    transmitter_startup_sequence
    send_preamble

    ; send framing
    ia_send_tx_reg 1
    ia_send_tx_reg 2
    ia_send_tx_reg 3
    ia_send_tx_reg 4

    send_packet_to_radio_loop:
        ld temp1, X+
        ia_send_tx_reg_r temp1
        dec packet_byte_count
        brne send_packet_to_radio_loop

    transmitter_shutdown_sequence
    ret

; fill SRAM with a simple test pattern (counting down from PACKET_LENGTH)
; for debugging purposes.
test_pattern_to_sram:
    ldi XL, low(PACKET_START)
    ldi XH, high(PACKET_START)
    ldi packet_byte_count, PACKET_LENGTH
    test_pattern_to_sram_loop:
        st X+, packet_byte_count
        dec packet_byte_count
        brne test_pattern_to_sram_loop
    ret

; Interrupt service routine for serial receiving.
serial_receive_interrupt:
    cli ; disable interrupts
    rcall serial_packet_to_sram
    rcall send_packet_to_radio
    ;rcall send_packet_to_serial ; debug- echo packet back to computer
    sei ; resume interrupts.
    reti

reset:
    ;
    ; set stack pointer to top of RAM
    ;
    ldi temp, high(RAMEND)
    out SPH, temp
    ldi temp, low(RAMEND)
    out SPL, temp
    ;
    ; set clock speed to /1, 8MHz
    ;
    ldi temp, (1 << CLKPCE)
    ldi temp1, (0 << CLKPS3)|(0 << CLKPS2)|(0 << CLKPS1)|(0 << CLKPS0)
    out CLKPR, temp
    out CLKPR, temp1

    ;
    ; initialize pins
    ;
    cbi RX_PORT, RX
    cbi RX_DDR, RX
    cbi TX_PORT, TX
    sbi TX_DDR, TX

    ;
    ; Enable interrupt for serial receive
    ;
    ldi temp, (1 << ISC01)|(1 << ISC00) ; trigger on rising edge (start bit)
    out MCUCR, temp
    ldi temp, (1 << INT0) ; int0 only
    out GIMSK, temp
    sei ; enable interrupts globally

    ;
    ; initialize radio
    ;
    initialize_IA4421
    transmitter_off_receiver_on

    ;
    ; Main loop: wait for a radio packet, send it along when it gets here.
    ;
    main_loop:
        rcall radio_packet_to_sram
        rcall send_packet_to_serial
        rjmp main_loop
