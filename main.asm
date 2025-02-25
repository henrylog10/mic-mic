.include <avr/io.h>          ; Inclui as definições de I/O para o ATmega328P

; Definição de pinos
.equ SDI = PB6               ; Serial Data In do display
.equ CLK = PB5               ; Clock do display
.equ BUTTON = PD3            ; Botão (INT1)
.equ BTN_GND = PD2           ; Pino usado para simular GND do botão

; Vetores de interrupção
.equ INT1addr = 0x0004       ; Vetor de interrupção do botão
.equ USART_RXaddr = 0x0024   ; Vetor de interrupção da UART

; Configuração inicial
.org 0x00
    rjmp setup               ; Pula para a configuração inicial

; Interrupções
.org INT1addr                ; Vetor de interrupção do botão
    rjmp send_name

.org USART_RXaddr            ; Vetor de interrupção da UART
    rjmp uart_receive

; -------------------------------------
; Configuração do microcontrolador
setup:
    ; Configura PB6 (SDI) e PB5 (CLK) como saída
    ldi r16, (1<<PB6) | (1<<PB5)
    out DDRB, r16

    ; Ativa pull-up interno para PD3 (INT1)
    ldi r16, (1<<PD3)
    out PORTD, r16

    ; Configura PD2 como saída e define como LOW
    ldi r16, (1<<PD2)
    out DDRD, r16
    cbi PORTD, PD2            ; Garante que PD2 está em LOW

    ; Configuração da UART (4800 bps, 8N1)
    ldi r16, 12               ; Valor para UBRR (4800 bps @ 16MHz)
    sts UBRR0L, r16
    clr r16
    sts UBRR0H, r16
    ldi r16, (1<<RXEN0) | (1<<TXEN0) | (1<<RXCIE0) ; Habilita TX, RX e interrupção
    sts UCSR0B, r16

    ; Configuração da interrupção do botão (borda de descida)
    ldi r16, (1<<ISC11)
    sts EICRA, r16
    sei                        ; Habilita interrupções globais

main:
    rjmp main                  ; Loop infinito

; -------------------------------------
; Rotina de interrupção da UART
uart_receive:
    in r16, UDR0               ; Lê byte recebido
    call process_data          ; Processa o dado
    reti

; -------------------------------------
; Processamento do dado recebido
process_data:
    ; Verifica se é um número hexadecimal válido
    cpi r16, '0'
    brlo invalid_char
    cpi r16, '9'+1
    brlo valid_char
    cpi r16, 'A'
    brlo invalid_char
    cpi r16, 'F'+1
    brlo valid_char
    cpi r16, 'a'
    brlo invalid_char
    cpi r16, 'f'+1
    brlo valid_char

invalid_char:
    ldi r16, 0b01000000        ; Código para "-" no display
    rjmp update_display

valid_char:
    call ascii_to_7seg         ; Converte ASCII para segmento
    rjmp update_display

; -------------------------------------
; Conversão de ASCII para 7 segmentos
ascii_to_7seg:
    ; Tabela de conversão de ASCII para 7 segmentos
    ; Exemplo: '0' -> 0x3F, '1' -> 0x06, etc.
    ; Implementar tabela de conversão aqui
    ret

; -------------------------------------
; Atualização do display
update_display:
    out PORTB, r16
    ret

; -------------------------------------
; Rotina de interrupção do botão (envia nome pela UART)
send_name:
    ldi r16, 'A'
    call uart_transmit
    ldi r16, 'L'
    call uart_transmit
    ldi r16, 'U'
    call uart_transmit
    ldi r16, 'N'
    call uart_transmit
    ldi r16, 'O'
    call uart_transmit
    reti

; -------------------------------------
; Transmissão de dados via UART
uart_transmit:
    sbis UCSR0A, UDRE0          ; Espera buffer vazio
    rjmp uart_transmit
    out UDR0, r16               ; Envia dado
    ret
