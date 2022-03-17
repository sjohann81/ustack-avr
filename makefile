# application flags:
# USTACK_BIG_ENDIAN		configures ustack to work on big endian machines
# USTACK_IP_ADDR		static configuration of IP address
# USTACK_NETMASK		static configuration of network mask
# USTACK_GW_ADDR		static configuration of gateway address
# USTACK_TAP_ADDR		TUN/TAP interface address
# USTACK_TAP_ROUTE		TUN/TAP interface default route

# configurable section
USTACK_IP_ADDR =	172.31.69.20
USTACK_NETMASK =	255.255.255.0
USTACK_GW_ADDR =	172.31.69.1
USTACK_TAP_ADDR =	172.31.69.1/24
USTACK_TAP_ROUTE =	172.31.69.0/24

# compiler flags section
AFLAGS = 	-DUSTACK_IP_ADDR=\"$(USTACK_IP_ADDR)\" \
		-DUSTACK_NETMASK=\"$(USTACK_NETMASK)\" \
		-DUSTACK_GW_ADDR=\"$(USTACK_GW_ADDR)\" \
		-DUSTACK_TAP_ADDR=\"$(USTACK_TAP_ADDR)\" \
		-DUSTACK_TAP_ROUTE=\"$(USTACK_TAP_ROUTE)\" 

MCU = atmega328p
#MCU = atmega2560
CRYSTAL = 16000000

ifeq ('$(MCU)', 'atmega328p')
	MCU_TYPE = 1
else ifeq ('$(MCU)', 'atmega2560')
	MCU_TYPE = 2
endif

SERIAL_DEV = /dev/ttyACM0
SERIAL_PROG = /dev/ttyACM0
SERIAL_BAUDRATE=57600

CC = avr-gcc
OBJCOPY = avr-objcopy
OBJDUMP = avr-objdump
SIZE = avr-size

CFLAGS = $(AFLAGS) -g -mmcu=$(MCU) -Wall -Os -fno-inline-small-functions -fno-split-wide-types -D MCU_TYPE=$(MCU_TYPE) -D F_CPU=$(CRYSTAL) -D USART_BAUD=$(SERIAL_BAUDRATE)

AVRDUDE_CONFIG=/usr/local/avr/gcc/etc/avrdude.conf
AVRDUDE_PART=m328p

#PROGRAMMER = bsd
#PROGRAMMER = usbtiny
#PROGRAMMER = dasa -P $(SERIAL_PROG)
#PROGRAMMER = usbasp
PROGRAMMER = arduino -P $(SERIAL_PROG)

all: eth_stack

eth_stack:
	$(CC) $(CFLAGS) -c utils.c -o utils.o
	$(CC) $(CFLAGS) -c uart.c -o uart.o
	$(CC) $(CFLAGS) -c tuntap_if.c -o tuntap_if.o
	$(CC) $(CFLAGS) -c eth_netif.c -o eth_netif.o
	$(CC) $(CFLAGS) -c bootp.c -o bootp.o
	$(CC) $(CFLAGS) -c arp.c -o arp.o
	$(CC) $(CFLAGS) -c ip.c -o ip.o
	$(CC) $(CFLAGS) -c icmp.c -o icmp.o
	$(CC) $(CFLAGS) -c udp.c -o udp.o
	$(CC) $(CFLAGS) -c main.c -o main.o
	$(CC) $(CFLAGS) utils.o uart.o tuntap_if.o eth_netif.o bootp.o arp.o ip.o icmp.o udp.o main.o -o code.elf
	$(OBJCOPY) -R .eeprom -O ihex code.elf code.hex
	$(OBJDUMP) -d code.elf > code.lst
	$(OBJDUMP) -h code.elf > code.sec
	$(SIZE) code.elf
	gcc $(AFLAGS) -Wall tuntap_if_host.c -o tuntap_if_host 

slip_stack:
	$(CC) $(CFLAGS) -c utils.c -o utils.o
	$(CC) $(CFLAGS) -c uart.c -o uart.o
	$(CC) $(CFLAGS) -c slip_netif.c -o slip_netif.o
	$(CC) $(CFLAGS) -c ip.c -o ip.o
	$(CC) $(CFLAGS) -c icmp.c -o icmp.o
	$(CC) $(CFLAGS) -c udp.c -o udp.o
	$(CC) $(CFLAGS) -c main.c -o main.o
	$(CC) $(CFLAGS) utils.o uart.o slip_netif.o ip.o icmp.o udp.o main.o -o code.elf
	$(OBJCOPY) -R .eeprom -O ihex code.elf code.hex
	$(OBJDUMP) -d code.elf > code.lst
	$(OBJDUMP) -h code.elf > code.sec
	$(SIZE) code.elf

flash:
	avrdude -C $(AVRDUDE_CONFIG) -p $(AVRDUDE_PART) -U flash:w:code.hex -y -c $(PROGRAMMER)

serial_sim:
	socat -d -d  pty,link=/tmp/ttyS10,raw,echo=0,perm-late=777 pty,link=/tmp/ttyS11,raw,echo=0

eth_up_sim:
	./tuntap_if_host /tmp/ttyS11

serial:
	stty ${SERIAL_BAUDRATE} raw cs8 -parenb -crtscts clocal cread ignpar ignbrk -ixon -ixoff -ixany -brkint \
	-icrnl -imaxbel -opost -onlcr -isig -icanon -iexten -echo -echoe -echok -echoctl -echoke -F ${SERIAL_DEV}
	
eth_up: serial
	./tuntap_if_host ${SERIAL_DEV}

slip_up: serial
	slattach -L -d -p slip -s ${SERIAL_BAUDRATE} ${SERIAL_DEV} &
	sleep 2
	ifconfig sl0 ${USTACK_GW_ADDR}
	ifconfig sl0 dstaddr ${USTACK_IP_ADDR}
	ifconfig sl0 mtu 576

slip_down:
	killall slattach

forwarding:
	echo 1 > /proc/sys/net/ipv4/ip_forward

config_ip:
	ping ${USTACK_IP_ADDR} -s 113 -c 1

dump:
	tcpdump -l -n -S -XX -s 0 -vv -i sl0

# external high frequency crystal
fuses:
	avrdude -C $(AVRDUDE_CONFIG) -p $(AVRDUDE_PART) -U lfuse:w:0xcf:m -U hfuse:w:0xd9:m -U efuse:w:0x07:m -c $(PROGRAMMER)

# internal rc osc @ 1MHz, original factory config
fuses_osc:
	avrdude -C $(AVRDUDE_CONFIG) -p $(AVRDUDE_PART) -U lfuse:w:0x62:m -U hfuse:w:0xd9:m -U efuse:w:0x07:m -c $(PROGRAMMER)

test:
	avrdude -C $(AVRDUDE_CONFIG) -p $(AVRDUDE_PART) -c $(PROGRAMMER)

parport:
	modprobe parport_pc

clean:
	rm -f *.o *.map *.elf *.sec *.lst *.hex *~ tuntap_if_host
