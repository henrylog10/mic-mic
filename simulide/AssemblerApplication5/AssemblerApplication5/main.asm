.include "m328Pdef.inc"

; Definições de constantes
.equ F_CPU = 16000000            ; Frequência do clock do microcontrolador (16 MHz)
.equ BAUD = 4800                 ; Taxa de comunicação UART (4800 bps)
.equ UBRR_VALUE = ((F_CPU / (16 * BAUD)) - 1) ; Valor para configurar o baud rate

.org 0x00
    rjmp main                     ; Vetor de reset (início do programa)
.org 0x24
    rjmp usart_rx_isr              ; Vetor da interrupção UART RX (recebimento de dados)

hex_table:
    .db 0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07
    .db 0x7F, 0x6F, 0x77, 0x7C, 0x39, 0x5E, 0x79, 0x71 ; Valores para "0123456789ABCDEF"
invalid:
    .db 0x40                      ; Código para exibir um traço "-" no display

name:
    .db "JOSE HENRIQUE B PENA", 0 ; Nome a ser enviado pela UART ao pressionar o botão

main:
    ; Configuração do UART (4800 bps)
    ldi R16, high(UBRR_VALUE)      ; Carrega o byte mais significativo de UBRR
    sts UBRR0H, R16                ; Configura UBRR0H
    ldi R16, low(UBRR_VALUE)       ; Carrega o byte menos significativo de UBRR
    sts UBRR0L, R16                ; Configura UBRR0L

    ; Habilita TX, RX e interrupção de RX
    ldi R16, (1 << RXEN0) | (1 << TXEN0) | (1 << RXCIE0)
    sts UCSR0B, R16                ; Configura UCSR0B

    ; Configura o formato do frame: 8 bits de dados, 1 bit de parada
    ldi R16, (1 << UCSZ01) | (1 << UCSZ00)
    sts UCSR0C, R16                ; Configura UCSR0C

    ; Configura PORTB como saída (conectado ao display de 7 segmentos)
    ldi R16, 0xFF
    out DDRB, R16                  ; Define todos os pinos do PORTB como saída

    ; Configura PD2 como entrada (botão) e habilita resistor de pull-up
    cbi DDRD, PD2                  ; Define PD2 como entrada
    sbi PORTD, PD2                 ; Habilita resistor de pull-up em PD2

    sei                             ; Habilita interrupções globais

loop:
    ; Verifica se o botão foi pressionado (nível baixo em PD2)
    sbic PIND, PD2                  ; Pula a próxima instrução se PD2 estiver em nível alto
    rjmp loop                       ; Se não estiver pressionado, volta ao início do loop

    ; Debounce: espera 50 ms
    rcall delay_50ms

    ; Confirma a pressão do botão
    sbic PIND, PD2                  ; Pula a próxima instrução se PD2 estiver em nível alto
    rjmp loop                       ; Se não estiver pressionado, volta ao início do loop

    ; Envia o nome pela UART
    rcall send_button_message

    ; Espera o botão ser solto
wait_for_release:
    sbis PIND, PD2                  ; Pula a próxima instrução se PD2 estiver em nível alto
    rjmp wait_for_release           ; Repete até que o botão seja solto

    rjmp loop                       ; Volta ao início do loop

usart_rx_isr:
    lds R16, UDR0                   ; Lê o byte recebido da UART
    cpi R16, '0'                    ; Verifica se o caractere é menor que '0'
    brlt invalid_char                ; Se for, trata como caractere inválido
    cpi R16, '9' + 1                ; Verifica se o caractere é maior que '9'
    brlt hex_number                  ; Se for um número, converte para valor hexadecimal
    cpi R16, 'A'                    ; Verifica se o caractere é menor que 'A'
    brlt invalid_char                ; Se for, trata como caractere inválido
    cpi R16, 'F' + 1                ; Verifica se o caractere é maior que 'F'
    brge invalid_char                ; Se for, trata como caractere inválido
    subi R16, 'A' - 10              ; Converte 'A'-'F' para 10-15
    rjmp display_char               ; Exibe o valor no display

hex_number:
    subi R16, '0'                   ; Converte '0'-'9' para 0-9

display_char:
    ldi ZL, low(hex_table*2)        ; Carrega o endereço da tabela no registrador Z
    ldi ZH, high(hex_table*2)
    add ZL, R16                     ; Adiciona o valor ao endereço da tabela
    adc ZH, R0                      ; Adiciona o carry ao byte superior
    lpm R16, Z                      ; Lê o valor correspondente na tabela
    out PORTB, R16                  ; Atualiza o display de 7 segmentos
    reti                            ; Retorna da interrupção

invalid_char:
    ldi ZL, low(invalid*2)          ; Carrega o endereço do caractere inválido (traço "-")
    ldi ZH, high(invalid*2)
    lpm R16, Z                      ; Lê o valor correspondente na tabela
    out PORTB, R16                  ; Exibe o traço no display
    rjmp loop                       ; Retorna da interrupção

send_button_message:
    ; Inicializa o ponteiro Z para a string "JOSE HENRIQUE B PENA"
    ldi ZL, LOW(name*2)             ; Carrega o byte inferior do endereço da string
    ldi ZH, HIGH(name*2)            ; Carrega o byte superior do endereço da string

send_name:
    lpm R16, Z+                     ; Lê o próximo caractere da string
    cpi R16, 0                      ; Verifica se é o fim da string (caractere nulo)
    breq end_send                   ; Se for, encerra o envio
    rcall uart_send                 ; Envia o caractere pela UART
    rjmp send_name                  ; Repete para o próximo caractere

end_send:
    ret                             ; Retorna da função

uart_send:
    lds R17, UCSR0A                 ; Lê o registrador de status da UART
    sbrs R17, UDRE0                 ; Pula a próxima instrução se o buffer de transmissão estiver vazio
    rjmp uart_send                  ; Repete até que o buffer esteja pronto
    sts UDR0, R16                   ; Envia o caractere pela UART
    ret                             ; Retorna da função

delay_50ms:
    ldi R21, 200                    ; Configura o contador externo para ~50 ms
delay_outer:
    ldi R22, 250                    ; Configura o contador interno
delay_inner:
    dec R22                         ; Decrementa o contador interno
    brne delay_inner                ; Repete até que o contador interno chegue a zero
    dec R21                         ; Decrementa o contador externo
    brne delay_outer                ; Repete até que o contador externo chegue a zero
    ret                             ; Retorna da função
