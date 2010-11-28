#
# Makefile for uevalrun
# by pts@fazekas.hu at Mon Nov 22 02:19:12 CET 2010
#

# This must be a 32-bit compiler.
# TODO(pts): How to enforce 32-bit output for GCC?
CC = i386-uclibc-gcc

CC_DETECT = $(shell if test "$$CC"; then echo "$$CC"; elif i386-uclibc-gcc -v >/dev/null 2>&1; then echo i386-uclibc-gcc -static; else echo gcc -static; fi)

ALL = uevalrun uevalrun.guestinit uevalrun.rootfs.minix.img

.PHONY: all clean run_sys run_mini_sys

all:
	$(MAKE) CC='$(CC_DETECT)' $(ALL)

clean:
	rm -f $(ALL)

uevalrun: uevalrun.c
	$(CC) -s -W -Wall -o $@ $<

minihalt: minihalt.c
	$(CC) -s -W -Wall -o $@ $<

uevalrun.guestinit: guestinit.c
	$(CC) -s -W -Wall -o $@ $<

uevalrun.rootfs.minix.img:
	./busybox sh ./make_rootfs.sh

run_sys: uevalrun.rootfs.minix.img
	./uevalrun.linux.uml con=null ssl=null con0=fd:0,fd:1 mem=30M ubda=uevalrun.rootfs.minix.img rw

run_mini_sys:
	./uevalrun.linux.uml con=null ssl=null con0=fd:0,fd:1 mem=30M ubda=uevalrun.rootfs.mini.minix.img init=/bin/sh rw

run_gcc_sys:
	./busybox dd if=/dev/zero of=uevalrun.rootfs.gcxtmp.minix.img bs=2000K count=1
	./busybox mkfs.minix -n 30 -i 20 uevalrun.rootfs.gcxtmp.minix.img
	./uevalrun.linux.uml con=null ssl=null con0=fd:0,fd:1 mem=60M ubda=uevalrun.rootfs.gcc.minix.img ubdb=uevalrun.rootfs.gcxtmp.minix.img init=/sbin/minihalt rw ubde=hello.c
