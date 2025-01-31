delay_1us: ; 8 cycles at 8000000Hz
    nop
    ret
    
delay_97us: ; 777 cycles at 8000000Hz
    push temp
    ldi temp, 255
    delay_97us_loop:
        dec temp
        brne delay_97us_loop
    nop ; even out final brne time
    pop temp
    ret
delay_26us: ; 208 cycles at 8000000Hz
    push temp
    ldi temp, 65
    delay_26us_loop:
        dec temp
        brne delay_26us_loop
    nop ; even out final brne time
    pop temp
    nop
    ret
delay_5ms: ; 40000 cycles at 8000000Hz
    push temp
    ldi temp, 51
    delay_5ms_loop:
        rcall delay_97us
        dec temp
        brne delay_5ms_loop
    nop ; even out final brne time
    pop temp 
    rcall delay_26us
    ret

delay_100ms: ; approximate 100ms delay (errs high)
    push temp
    ldi temp, 20
    delay_100ms_loop:
        rcall delay_5ms
        dec temp
        brne delay_100ms_loop
    pop temp
    ret
