/* file:          rs232.c
 * description:   UART driver
 * date:          07/2021
 * author:        Sergio Johann Filho <sergio.johann@acad.pucrs.br>
 */

#include "include/ustack.h"

#define UCSRA		UCSR0A
#define UCSRB		UCSR0B
#define UCSRC		UCSR0C
#define UBRRH		UBRR0H
#define UBRRL		UBRR0L
#define UDRE		UDRE0
#define UDR		UDR0
#define RXC		RXC0
#define RXEN		RXEN0
#define TXEN		TXEN0
#define UCSZ1		UCSZ01
#define UCSZ0		UCSZ00 
#define USBS		USBS0
#define RXCIE		RXCIE0

void rs232_init(uint32_t baud)
{
	uint32_t ubrr_val;
	
	cli();
	/* set USART baud rate */
	ubrr_val = ((uint32_t)F_CPU / (16 * baud)) - 1;
	UBRRH = (uint8_t)(ubrr_val >> 8);
	UBRRL = (uint8_t)(ubrr_val & 0xff);
	/* set frame format to 8 data bits, no parity, 1 stop bit */
	UCSRC = (0 << USBS) | (3 << UCSZ0);
	/* enable receiver, transmitter and receiver interrupt */
	UCSRB = (1 << RXEN) | (1 << TXEN);
	sei();
}

void rs232_tx(uint8_t data)
{
	/* wait if a byte is being transmitted */
	while ((UCSRA & (1 << UDRE)) == 0);
	/* transmit data */
	UDR = data;
}

uint8_t rs232_rx(void)
{
	// wait until a byte has been received
	while ((UCSRA & (1 << RXC)) == 0);
	// return received data
	return UDR;
}
