# uStack-avr - A portable and minimalistic IP stack, ported to the ATMEGA328p / ATMEGA2560

Ported from https://github.com/sjohann81/ustack.

uStack is a quick-and-dirty implementation of most common network protocols of IPv4, suitable for experiments, porting and integration of a IP network stack on embedded devices with limited resources. Currently, uStack supports a low level abstraction of a network card (using Linux TUN/TAP), Serial IP interface, Ethernet, ARP, BOOTP, IP, ICMP and UDP protocols.

## Configuration (TUN/TAP interface)

Just type *make eth_stack* or *make* to build the binary. To run it on a Arduino UNO or MEGA, change the MCU type in the Makefile, connect the board via USB and type *make flash*. After the programming process, connect to the board using the serial port created by the Arduino with a TUN/TAP tunnel using *sudo make eth_up* then try the demo.

Before reprogramming the board, be sure to bring the TUN/TAP tunnel down using Ctrl+c on the terminal running it. This process is needed because the same serial port is used for both programming and communicating with the host. If you have a different board, or arranged a different configuration on a breadboard, you may not need this.


## Configuration (TUN/TAP interface and SimulIDE)

This network stack can also run on the SimulIDE simulator. Add an ATMEGA328p MCU, right click on it and choose 'Open Serial Port'. Right click the serial port component, configure the port name as '/tmp/ttyS10' and select a baud rate of 57600, 1 stop bit, no flow control, no parity and 8 data bits. On a terminal, type *make eth_stack* or *make* to build the binary. To run it on SimulIDE, open a terminal and type *sudo make serial_sim* and on another terminal open a tunnel with *sudo make eth_up_sim*. Now click 'Open' on the serial port, load the .hex file on SimulIDE, start the simulation and try the demo.


## Configuration (SLIP interface)

Just type *make slip_stack* to build the binary. To run it on a Arduino UNO, connect the board via USB and type *make flash*. After the programming process, connect to the board using the serial port created by the Arduino with *sudo make slip_up* then try the demo.

Before reprogramming the board, be sure to bring the SLIP interface down with *sudo make slip_down*. This process is needed because the same serial port is used for both programming and communicating with the host. If you have a different board, or arranged a different configuration on a breadboard, you may not need this.


## Demo

The demo application (main.c) uses a static IP address / network mask is configured in the makefile. The application consists of a UDP callback routine and a loop which checks for received packets. On reception, the packet is injected into the network stack. To reach the application try this:

    $ ping -c 3 172.31.69.20

    PING 172.31.69.20 (172.31.69.20) 56(84) bytes of data.
    64 bytes from 172.31.69.20: icmp_seq=1 ttl=64 time=33.0 ms
    64 bytes from 172.31.69.20: icmp_seq=2 ttl=64 time=31.3 ms
    64 bytes from 172.31.69.20: icmp_seq=3 ttl=64 time=33.2 ms

    --- 172.31.69.20 ping statistics ---
    3 packets transmitted, 3 received, 0% packet loss, time 2002ms
    rtt min/avg/max/mdev = 31.307/32.524/33.262/0.892 ms


Then, test the *echo protocol* using UDP on port 7 or the demo application on port 30168:

    $ echo "hi there" | nc -u -w1 172.31.69.20 7
    hi there

    $ nc -u 172.31.69.20 30168
    hey
    Hello world!
