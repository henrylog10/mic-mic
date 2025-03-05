.include "m328Pdef.inc"

; Defini��es de constantes
.equ F_CPU = 16000000            ; Frequ�ncia do clock do microcontrolador (16 MHz)
.equ BAUD = 4800                 ; Taxa de comunica��o UART (4800 bps)
.equ UBRR_VALUE = ((F_CPU / (16 * BAUD)) - 1) ; Valor para configurar o baud rate

.org 0x00
    rjmp main                     ; Vetor de reset (in�cio do programa)
.org 0x24
    rjmp usart_rx_isr              ; Vetor da interrup��o UART RX (recebimento de dados)

hex_table:
    .db 0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07
    .db 0x7F, 0x6F, 0x77, 0x7C, 0x39, 0x5E, 0x79, 0x71 ; Valores para "0123456789ABCDEF"
invalid:
    .db 0x40                      ; C�digo para exibir um tra�o "-" no display

name:
    .db "JOSE HENRIQUE B PENA", 0 ; Nome a ser enviado pela UART ao pressionar o bot�o

main:
    ; Configura��o do UART (4800 bps)
    ldi R16, high(UBRR_VALUE)      ; Carrega o byte mais significativo de UBRR
    sts UBRR0H, R16                ; Configura UBRR0H
    ldi R16, low(UBRR_VALUE)       ; Carrega o byte menos significativo de UBRR
    sts UBRR0L, R16                ; Configura UBRR0L

    ; Habilita TX, RX e interrup��o de RX
    ldi R16, (1 << RXEN0) | (1 << TXEN0) | (1 << RXCIE0)
    sts UCSR0B, R16                ; Configura UCSR0B

    ; Configura o formato do frame: 8 bits de dados, 1 bit de parada
    ldi R16, (1 << UCSZ01) | (1 << UCSZ00)
    sts UCSR0C, R16                ; Configura UCSR0C

    ; Configura PORTB como sa�da (conectado ao display de 7 segmentos)
    ldi R16, 0xFF
    out DDRB, R16                  ; Define todos os pinos do PORTB como sa�da

    ; Configura PD2 como entrada (bot�o) e habilita resistor de pull-up
    cbi DDRD, PD2                  ; Define PD2 como entrada
    sbi PORTD, PD2                 ; Habilita resistor de pull-up em PD2

    sei                             ; Habilita interrup��es globais

loop:
    ; Verifica se o bot�o foi pressionado (n�vel baixo em PD2)
    sbic PIND, PD2                  ; Pula a pr�xima instru��o se PD2 estiver em n�vel alto
    rjmp loop                       ; Se n�o estiver pressionado, volta ao in�cio do loop

    ; Debounce: espera 50 ms
    rcall delay_50ms

    ; Confirma a press�o do bot�o
    sbic PIND, PD2                  ; Pula a pr�xima instru��o se PD2 estiver em n�vel alto
    rjmp loop                       ; Se n�o estiver pressionado, volta ao in�cio do loop

    ; Envia o nome pela UART
    rcall send_button_message

    ; Espera o bot�o ser solto
wait_for_release:
    sbis PIND, PD2                  ; Pula a pr�xima instru��o se PD2 estiver em n�vel alto
    rjmp wait_for_release           ; Repete at� que o bot�o seja solto

    rjmp loop                       ; Volta ao in�cio do loop

usart_rx_isr:
    lds R16, UDR0                   ; L� o byte recebido da UART
    cpi R16, '0'                    ; Verifica se o caractere � menor que '0'
    brlt invalid_char                ; Se for, trata como caractere inv�lido
    cpi R16, '9' + 1                ; Verifica se o caractere � maior que '9'
    brlt hex_number                  ; Se for um n�mero, converte para valor hexadecimal
    cpi R16, 'A'                    ; Verifica se o caractere � menor que 'A'
    brlt invalid_char                ; Se for, trata como caractere inv�lido
    cpi R16, 'F' + 1                ; Verifica se o caractere � maior que 'F'
    brge invalid_char                ; Se for, trata como caractere inv�lido
    subi R16, 'A' - 10              ; Converte 'A'-'F' para 10-15
    rjmp display_char               ; Exibe o valor no display

hex_number:
    subi R16, '0'                   ; Converte '0'-'9' para 0-9

display_char:
    ldi ZL, low(hex_table*2)        ; Carrega o endere�o da tabela no registrador Z
    ldi ZH, high(hex_table*2)
    add ZL, R16                     ; Adiciona o valor ao endere�o da tabela
    adc ZH, R0                      ; Adiciona o carry ao byte superior
    lpm R16, Z                      ; L� o valor correspondente na tabela
    out PORTB, R16                  ; Atualiza o display de 7 segmentos
    reti                            ; Retorna da interrup��o

invalid_char:
    ldi ZL, low(invalid*2)          ; Carrega o endere�o do caractere inv�lido (tra�o "-")
    ldi ZH, high(invalid*2)
    lpm R16, Z                      ; L� o valor correspondente na tabela
    out PORTB, R16                  ; Exibe o tra�o no display
    rjmp loop                       ; Retorna da interrup��o

send_button_message:
    ; Inicializa o ponteiro Z para a string "JOSE HENRIQUE B PENA"
    ldi ZL, LOW(name*2)             ; Carrega o byte inferior do endere�o da string
    ldi ZH, HIGH(name*2)            ; Carrega o byte superior do endere�o da string

send_name:
    lpm R16, Z+                     ; L� o pr�ximo caractere da string
    cpi R16, 0                      ; Verifica se � o fim da string (caractere nulo)
    breq end_send                   ; Se for, encerra o envio
    rcall uart_send                 ; Envia o caractere pela UART
    rjmp send_name                  ; Repete para o pr�ximo caractere

end_send:
    ret                             ; Retorna da fun��o

uart_send:
    lds R17, UCSR0A                 ; L� o registrador de status da UART
    sbrs R17, UDRE0                 ; Pula a pr�xima instru��o se o buffer de transmiss�o estiver vazio
    rjmp uart_send                  ; Repete at� que o buffer esteja pronto
    sts UDR0, R16                   ; Envia o caractere pela UART
    ret                             ; Retorna da fun��o

delay_50ms:
    ldi R21, 200                    ; Configura o contador externo para ~50 ms
delay_outer:
    ldi R22, 250                    ; Configura o contador interno
delay_inner:
    dec R22                         ; Decrementa o contador interno
    brne delay_inner                ; Repete at� que o contador interno chegue a zero
    dec R21                         ; Decrementa o contador externo
    brne delay_outer                ; Repete at� que o contador externo chegue a zero
    ret                             ; Retorna da fun��o
