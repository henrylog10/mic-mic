; Definições do microcontrolador
.include "m328pdef.inc"

; Constantes
.equ F_CPU = 16000000      ; Frequência do clock
.equ BAUD = 4800           ; Taxa de transmissão UART
.equ UBRR_VAL = (F_CPU/(16*BAUD)-1) ; Cálculo do UBRR

; Registradores auxiliares
.def temp = r16            ; Registrador temporário
.def hex_val = r17         ; Valor hexadecimal convertido
.def seg_code = r18        ; Código do segmento
.def tx_flag = r19         ; Flag de transmissão

; Tabela de segmentos (0-F e '-')
seg_table:
.db 0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07, 0x7F, 0x6F, 0x77, 0x7C, 0x39, 0x5E, 0x79, 0x71, 0x40

; String do nome (José Henrique Barbosa Pena)
name_string:
.db 'J','o','s',0xE9,' ','H','e','n','r','i','q','u','e',' ','B','a','r','b','o','s','a',' ','P','e','n','a',0

; Vetores de interrupção
.cseg
.org 0x0000
    rjmp main              ; Reset
.org URXCaddr             ; Endereço da interrupção UART RX
    rjmp uart_rx_isr
.org INT0addr             ; Endereço da interrupção INT0 (botão)
    rjmp button_isr

; Programa principal
main:
    ; Inicializa stack pointer
    ldi temp, HIGH(RAMEND)
    out SPH, temp
    ldi temp, LOW(RAMEND)
    out SPL, temp

    ; Configura UART
    ldi temp, HIGH(UBRR_VAL)
    sts UBRR0H, temp
    ldi temp, LOW(UBRR_VAL)
    sts UBRR0L, temp
    ldi temp, (1<<RXEN0)|(1<<TXEN0)|(1<<RXCIE0) ; Habilita RX, TX e interrupção
    sts UCSR0B, temp
    ldi temp, (1<<UCSZ01)|(1<<UCSZ00)           ; Modo 8N1
    sts UCSR0C, temp

    ; Configura PortD como saída (display 7 segmentos)
    ldi temp, 0xFF
    out DDRD, temp

    ; Configura botão em PD2 (INT0) com pull-up
    cbi DDRD, 2
    sbi PORTD, 2
    ldi temp, (1<<ISC01)                        ; Borda de descida
    sts EICRA, temp
    ldi temp, (1<<INT0)                         ; Habilita INT0
    out EIMSK, temp

    sei                     ; Habilita interrupções globais
    clr tx_flag             ; Inicializa flag de transmissão

loop:
    cpi tx_flag, 1          ; Verifica se o botão foi pressionado
    brne loop
    rcall send_name         ; Envia o nome
    clr tx_flag             ; Limpa a flag
    rjmp loop

; Envia o nome pela UART
send_name:
    ldi ZL, LOW(name_string<<1)
    ldi ZH, HIGH(name_string<<1)
send_loop:
    lpm temp, Z+           ; Carrega caractere
    cpi temp, 0            ; Verifica fim da string
    breq send_end
wait_tx:
    lds r20, UCSR0A        ; Espera UDR0 estar vazio
    sbrs r20, UDRE0
    rjmp wait_tx
    sts UDR0, temp         ; Envia caractere
    rjmp send_loop
send_end:
    ret

; Interrupção UART RX
uart_rx_isr:
    push temp
    push hex_val
    push seg_code
    push ZL
    push ZH
    in temp, SREG
    push temp

    lds temp, UDR0         ; Lê dado recebido

    ; Verifica se é '0'-'9'
    cpi temp, '0'
    brlo invalid
    cpi temp, '9'+1
    brlo digit

    ; Verifica 'A'-'F'
    cpi temp, 'A'
    brlo invalid
    cpi temp, 'F'+1
    brlo upper_hex

    ; Verifica 'a'-'f'
    cpi temp, 'a'
    brlo invalid
    cpi temp, 'f'+1
    brsh invalid
    subi temp, 0x20        ; Converte para maiúscula

upper_hex:
    subi temp, 0x37        ; Converte para 0x0A-0x0F
    rjmp convert

digit:
    subi temp, '0'         ; Converte para 0x00-0x09

convert:
    mov hex_val, temp
    ldi ZL, LOW(seg_table<<1)
    ldi ZH, HIGH(seg_table<<1)
    add ZL, hex_val        ; Ajusta ponteiro
    clr temp
    adc ZH, temp
    lpm seg_code, Z        ; Carrega código do segmento
    out PORTD, seg_code    ; Atualiza display
    rjmp end_isr

invalid:
    ldi seg_code, 0x40     ; Código para '-'
    out PORTD, seg_code

end_isr:
    pop temp
    out SREG, temp
    pop ZH
    pop ZL
    pop seg_code
    pop hex_val
    pop temp
    reti

; Interrupção do botão
button_isr:
    push temp
    in temp, SREG
    push temp

    ldi tx_flag, 1         ; Ativa flag de transmissão

    pop temp
    out SREG, temp
    pop temp
    reti