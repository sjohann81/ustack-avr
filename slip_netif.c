/* file:          slip_netif.c
 * description:   Serial Line IP interface
 * date:          07/2021
 * author:        Sergio Johann Filho <sergio.johann@acad.pucrs.br>
 */

#include "include/ustack.h"

int32_t if_setup()
{
	rs232_init(57600);
	
	return 0;
}

static void tty_write(uint8_t byte)
{
	rs232_tx(byte);
}

static uint8_t tty_read(void)
{
	uint8_t byte;
	
	byte = rs232_rx();
	
	return byte;
}
 
uint16_t netif_send(uint8_t *packet, uint16_t len)
{
	uint16_t i;

	tty_write(SLIP_END);
	for (i = 0; i < len; i++) {
		if (packet[i] == SLIP_END) {
			tty_write(SLIP_ESC);
			tty_write(SLIP_ESC_END);
		} else {
			if (packet[i] == SLIP_ESC) {
				tty_write(SLIP_ESC);
				tty_write(SLIP_ESC_ESC);
			} else {
				tty_write(packet[i]);
			}
		}
	}
	tty_write(SLIP_END);
	
	return len;
}

uint16_t netif_recv(uint8_t *packet)
{
	uint16_t len = 0;
	int16_t r;

	while (1) {
		r = tty_read();
		if (r == SLIP_END) {
			if (len > 0) {
				return len;
			}
		} else {
			if (r == SLIP_ESC) {
				r = tty_read();
				if (r == SLIP_ESC_END) {
					r = SLIP_END;
				} else {
					if (r == SLIP_ESC_ESC) {
						r = SLIP_ESC;
					}
				}
			}
			packet[len++] = r;
			if (len > FRAME_SIZE)
				len = 0;
		}
	}
}
