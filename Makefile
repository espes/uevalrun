#
# Makefile for uevalrun
# by pts@fazekas.hu at Mon Nov 22 02:19:12 CET 2010
#

# This must be a 32-bit compiler.
# TODO(pts): How to enforce 32-bit output for GCC?
CC = i386-uclibc-gcc

CC_DETECT = $(shell if test "$$CC"; then echo "$$CC"; elif i386-uclibc-gcc -v >/dev/null 2>&1; then echo i386-uclibc-gcc -static; else echo gcc -static; fi)

.PHONY: all clean run_sys run_mini_sys

all:
	$(MAKE) CC='$(CC_DETECT)' uevalrun uevalrun.guestinit

clean:
	rm -f uevalrun uevalrun.guestinit

uevalrun: uevalrun.c
	$(CC) -s -W -Wall -o $@ $<

minihalt: minihalt.c
	$(CC) -s -W -Wall -o $@ $<

uevalrun.guestinit: guestinit.c
	$(CC) -s -W -Wall -o $@ $<

run_sys:
	./uevalrun.linux.uml con=null ssl=null con0=fd:0,fd:1 mem=30M ubda=uevalrun.rootfs.ext2.img rw

run_mini_sys:
	./uevalrun.linux.uml con=null ssl=null con0=fd:0,fd:1 mem=30M ubda=uevalrun.rootfs.mini.ext2.img init=/bin/sh rw
