/* file:          tuntap_if.c
 * description:   tun/tap interface access / low level
 *                ethernet driver abstraction / tunnel via serial interface (host side)
 * date:          10/2021
 * author:        Sergio Johann Filho <sergio.johann@acad.pucrs.br>
 */

#include <stdlib.h>
#include <stdio.h>
#include <stdint.h>
#include <unistd.h>
#include <string.h>
#include <stdarg.h>
#include <errno.h>
#include <sys/socket.h>
#include <arpa/inet.h>
#include <linux/if.h>
#include <linux/if_tun.h>
#include <sys/ioctl.h>
#include <fcntl.h>

#define FRAME_SIZE	594
#define SERIAL_TO	10000
#define TUN_TO		10000

static int32_t tun_fd;
static char *dev;

char *tapaddr = USTACK_TAP_ADDR;
char *taproute = USTACK_TAP_ROUTE;

FILE *tin, *tout;
FILE *flog, *fdb;
int fd;

uint8_t eth_frame[FRAME_SIZE];
uint8_t mymac[6];

int32_t tty_setup(char *uart){
	fd = open(uart, O_RDWR);
	if (fd < 0) {
		printf("[ERROR]	error opening %s\n", uart);
		
		return -1;
	}
	tout = fopen(uart, "w");
	tin = fopen(uart, "r");
	if (tout < 0) {
		printf("[ERROR]	error opening for reading/writing%s\n", uart);
		
		return -1;
	} else {
		return 0;
	}
}

int32_t tty_data_recv(void){
	fd_set fds;
	FD_ZERO(&fds);
	FD_SET(fd, &fds);
	struct timeval timeout = { 0, SERIAL_TO };
	return select(fd+1, &fds, NULL, NULL, &timeout);
	/* ret == 0 means timeout, ret == 1 means descriptor is ready for reading,
		ret == -1 means error (check errno) */
}

int32_t tun_data_recv(void){
	fd_set fds;
	FD_ZERO(&fds);
	FD_SET(tun_fd, &fds);
	struct timeval timeout = { 0, TUN_TO };
	return select(tun_fd+1, &fds, NULL, NULL, &timeout);
	/* ret == 0 means timeout, ret == 1 means descriptor is ready for reading,
		ret == -1 means error (check errno) */
}

static int32_t set_if_route(char *dev, char *cidr)
{
	char buf[256];

	sprintf(buf, "ip route add dev %s %s", dev, cidr);
	printf("[DEBUG] %s\n", buf);
	system(buf);
	
	return 0;
}

static int32_t set_if_address(char *dev, char *cidr)
{
	char buf[256];

	sprintf(buf, "ip address add dev %s local %s", dev, cidr);
	printf("[DEBUG] %s\n", buf);
	system(buf);
	
	return 0;
}

static int32_t set_if_up(char *dev)
{
	char buf[256];

	sprintf(buf, "ip link set dev %s up", dev);
	printf("[DEBUG] %s\n", buf);
	system(buf);
	
	return 0;
}

static int32_t tun_alloc(char *dev)
{
	struct ifreq ifr;
	int32_t fd, err;
	struct ifreq s;

	if ((fd = open("/dev/net/tun", O_RDWR | O_NOCTTY | O_NDELAY)) < 0) {
		printf("[FATAL] Cannot open TUN/TAP dev\nMake sure one exists with '$ mknod /dev/net/tun c 10 200'\n");
		exit(-1);
	}

	memset(&ifr, 0, sizeof(ifr));
	ifr.ifr_flags = IFF_TAP | IFF_NO_PI;
	if (*dev)
		strncpy(ifr.ifr_name, dev, IFNAMSIZ-1);

	if ((err = ioctl(fd, TUNSETIFF, (void *) &ifr)) < 0) {
		printf("[FATAL] Could not ioctl tun");
		close(fd);
		return err;
	}

	if ((err = ioctl(fd, SIOCGIFHWADDR, &s)) == 0) {
		memcpy(mymac, s.ifr_addr.sa_data, 6);
		printf("[DEBUG] tap interface configured\n");
	} else {
		printf("[FATAL] Could not get interface MAC address");
		close(fd);
		return err;
	}
	strcpy(dev, ifr.ifr_name);

	return fd;
}

int32_t if_setup()
{
	dev = calloc(10, 1);
	tun_fd = tun_alloc(dev);

	if (set_if_up(dev) != 0)
		printf("[FATAL] Setting up interface failed.\n");

	if (set_if_route(dev, taproute) != 0)
		printf("[FATAL] Setting route for interface failed\n");

	if (set_if_address(dev, tapaddr) != 0)
		printf("[FATAL] Setting address for interface failed\n");
		
	return 0;
}

int32_t if_deinit()
{
	free(dev);
	
	return 0;
}

int32_t hexdump(uint8_t *buf, uint32_t size)
{
	uint32_t k, l;
	char ch;

	for (k = 0; k < size; k += 16) {
		for (l = 0; l < 16; l++) {
			printf("%02x ", buf[k + l]);
			if (l == 7) putchar(' ');
		}
		printf(" |");
		for (l = 0; l < 16; l++) {
			ch = buf[k + l];
			if ((ch >= 32) && (ch <= 126))
				putchar(ch);
			else
				putchar('.');
		}
		printf("|\n");
	}

	return 0;
}

int main(int32_t argc, char **argv)
{
	int32_t size, i, k;
	uint8_t header[4], data;
	uint16_t *data_sz = (uint16_t *)&header[2];

	if (argc != 2) {
		printf("Usage: tuntap_if_host </dev/ttyXX>\n");
		
		return -1;
	}

	tty_setup(argv[1]);
	if_setup();
	
	for (;;) {
		size = read(tun_fd, eth_frame, FRAME_SIZE);
		if (size > 0) {
			header[0] = 0x55;
			header[1] = 0x55;
			*data_sz = htons(size);
			write(fd, header, 4);
			write(fd, eth_frame, size);
		}
		
		if (tty_data_recv()) {
			usleep(50000);
			i = read(fd, header, 4);
			if (i == 4) {
				size = ntohs(*data_sz);
				printf("size: %d\n", size);
				
				for (k = 0; k < size && k < FRAME_SIZE; k++) {
					read(fd, &data, 1);
					eth_frame[k] = data;
				}

				if (size > 0 && size <= FRAME_SIZE) {
					hexdump(eth_frame, size);
					write(tun_fd, eth_frame, size);
				}
			}
		}
	}
}
