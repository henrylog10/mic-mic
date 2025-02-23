#define F_CPU 16000000UL   // Define F_CPU antes de incluir <util/delay.h>
#include <avr/io.h>
#include <avr/interrupt.h>
#include <util/delay.h>    // Agora F_CPU já está definido
#include <avr/pgmspace.h>

// Constantes
#define BAUD 4800          // Taxa de transmissão UART
#define UBRR_VAL ((F_CPU / (16UL * BAUD)) - 1) // Cálculo do UBRR

// Tabela de segmentos (0-F e '-')
const uint8_t seg_table[] PROGMEM = {
    0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07,
    0x7F, 0x6F, 0x77, 0x7C, 0x39, 0x5E, 0x79, 0x71, 0x40
};

// String do nome (José Henrique Barbosa Pena)
const char name_string[] PROGMEM = "José Henrique Barbosa Pena";

// Variáveis globais
volatile uint8_t tx_flag = 0; // Flag de transmissão

// Função para enviar o nome pela UART
void send_name() {
    uint8_t i = 0;
    char c;
    while ((c = pgm_read_byte(&name_string[i])) != 0) {
        while (!(UCSR0A & (1 << UDRE0))); // Espera UDR0 estar vazio
        UDR0 = c; // Envia caractere
        i++;
    }
}

// Interrupção UART RX
ISR(USART_RX_vect) {
    uint8_t temp = UDR0; // Lê dado recebido
    uint8_t hex_val, seg_code;

    // Verifica se é '0'-'9'
    if (temp >= '0' && temp <= '9') {
        hex_val = temp - '0'; // Converte para 0x00-0x09
    }
    // Verifica 'A'-'F'
    else if (temp >= 'A' && temp <= 'F') {
        hex_val = temp - 'A' + 10; // Converte para 0x0A-0x0F
    }
    // Verifica 'a'-'f'
    else if (temp >= 'a' && temp <= 'f') {
        hex_val = temp - 'a' + 10; // Converte para 0x0A-0x0F
    }
    // Caractere inválido
    else {
        seg_code = 0x40; // Código para '-'
        PORTD = seg_code; // Atualiza display
        return;
    }

    // Carrega código do segmento
    seg_code = pgm_read_byte(&seg_table[hex_val]);
    PORTD = seg_code; // Atualiza display
}

// Interrupção do botão (INT0)
ISR(INT0_vect) {
    tx_flag = 1; // Ativa flag de transmissão
}

int main(void) {
    // Inicializa stack pointer
    SP = RAMEND;

    // Configura UART
    UBRR0H = (uint8_t)(UBRR_VAL >> 8);
    UBRR0L = (uint8_t)(UBRR_VAL);
    UCSR0B = (1 << RXEN0) | (1 << TXEN0) | (1 << RXCIE0); // Habilita RX, TX e interrupção
    UCSR0C = (1 << UCSZ01) | (1 << UCSZ00); // Modo 8N1

    // Configura PortD como saída (display 7 segmentos)
    DDRD = 0xFF;

    // Configura botão em PD2 (INT0) com pull-up
    DDRD &= ~(1 << PD2);
    PORTD |= (1 << PD2);
    EICRA = (1 << ISC01); // Borda de descida
    EIMSK = (1 << INT0);  // Habilita INT0

    sei(); // Habilita interrupções globais

    while (1) {
        if (tx_flag) { // Verifica se o botão foi pressionado
            send_name(); // Envia o nome
            tx_flag = 0; // Limpa a flag
        }
    }

    return 0;
}