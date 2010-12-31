CFLAGS = -Wall -std=c99 
CC = gcc
BINDIR = ${DESTDIR}/bin
MANDIR = ${DESTDIR}/man
SRCS = hex2passwd.c
OBJS = hex2passwd.o
INSTALL = install
all: hex2passwd

$(SRCS):
	$(CC) $(CFLAGS) -c $*.c


hex2passwd: $(OBJS)
	$(CC) $(CFLAGS) -o $@ $(OBJS)

install: hex2passwd hex2passwd.1
	$(INSTALL) -c -o root -g sys -m 755 hex2passwd $(BINDIR)
	$(INSTALL) -c -o root -g sys -m 644 hex2passwd.1 $(MANDIR)/man1
