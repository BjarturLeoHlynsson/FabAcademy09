;
; IA4421_code.asm - macros for controlling IA4421 radio.
; By Charlie DeTar, 2008

; 
; Macros and routines for controlling the IA4421.
;
; To use, first include "IA4421_config.asm", then include this file 
; in the code segment.
;
; DEPENDENCIES - registers, routines, constants:
;
; 1. Depends on the following externally defined registers:
;
;    spi_byte
;    temp
;
; 2. Depends on the following externally defined routines:
;
;    delay_100ms - delay for 100 milliseconds then return
;    delay_5ms - delay for 5 milliseconds then return
;
; 3. Depends on the following externally defined constants:
;
;     IA_MISO      ; e.g. PA6  - this is "SDO" on IA4421
;     IA_MISO_PORT ; e.g. PORTA
;     IA_MISO_PIN  ; e.g. PINA
;     IA_MISO_DDR  ; e.g. DDRA
;     IA_MOSI      ; this is "SDI" on IA4421
;     IA_MOSI_PORT
;     IA_MOSI_DDR
;     IA_SCK
;     IA_SCK_PORT
;     IA_SCK_DDR
;     IA_NSEL
;     IA_NSEL_PORT
;     IA_NSEL_DDR
; 
; Note that these are just for basic SPI communication.  You may want
; to use NIRQ or NFFS, which you must handle externally.

.macro IA_MOSI_LO
   cbi IA_MOSI_PORT, IA_MOSI;
.endmacro
.macro IA_MOSI_HI
   sbi IA_MOSI_PORT, IA_MOSI;
.endmacro
.macro IA_SCK_LO
   cbi IA_SCK_PORT, IA_SCK;
.endmacro
.macro IA_SCK_HI
   sbi IA_SCK_PORT, IA_SCK;
.endmacro
.macro ia_toggle_sck
   IA_SCK_HI
   IA_SCK_LO
.endmacro
.macro IA_NSEL_ACTIVE
   cbi IA_NSEL_PORT, IA_NSEL;
.endmacro
.macro IA_NSEL_INACTIVE
   sbi IA_NSEL_PORT, IA_NSEL;
.endmacro
.macro skip_if_ia_miso_high
   sbis IA_MISO_PIN, IA_MISO
.endmacro
.macro skip_if_ia_miso_low
   sbic IA_MISO_PIN, IA_MISO
.endmacro
.macro ia_init_pins
   sbi IA_MOSI_DDR, IA_MOSI
   cbi IA_MISO_DDR, IA_MISO
   sbi IA_SCK_DDR, IA_SCK
   sbi IA_NSEL_DDR, IA_NSEL

   IA_MOSI_LO
   IA_SCK_LO
   IA_NSEL_INACTIVE
   sbi IA_NSEL_PORT, IA_NSEL
   cbi IA_MISO_PORT, IA_MISO ; ensure pullup is off

   
.endmacro

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Configuration Directives
;
; Here, we assemble the configuration snippets from IA4421_config.asm (or
; whatever other file is used for configuration) into the usable directives.
;
; The definition of config snippets and this assembling of them are separated
; to make it easy to share code among different configurations.  You should
; not have to modify anything here; just modify the configuration in 
; IA4421_config and tailor it to your needs.

; 1. Configuration Setting Command
.equ CONFIGURATION_SETTING_CMD = (0b10000000 << 8) | (ENABLE_DATA_REGISTER << 7) | (FIFO_MODE_ENABLE << 6) | (FREQUENCY_BAND << 4) | CRYSTAL_LOAD_CAPACITANCE;

.equ TX_REGISTER_ENABLE_CMD = CONFIGURATION_SETTING_CMD | 0x0080
.equ TX_REGISTER_DISABLE_CMD = CONFIGURATION_SETTING_CMD & (~0x0080)

; 2.  Power Management Command
; gavrasm borks on long expressions, so it is split up 
; into part1 and part2 here:
.equ pmc_part_1 = (0b10000010 << 8) | (ENABLE_WHOLE_RECEIVER_CHAIN << 7) | (ENABLE_RECEIVER_BASEBAND_CIRCUIT << 6)
.equ pmc_part_2 = (ENABLE_TRANSMITTER_CIRCUIT << 5) | (ENABLE_SYNTHESIZER << 4) | (ENABLE_CRYSTAL_OSCILLATOR << 3) | (ENABLE_LOW_BATTERY_DETECTOR << 2) | (ENABLE_WAKEUP_TIMER << 1) | DISABLE_CLOCK_OUTPUT
.equ POWER_MANAGEMENT_CMD = pmc_part_1 | pmc_part_2

.equ TX_ENABLE_RX_DISABLE_CMD = (POWER_MANAGEMENT_CMD | 0x0020) & (~0x0080)
.equ TX_DISABLE_RX_ENABLE_CMD = (POWER_MANAGEMENT_CMD | 0x0080) & (~0x0020)
.equ TX_AND_RX_DISABLE_CMD = (POWER_MANAGEMENT_CMD  & (~0x0080)) & (~0x0020)

; 3.  Frequency Setting Command
.equ FREQUENCY_SETTING_CMD = (0b1010 << 12) | F_PARAMETER

; 4.  Data Rate Command
.equ DATA_RATE_CMD = (0b11000110 << 8) | (DATA_RATE_CS << 7) | DATA_RATE_R;

; 5.  Receiver Control Command
.equ RECEIVER_CONTROL_CMD = (0b10010 << 11) | (PIN_16_FUNCTION << 10) | (VDI_RESPONSE_TIME << 8) | (RECEIVER_BASEBAND_BANDWIDTH << 5) | (RECEIVER_LNA_GAIN << 3) | (RSSI_DETECTOR_THRESHOLD);

; 6.  Data Filter Command
.equ DATA_FILTER_CMD = 0b1100001000101000 | (CLOCK_RECOVERY_LOCK_AUTO_MODE << 7) | (CLOCK_RECOVERY_LOCK_CONTROL << 6) | (DATA_FILTER_TYPE << 4) | DATA_QUALITY_DETECTOR_THRESHOLD

; 7.  FIFO and Reset Mode Command
.equ FIFO_AND_RESET_MODE_CMD = (0b11001010 << 8) | (FIFO_IT_LEVEL << 4) | (SYNCHRON_PATTERN_LENGTH << 3) | (FIFO_START_CONDITION << 2) | (ENABLE_FIFO_BUFFER_FILL << 1) | RESET_MODE_SENSITIVITY
.equ STOP_FIFO_BUFFER_FILL_CMD = FIFO_AND_RESET_MODE_CMD & (~0x0002)
.equ ENABLE_FIFO_BUFFER_FILL_CMD = FIFO_AND_RESET_MODE_CMD | 0x0002

; 8.  Synchron Pattern Command
.equ SYNCHRON_PATTERN_CMD = (0b11001110 << 8) | SYNCHRON_PATTERN_LSBYTE

; 9.  Receiver FIFO Read Command
.equ RECEIVER_FIFO_READ_CMD = 0b1011000000000000

; 10.  Automatic Frequency Correction Command
.equ AFC_CMD = (0b11000100 << 8) | (AFC_OPERATION_MODE << 6) | (AFC_RANGE_LIMITS << 4) | (ENABLE_AFC_HIGH_ACCURACY_MODE << 2) | (ENABLE_FREQUENCY_OFFSET_REGISTER << 1) | (ENABLE_OFFSET_FREQUENCY_CALCULATION)

; 11. TX Configuration Control Command
.equ TX_CONFIG_CONTROL_CMD = (0b1001100 << 9) | (FSCK_MOD_SIGN << 8) | (FSCK_MOD_PARAMETER << 4) | (0 << 3) | OUTPUT_POWER

; 12. PLL Setting Command
; note: The data sheet's given hex POR value disagrees with the bit
; diagram for value of reserved bits. POR values used here.
.equ PLL_SETTING_CMD = 0b1100110000000010 | (UC_CLK_FREQUENCY << 5) | (ENABLE_PLL_DETECTOR_DELAY << 3) | (DISABLE_PLL_DITHERING << 2) | PLL_BANDWIDTH

; 13. Transmitter Register Write Command
; to write a byte to TX register, write (TXREG_WRITE_CMD | byte).
.equ TXREG_WRITE_CMD = 0b1011100000000000

; 14. Wake-Up Timer Command
.equ WAKE_UP_TIMER_CMD = (0b111 << 13) | (WAKE_UP_TIMER_R << 8) | (WAKE_UP_TIMER_M)

; 15. Low Duty Cycle Command
.equ LOW_DUTY_CYCLE_CMD = (0b11001000 << 8) | (DUTY_CYCLE_PARAM << 1) | ENABLE_LOW_DUTY_CYCLE_MODE

; 16. Low Battery Detector and Microcontroller Clock Divider Command
.equ LOW_BATTERY_DETECTOR_CMD = (0b11000000 << 8) | (EXT_CLOCK_FREQUENCY << 5) | LOW_BATTERY_THRESHOLD_VOLTAGE

; 17. Status Read Command
; This command starts with a zero, wehreas all other commands start with a 1.
; As soon as the 0 is received, all 19 status bits may be read out.
.equ STATUS_READ_CMD = 0

; additional values:
.equ PREAMBLE_BYTE = 0xAA ; used for TX register addressing.

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; SPI macros
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; 
; ia_write_spi - write an 8-bit immediate value to radio.
; Argument: immediate value to send
;
.macro ia_write_spi
   ldi spi_byte, @0
   rcall ia_write_spi
.endmacro

;
; ia_write_spi_r - write an 8-bit register value to radio.
; Argument: the register to send.
;
.macro ia_write_spi_r
   mov spi_byte, @0
   rcall ia_write_spi
.endmacro

;
; ia_send_cmd - Send a 16-bit command to the radio.
; Argument: 16-bit immediate value to send.
.macro ia_send_cmd
   IA_NSEL_ACTIVE
   ia_write_spi high(@0)
   ia_write_spi low(@0)
   IA_NSEL_INACTIVE
.endmacro
;
; ia_send_cmd_r - Send 16-bit command defined by two given registers to radio.
; Argument: @0, @1 - 16-bit value to send, MSB first.
.macro ia_send_cmd_r
   ia_write_spi_r @0
   ia_write_spi_r @1
.endmacro

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Transceiver status
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Turn transmitter and receiver off.
.macro transmitter_and_receiver_off
   ia_send_cmd TX_AND_RX_DISABLE_CMD
.endmacro
; turn on transmitter
.macro transmitter_on
   ia_send_cmd TX_ENABLE_RX_DISABLE_CMD
.endmacro
; Turn off transmitter, turn on receiver
.macro transmitter_off_receiver_on
   ia_send_cmd TX_DISABLE_RX_ENABLE_CMD
.endmacro


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; TX/RX register control
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; write an 8-bit immediate value to radio's TX register.
; Argument: immediate value to send.
.macro ia_send_tx_reg
   IA_NSEL_ACTIVE
   rcall loop_until_tx_reg_ready
   ia_write_spi high(TXREG_WRITE_CMD)
   ia_write_spi @0
   IA_NSEL_INACTIVE
.endmacro

;
; send_tx_reg_r - write an 8-bit register to the radio's TX register.
;
; Argument:  register to send.
;
.macro ia_send_tx_reg_r
   IA_NSEL_ACTIVE
   rcall loop_until_tx_reg_ready
   ia_write_spi high(TXREG_WRITE_CMD)
   ia_write_spi_r @0
   IA_NSEL_INACTIVE
.endmacro

.macro ia_fifo_receive
   IA_NSEL_ACTIVE
   ia_write_spi high(RECEIVER_FIFO_READ_CMD)
   rcall ia_read_spi
   IA_NSEL_INACTIVE
.endmacro

.macro ia_read_fifo
   rcall ia_wait_until_fifo_ready
   ia_fifo_receive
.endmacro

.macro open_read_status_register
   IA_SCK_LO
   IA_MOSI_LO
   IA_NSEL_ACTIVE
.endmacro
.macro close_read_status_register
   IA_NSEL_INACTIVE
.endmacro

; Enable transmit register for FIFO sending.
.macro enable_tx_register
   ia_send_cmd TX_REGISTER_ENABLE_CMD
.endmacro

; disable transmit register (for receiving or non-FIFO sending).
.macro disable_tx_register
   ia_send_cmd TX_REGISTER_DISABLE_CMD
.endmacro

; Send commands to stop filling FIFO buffer and wait for synchron bytes.
.macro reset_fifo_synchron_latch
   ia_send_cmd STOP_FIFO_BUFFER_FILL_CMD
   ia_send_cmd ENABLE_FIFO_BUFFER_FILL_CMD
.endmacro

; send preamble and synchron bytes.
; Only used when using TX register.
.macro send_preamble
   ia_send_tx_reg PREAMBLE_BYTE ; preamble
   ia_send_tx_reg SYNCHRON_PATTERN_MSBYTE ; synch byte 1
   ia_send_tx_reg SYNCHRON_PATTERN_LSBYTE ; synch byte 2
.endmacro

; Enable tx register, fill preamble, and turn on transmitter.
; Only used when using TX register.
.macro transmitter_startup_sequence
   transmitter_and_receiver_off
   enable_tx_register
   ; we don't use ia_send_tx_reg here because 
   ; we don't want to wait for ready bit.
   ia_send_cmd (TXREG_WRITE_CMD | PREAMBLE_BYTE) ; fill tx register with preamble 
   ia_send_cmd (TXREG_WRITE_CMD | PREAMBLE_BYTE) ; "
   transmitter_on
.endmacro

; push through last two tx register bytes (call before disabling transmitter
; when using tx register)
.macro flush_send_buffer
   ia_send_tx_reg PREAMBLE_BYTE ; don't care
   ia_send_tx_reg PREAMBLE_BYTE ; don't care
.endmacro

; Flush bytes, then turn off transmitter and disable tx register.
.macro transmitter_shutdown_sequence
   flush_send_buffer
   transmitter_off_receiver_on
   disable_tx_register
.endmacro

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; initialization
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.macro initialize_IA4421
   ia_init_pins
   rcall delay_100ms ; wait for IA4421 POR (power on reset)

   ia_send_cmd CONFIGURATION_SETTING_CMD
   ia_send_cmd POWER_MANAGEMENT_CMD
   ia_send_cmd FREQUENCY_SETTING_CMD
   ia_send_cmd DATA_RATE_CMD
   ia_send_cmd RECEIVER_CONTROL_CMD
   ia_send_cmd DATA_FILTER_CMD
   ia_send_cmd FIFO_AND_RESET_MODE_CMD
   ia_send_cmd SYNCHRON_PATTERN_CMD
   ia_send_cmd AFC_CMD
   ia_send_cmd TX_CONFIG_CONTROL_CMD
   ia_send_cmd PLL_SETTING_CMD
   ia_send_cmd WAKE_UP_TIMER_CMD
   ia_send_cmd LOW_BATTERY_DETECTOR_CMD
   reset_fifo_synchron_latch

   transmitter_on
   ; 5ms delay for antenna tuning
   rcall delay_5ms
   ; default to receive mode.
   transmitter_off_receiver_on
.endmacro

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; SPI routines
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; clobbers: temp, spi_byte
ia_read_spi:
   IA_MOSI_LO
   IA_SCK_LO
   ldi temp, 8
   read_spi_loop:
      lsl spi_byte ; put 0 in least significant bit
      skip_if_ia_miso_high
         rjmp read_spi_ia_toggle_sck
      ; bit high
      read_spi_miso_hi:
         sbr spi_byte, 0b00000001
         rjmp read_spi_ia_toggle_sck
      ; toggle sck
      read_spi_ia_toggle_sck:
         ia_toggle_sck
         dec temp
         brne read_spi_loop
   ret

; clobbers: temp, spi_byte
ia_write_spi:
   IA_MOSI_LO
   IA_SCK_LO
   ldi temp, 8
   write_spi_loop:
      lsl spi_byte ; put most significant bit in carry.
      brcc write_spi_bit_low 
      ; if bit is high:
         nop
         IA_MOSI_HI
         rjmp write_spi_ia_toggle_sck
      write_spi_bit_low:
      ; else (bit is low):
         IA_MOSI_LO;
         rjmp write_spi_ia_toggle_sck
      write_spi_ia_toggle_sck:
         ia_toggle_sck
         dec temp
         brne write_spi_loop
   IA_MOSI_LO
   ret

; Wait until a byte is ready in the FIFO register,
; then receive it.
ia_wait_until_fifo_ready:
   ; start status register read.
   IA_SCK_LO
   IA_NSEL_ACTIVE
   ; command (just a 0)
   IA_MOSI_LO
   ;rcall delay_1us ; undocumented delay, necessary for early IA4421's (but not
                    ; RFM-branded modules)
   skip_if_ia_miso_high
      rjmp ia_wait_until_fifo_ready_clear_latches
   ; byte ready!
   IA_NSEL_INACTIVE
   ret
   
   ia_wait_until_fifo_ready_clear_latches:
      rcall ia_clear_it_latches ; (Also deactivates NSEL)
      rjmp ia_wait_until_fifo_ready

ia_clear_it_latches:
   IA_SCK_LO
   IA_NSEL_ACTIVE
   IA_MOSI_LO
   ; (ffit/rgit)
   ia_toggle_sck ; por
   ia_toggle_sck ; ffof/rgur
   ia_toggle_sck ; wkup
   ia_toggle_sck ; ext
   ia_toggle_sck ; lbd
   ia_toggle_sck ; reset's IT latches
   IA_NSEL_INACTIVE
   ret

; blocks until TX reg is ready, assuming NSEL is active and transmitter is on.
loop_until_tx_reg_ready:
    skip_if_ia_miso_high
        rjmp loop_until_tx_reg_ready
    ret

