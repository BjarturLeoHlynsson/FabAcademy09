;
; IA4421_config.asm - annotated configuration directives for the IA4421
; By Charlie DeTar, 2008
;
;
; The IA4421 has 17 configuration directives which are used for both initial
; setup and run-time control (e.g. turning on/off the transmitter and receiver).
; This file abstracts those directives into their component parts, allowing
; you to slightly more intelligibly configure the chip.
;
; Include this file first, and then include "IA4421_code.asm".  Call the 
; "initialize_IA4421" macro to assemble load the configuration into the IA4421.
;
; For example:
;
;     ;; asm file suing IA4421
;     .cseg
;     .org 0
;     rjmp reset
;     .include "IA4421_config.asm"
;     .include "IA4421_code.asm"
;     ...
;     reset:
;         ...
;         initialize_IA4421
;         ...

; In the interests of code reuse, it is recommended to change values given here
; by "subclassing" this file rather than overwriting it.  Simply creating a new 
; file, ".include" this one, and use ".set" directives to override definitions.  
; For example:
;
;    ;;  IA4421_i0_config.asm - configuration for I0
;    .include "IA4421_config.asm"
;    .set FIFO_MODE_ENABLE = 0 ; no FIFO register
;    .set DATA_FILTER_TYPE = 1 ; Analog filter


;
; Sketchy explanations of the directives are given here; for details see the
; data sheet.  The most important directives you will probably need to change 
; are:
; 
;   Configuration Setting Command (base freq, crystal capacitance, 
;                                  FIFO/data register enable)
;   Data Rate command
;   Receiver Command (gain, baseband bandwidth)
;   TX Configuration Control Command (output power)
;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; 1. Configuration Setting Command

;.set FREQUENCY_BAND = 0b01 ; 433MHz
;.set FREQUENCY_BAND = 0b10 ; 868MHz
.set FREQUENCY_BAND = 0b11 ; 915MHz

.set ENABLE_DATA_REGISTER = 0 ; 
.set FIFO_MODE_ENABLE = 1;

; Crystal Load Capacitance
;.set CRYSTAL_LOAD_CAPACITANCE = 0b0000; 8.5pF
;.set CRYSTAL_LOAD_CAPACITANCE = 0b0001; 9.0pF
;.set CRYSTAL_LOAD_CAPACITANCE = 0b0010; 9.5pF
; ...
.set CRYSTAL_LOAD_CAPACITANCE = 0b0111; 12.0pF
; ...
; .set CRYSTAL_LOAD_CAPACITANCE = 0b1110; 15.5pF
; .set CRYSTAL_LOAD_CAPACITANCE = 0b1111; 16.0pF

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; 2. Power Management Command defaults

.set ENABLE_WHOLE_RECEIVER_CHAIN = 0
.set ENABLE_RECEIVER_BASEBAND_CIRCUIT = 0
.set ENABLE_TRANSMITTER_CIRCUIT = 0
.set ENABLE_SYNTHESIZER = 0
.set ENABLE_CRYSTAL_OSCILLATOR = 0
.set ENABLE_LOW_BATTERY_DETECTOR = 0
.set ENABLE_WAKEUP_TIMER = 0
.set DISABLE_CLOCK_OUTPUT = 1

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; 3. Frequency Setting Command

; This command fine-tunes the frequency or "channel" used within the band 
; given in the "Configuration Setting Command".  
;
; The frequency is defined by the following equation:
; 
; f = 10 * C1 * (C2 + F / 4000)
; 
; where F is the parameter given below, and C1/C2 are constants defined by
; frequency band chosen in the Configuration Setting Command:
;   Band    C1  C2
;    433     1  43
;    868     2  43
;    915     3  30
;
.set F_PARAMETER = 2000 ; 12-bit value

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; 4. Data Rate Command

; The bit rate is given by the following equation, given the parameter
; DATA_RATE_CS and DATA_RATE_R below:
;
; BR = 10000 / 29 / (DATA_RATE_R + 1) / (1 + DATA_RATE_CS * 7)

.set DATA_RATE_CS = 0
;.set DATA_RATE_R = 35 ; ~9600 Baud (with DATA_RATE_CS = 0)
;.set DATA_RATE_R = 10 ; ~31K Baud (with DATA_RATE_CS = 0)
.set DATA_RATE_R = 5 ; ~56K Baud (with DATA_RATE_CS = 0)
;.set DATA_RATE_R = 4 ; ~68K Baud (with DATA_RATE_CS = 0)
;.set DATA_RATE_R = 3 ; ~86K Baud (with DATA_RATE_CS = 0)
;.set DATA_RATE_R = 2 ; ~115K Baud (with DATA_RATE_CS = 0)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; 5. Receiver Control Command

;.set PIN_16_FUNCTION = 0 ; Interrupt input
.set PIN_16_FUNCTION = 1 ; VDI (Valid Data Indicator) output

.set VDI_RESPONSE_TIME = 0b00 ; Fast 
;.set VDI_RESPONSE_TIME = 0b01 ; Medium
;.set VDI_RESPONSE_TIME = 0b10 ; Slow
;.set VDI_RESPONSE_TIME = 0b00 ; Always on

;.set RECEIVER_BASEBAND_BANDWIDTH = 0b001 ; 400kHz
;.set RECEIVER_BASEBAND_BANDWIDTH = 0b010 ; 340kHz
;.set RECEIVER_BASEBAND_BANDWIDTH = 0b011 ; 270kHz
.set RECEIVER_BASEBAND_BANDWIDTH = 0b100 ; 200kHz
;.set RECEIVER_BASEBAND_BANDWIDTH = 0b101 ; 134kHz
;.set RECEIVER_BASEBAND_BANDWIDTH = 0b110 ;  67kHz

.set RECEIVER_LNA_GAIN = 0b00 ; 0dB
;.set RECEIVER_LNA_GAIN = 0b01 ; -6dB
;.set RECEIVER_LNA_GAIN = 0b10 ; -14dB
;.set RECEIVER_LNA_GAIN = 0b11 ; -20dB

; Receiver Signal Strength Indicator:
; RSSI threshold depends on LNA gain.  The real threshold can be calculated as:
;
;    RSSI = RSSI_DETECTOR_THRESHOLD + LNA_GAIN
;

;.set RSSI_DETECTOR_THRESHOLD = 0b000 ; -103dBm
;.set RSSI_DETECTOR_THRESHOLD = 0b001 ; -97dbm
;.set RSSI_DETECTOR_THRESHOLD = 0b010 ; -91dBm
.set RSSI_DETECTOR_THRESHOLD = 0b011 ; -85dBm
;.set RSSI_DETECTOR_THRESHOLD = 0b100 ; -79dBm
;.set RSSI_DETECTOR_THRESHOLD = 0b101 ; -73dBm

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; 6. Data Filter Command

.set CLOCK_RECOVERY_LOCK_AUTO_MODE = 0 ; CR will start in fast mode, 
                                       ; then after locking, switch 
                                       ; to slow mode

;.set CLOCK_RECOVERY_LOCK_CONTROL = 1 ; fast mode
.set CLOCK_RECOVERY_LOCK_CONTROL = 0 ; slow mode

.set DATA_FILTER_TYPE = 0 ; Digital filter
;.set DATA_FILTER_TYPE = 1 ; Analog filter

; 3-bit number indicating threshold for data quality detector
; (read out in status register)
.set DATA_QUALITY_DETECTOR_THRESHOLD = 0b010 ; medium

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; 7. FIFO and Reset Mode Command

.set FIFO_IT_LEVEL = 8 ; FIFO generates an interrupt when this many 
                       ; bits have been received (max 15)

.set SYNCHRON_PATTERN_LENGTH = 0 ; 16 bits 
;.set SYNCHRON_PATTERN_LENGTH = 1 ; 8 bits 

.set FIFO_START_CONDITION = 0 ; Start filling FIFO if synchron pattern is detected
;.set FIFO_START_CONDITION = 1 ; Always fill FIFO (ignore synchron pattern)

;.set RESET_MODE_SENSITIVITY = 0 ; Reset when Vdd goes below 1.5V or glitches greater than 500mV
.set RESET_MODE_SENSITIVITY = 1 ; Reset when Vdd goes below 0.25V

.set ENABLE_FIFO_BUFFER_FILL = 1 ; 

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; 8.  Synchron Pattern Command

; This command sets the least significant byte of the synchron pattern, which
; is used to identify the start of valid data when using the FIFO buffer (see
; FIFO and Reset Mode Command for control over synchron pattern length and fifo
; start condition).

; The most significant byte of the synchron pattern, if 2 bytes are used, is 0x2D.
.equ SYNCHRON_PATTERN_MSBYTE = 0x2D ; don't change this; 0x2D is required.
; Least significant byte (for 1 or 2 byte synchron patterns):
.set SYNCHRON_PATTERN_LSBYTE = 0xD4 ; you may change this; default 0xD4


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; 9.  Receiver FIFO Read Command

; no configurable parts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; 10.  Automatic Frequency Correction Command

;.set AFC_OPERATION_MODE = 0b00 ; Auto mode off
;.set AFC_OPERATION_MODE = 0b01 ; Runs only once after each power-up
;.set AFC_OPERATION_MODE = 0b10 ; Keep the f-offset only during receiving, and Valid Data Indicator is high.
.set AFC_OPERATION_MODE = 0b11 ; Keep the f-offset independently of VDI.

; for the AFC range limits, the constant "Fres" is defined by the 
; base frequency band:
;  base frequency     Fres
;            415      2.5kHz
;            868      5kHz
;            915      7.5kHz
;.set AFC_RANGE_LIMITS = 0b00 ; no restriction
;.set AFC_RANGE_LIMITS = 0b01 ; +15 * Fres to to -16 * fres
;.set AFC_RANGE_LIMITS = 0b10 ; +7 * Fres to -8 * fres
.set AFC_RANGE_LIMITS = 0b11 ; +3 * Fres to -4 * fres

; see data sheet for lengthy explanation of these parameters
.set ENABLE_AFC_HIGH_ACCURACY_MODE = 1
.set ENABLE_FREQUENCY_OFFSET_REGISTER = 1
.set ENABLE_OFFSET_FREQUENCY_CALCULATION = 1

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; 11. TX Configuration Control Command 

; The FSK Output Frequency is defined by the following equation:
;
;  fout = f0 + (-1)^FSK_MOD_SIGN * (FSK_MOD_PARAMETER + 1) * 15Khz
;
; where f0 is the base frequency (433, 856, 915) and FSK_MOD_SIGN and
; FSK_MOD_PARAMETER are the values below.

.set FSCK_MOD_SIGN = 0 ; 0 => 1, 1 => -1
.set FSCK_MOD_PARAMETER = 0b0101 ; 4-bit number

.set OUTPUT_POWER = 0b000 ; 0dB
;.set OUTPUT_POWER = 0b001 ; -2.5db
;.set OUTPUT_POWER = 0b010 ; -5db
;.set OUTPUT_POWER = 0b011 ; -7.5db
;.set OUTPUT_POWER = 0b100 ; -10db
;.set OUTPUT_POWER = 0b101 ; -12.5db
;.set OUTPUT_POWER = 0b110 ; -15db
;.set OUTPUT_POWER = 0b111 ; -17.5db

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; 12. PLL Setting Command

;.set UC_CLK_FREQUENCY = 0b00 ; 5 or 10MHz
;.set UC_CLK_FREQUENCY = 0b01 ; 3.3MHz
.set UC_CLK_FREQUENCY = 0b11 ; 2.5MHz or less

.set ENABLE_PLL_DETECTOR_DELAY = 0
.set DISABLE_PLL_DITHERING = 1
;.set PLL_BANDWIDTH = 0 ; 86.2kbps, -107dBc/Hz noise at 1Mhz offset
.set PLL_BANDWIDTH = 1 ; 256kbps, -102dBc/Hz noise at 1Mhz offset

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; 13. Transmitter Register Write Command

; no configurable parts

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; 14. Wake-Up Timer Command

; The wake-up time period is calculated using two values WAKE_UP_TIMER_M and
; WAKE_UP_TIMER_R using the following equation:
;
;   Twakeup (ms) = 1.03 * WAKE_UP_TIMER_M * 2^WAKE_UP_TIMER_R + 0.5 

.set WAKE_UP_TIMER_R = 0b00001 ; 5 bit value
.set WAKE_UP_TIMER_M = 0b10010110 ; 8 bit value

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; 15. Low Duty-Cycle Command

; this command sets up a low duty-cycle receiver mode in which the chip sleeps
; for a majority of the time and wakes up periodically to listen for
; transmissions.
; The duty-cycle is calculated using the following equation:
;
;   Duty-cycle = (D * 2 + 1) / DUTY_CYCLE_PARAM * 100%

.set DUTY_CYCLE_PARAM = 0b0000111 ; 7-bit value
.set ENABLE_LOW_DUTY_CYCLE_MODE = 0 ; 

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; 16. Low Battery Detector and Microcontroller Clock Divider Command

; divider for provided external clock pin 
; (if enabled in Power Management Command)
.set EXT_CLOCK_FREQUENCY = 0b000 ; 1MHz
;.set EXT_CLOCK_FREQUENCY = 0b001 ; 1.25MHz
;.set EXT_CLOCK_FREQUENCY = 0b010 ; 1.66MHz
;.set EXT_CLOCK_FREQUENCY = 0b011 ; 2MHz
;.set EXT_CLOCK_FREQUENCY = 0b100 ; 2.5MHz
;.set EXT_CLOCK_FREQUENCY = 0b101 ; 3.33MHz
;.set EXT_CLOCK_FREQUENCY = 0b110 ; 5MHz
;.set EXT_CLOCK_FREQUENCY = 0b111 ; 10MHz

; The low battery threshold is defined by the following equation:
;
;  Vthresh = 2.25 + LOW_BATTERY_THRESHOLD_VOLTAGE * 0.1
;
.set LOW_BATTERY_THRESHOLD_VOLTAGE = 0b0000 ; 4-bit value

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; 17.  Status Read Command

; This command starts with a zero, whereas all other commands start with a 1.
; As soon as the 0 is received, all 19 status bits may be read out.

; no configurable parts
