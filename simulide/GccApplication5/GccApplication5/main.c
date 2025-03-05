#define F_CPU 16000000UL
#include <avr/io.h>
#include <avr/interrupt.h>
#include <util/delay.h>
#include <stdio.h>

#define BAUD 4800
#define MYUBRR F_CPU/16/BAUD-1

// Tabela de conversão para display de 7 segmentos (ânodo comum)
const uint8_t hex_to_7seg[16] = {
	0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07,
	0x7F, 0x6F, 0x77, 0x7C, 0x39, 0x5E, 0x79, 0x71
};

// Variável global para armazenar o último caractere recebido
volatile char last_received_char = '\0';

static int uart_putchar(char c, FILE *stream) {
	while (!(UCSR0A & (1 << UDRE0)));
	UDR0 = c;
	return 0;
}

static FILE uart_output = FDEV_SETUP_STREAM(uart_putchar, NULL, _FDEV_SETUP_WRITE);

void UART_init() {
	UBRR0H = ((MYUBRR) >> 8); // Adicionado parênteses para evitar aviso
	UBRR0L = MYUBRR;
	UCSR0B = (1 << RXEN0) | (1 << TXEN0) | (1 << RXCIE0);
	UCSR0C = (1 << UCSZ01) | (1 << UCSZ00);
}

ISR(USART_RX_vect) {
	last_received_char = UDR0; // Armazena o último caractere recebido
}

void update_display(char received) {
	uint8_t display_value = 0x40; // Valor padrão: traço "-"

	// Converte o caractere recebido para o valor correspondente no display de 7 segmentos
	if (received >= '0' && received <= '9') {
		display_value = hex_to_7seg[received - '0'];
		} else if (received >= 'A' && received <= 'F') {
		display_value = hex_to_7seg[received - 'A' + 10];
		} else if (received >= 'a' && received <= 'f') {
		display_value = hex_to_7seg[received - 'a' + 10];
	}

	PORTB = display_value; // Exibe o valor no display de 7 segmentos
	printf("Recebido: %c | Exibindo: 0x%02X\n", received, display_value); // Debug
}

int main() {
	DDRB = 0x7F; // Configura PB0-PB6 como saídas (display de 7 segmentos)
	PORTB = 0x40; // Exibe um traço "-" inicialmente

	DDRD &= ~(1 << PD2); // Configura PD2 como entrada (botão)
	PORTD |= (1 << PD2); // Habilita o pull-up interno no PD2

	UART_init(); // Inicializa a UART
	stdout = &uart_output; // Redireciona a saída padrão (printf) para a UART
	sei(); // Habilita interrupções globais

	printf("Sistema inicializado.\n"); // Mensagem de inicialização

	while (1) {
		if (last_received_char != '\0') { // Verifica se há um novo caractere
			update_display(last_received_char); // Atualiza o display com o último caractere
			last_received_char = '\0'; // Limpa o caractere após processamento
		}

		if (!(PIND & (1 << PD2))) { // Verifica se o botão foi pressionado (nível baixo)
			_delay_ms(50); // Debounce
			if (!(PIND & (1 << PD2))) { // Confirma a pressão do botão
				printf("Botão pressionado: josé henrique barbosa pena\n"); // Envia mensagem pela UART
				while (!(PIND & (1 << PD2))); // Espera o botão ser solto
			}
		}
	}
}