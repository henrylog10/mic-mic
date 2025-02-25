#include <avr/io.h>
#include <avr/interrupt.h>

#define F_CPU 16000000UL  // Frequência do clock do ATmega328P (16 MHz)
#include <util/delay.h>

// Configuração dos pinos
#define SDI PB6
#define CLK PB5
#define BUTTON PD3
#define BTN_GND PD2

void uart_init() {
    unsigned int ubrr = 12;  // Para 4800 bps com 16 MHz
    UBRR0H = (unsigned char)(ubrr >> 8);
    UBRR0L = (unsigned char)ubrr;
    UCSR0B = (1 << RXEN0) | (1 << TXEN0) | (1 << RXCIE0);  // Habilita RX, TX e interrupção RX
    UCSR0C = (1 << UCSZ01) | (1 << UCSZ00);  // 8 bits de dados
}

void uart_transmit(unsigned char data) {
    while (!(UCSR0A & (1 << UDRE0)));  // Espera até o buffer estar vazio
    UDR0 = data;
}

unsigned char uart_receive(void) {
    while (!(UCSR0A & (1 << RXC0)));  // Espera por dado
    return UDR0;
}

void update_display(unsigned char data) {
    PORTB = data;  // Envia o dado para os pinos de controle do display
}

void ascii_to_7seg(char c, unsigned char* data) {
    switch (c) {
        case '0': *data = 0x3F; break;
        case '1': *data = 0x06; break;
        case '2': *data = 0x5B; break;
        case '3': *data = 0x4F; break;
        case '4': *data = 0x66; break;
        case '5': *data = 0x6D; break;
        case '6': *data = 0x7D; break;
        case '7': *data = 0x07; break;
        case '8': *data = 0x7F; break;
        case '9': *data = 0x6F; break;
        default: *data = 0x00; break;
    }
}

void setup() {
    // Configura PB6 (SDI) e PB5 (CLK) como saída
    DDRB |= (1 << SDI) | (1 << CLK);
    // Configura PD3 (BUTTON) como entrada com pull-up
    DDRD &= ~(1 << BUTTON);
    PORTD |= (1 << BUTTON);  // Ativa o pull-up
    // Configura PD2 como saída para BTN_GND
    DDRD |= (1 << BTN_GND);
    PORTD &= ~(1 << BTN_GND);  // GND

    uart_init();  // Inicializa a UART
    sei();  // Habilita interrupções globais
}

ISR(USART_RX_vect) {
    unsigned char received = uart_receive();  // Lê o dado recebido pela UART
    unsigned char display_data;
    ascii_to_7seg(received, &display_data);  // Converte para 7 segmentos
    update_display(display_data);  // Atualiza o display
}

ISR(INT1_vect) {
    // Interrupção do botão: envia o nome pela UART
    uart_transmit('A');
    uart_transmit('L');
    uart_transmit('U');
    uart_transmit('N');
}

int main() {
    setup();
    while (1) {
        // Loop principal
    }
    return 0;
}
