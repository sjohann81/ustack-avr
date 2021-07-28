# application flags:
# USTACK_BIG_ENDIAN		configures ustack to work on big endian machines
# USTACK_IP_ADDR		static configuration of IP address
# USTACK_NETMASK		static configuration of network mask
# USTACK_GW_ADDR		static configuration of gateway address

# configurable section
USTACK_IP_ADDR =	172.31.69.20
USTACK_NETMASK =	255.255.255.0
USTACK_GW_ADDR =	172.31.69.1

# compiler flags section
AFLAGS = 	-DUSTACK_IP_ADDR=\"$(USTACK_IP_ADDR)\" \
		-DUSTACK_NETMASK=\"$(USTACK_NETMASK)\" \
		-DUSTACK_GW_ADDR=\"$(USTACK_GW_ADDR)\"

MCU = atmega328p
CRYSTAL = 16000000

SERIAL_DEV = /dev/ttyACM0
SERIAL_PROG = /dev/ttyACM0
SERIAL_BAUDRATE=57600

CC = avr-gcc
OBJCOPY = avr-objcopy
OBJDUMP = avr-objdump
SIZE = avr-size

CFLAGS = $(AFLAGS) -g -mmcu=$(MCU) -Wall -Os -fno-inline-small-functions -fno-split-wide-types -D F_CPU=$(CRYSTAL) -D USART_BAUD=$(SERIAL_BAUDRATE)

AVRDUDE_CONFIG=/usr/local/avr/gcc/etc/avrdude.conf
AVRDUDE_PART=m328p

#PROGRAMMER = bsd
#PROGRAMMER = usbtiny
#PROGRAMMER = dasa -P $(SERIAL_PROG)
#PROGRAMMER = usbasp
PROGRAMMER = arduino -P $(SERIAL_PROG)

all:
	$(CC) $(CFLAGS) -c utils.c -o utils.o
	$(CC) $(CFLAGS) -c rs232.c -o rs232.o
	$(CC) $(CFLAGS) -c slip_netif.c -o slip_netif.o
	$(CC) $(CFLAGS) -c ip.c -o ip.o
	$(CC) $(CFLAGS) -c icmp.c -o icmp.o
	$(CC) $(CFLAGS) -c udp.c -o udp.o
	$(CC) $(CFLAGS) -c main.c -o main.o
	$(CC) $(CFLAGS) utils.o rs232.o slip_netif.o ip.o icmp.o udp.o main.o -o code.elf
	$(OBJCOPY) -R .eeprom -O ihex code.elf code.hex
	$(OBJDUMP) -d code.elf > code.lst
	$(OBJDUMP) -h code.elf > code.sec
	$(SIZE) code.elf

flash:
	avrdude -C $(AVRDUDE_CONFIG) -p $(AVRDUDE_PART) -U flash:w:code.hex -y -c $(PROGRAMMER)

serial:
	stty ${BAUD} raw cs8 -parenb -crtscts clocal cread ignpar ignbrk -ixon -ixoff -ixany -brkint \
	-icrnl -imaxbel -opost -onlcr -isig -icanon -iexten -echo -echoe -echok -echoctl -echoke -F ${SERIAL_DEV}

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
	rm -f *.o *.map *.elf *.sec *.lst *.hex *~
