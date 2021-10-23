/* file:          tuntap_if.c
 * description:   tun/tap interface access / low level
 *                ethernet driver abstraction / tunnel via serial interface (MCU side)
 * date:          07/2021
 * author:        Sergio Johann Filho <sergio.johann@acad.pucrs.br>
 */

#include "include/ustack.h"

int32_t if_setup()
{
	uart_init(57600, 0);
	
	return 0;
}

void en_ll_output(uint8_t *frame, uint16_t size)
{
	uint16_t i;
	uint8_t data_sz[2];
	uint16_t *size_p = (uint16_t *)&data_sz;
	
	*size_p = htons(size);
	uart_tx(0x55);
	uart_tx(0x55);
	uart_tx(data_sz[0]);
	uart_tx(data_sz[1]);
	for (i = 0; i < size && i < FRAME_SIZE; i++)
		uart_tx(frame[i]);
}

int32_t en_ll_input(uint8_t *frame)
{
	uint16_t i, size;
	uint8_t data_sz[2];
	uint16_t *size_p = (uint16_t *)&data_sz;

	if (uart_rxsize() == 0)
		return 0;

	if (uart_rx() != 0x55)
		return -1;
	if (uart_rx() != 0x55)
		return -1;
	data_sz[0] = uart_rx();
	data_sz[1] = uart_rx();
	
	size = ntohs(*size_p);
	
	for (i = 0; i < size && i < FRAME_SIZE; i++)
		frame[i] = uart_rx();

	return size;
}
