#! /bin/bash --
#
# make_kernel.sh: build the uevalrun.linux.uml kernel
# by pts@fazekas.hu at Wed Nov 24 00:26:59 CET 2010
#

KERNEL_TBZ2="${KERNEL_TBZ2:-linux-2.6.36.1.tar.bz2}"
CROSS_COMPILER=cross-compiler-i686

set -ex

test "${0%/*}" != "$0" && cd "${0%/*}"

if ! test -f "$KERNEL_TBZ2.downloaded"; then
  wget -c -O "${KERNEL_TBZ2}" http://www.kernel.org/pub/linux/kernel/v2.6/"${KERNEL_TBZ2##*/}"
  touch "$KERNEL_TBZ2.downloaded"
fi

if ! test -f "$CROSS_COMPILER.tar.bz2.downloaded"; then
  wget -c -O "$CROSS_COMPILER.tar.bz2" http://pts-mini-gpl.googlecode.com/files/"$CROSS_COMPILER".tar.bz2
  touch "$CROSS_COMPILER.tar.bz2.downloaded"
fi

rm -rf make_kernel.tmp
mkdir make_kernel.tmp
: Extracting "$KERNEL_TBZ2"
(cd make_kernel.tmp && tar xj) <"$KERNEL_TBZ2"
mv make_kernel.tmp/linux-* make_kernel.tmp/kernel
: Applying linux-2.6.36-uevalrun.patch
(cd make_kernel.tmp/kernel && patch -p1) <linux-2.6.36-uevalrun.patch
: Extracting "$CROSS_COMPILER.tar.bz2"
(cd make_kernel.tmp && tar xj) <"$CROSS_COMPILER.tar.bz2"
mv make_kernel.tmp/cross-compiler-* make_kernel.tmp/cross-compiler

# TODO(pts): Auto-detect non-i686 prefixes.
CROSS="$PWD/make_kernel.tmp/cross-compiler/bin/i686-"
test "${CROSS}gcc"

(cd make_kernel.tmp/kernel && make ARCH=um \
    CROSS_COMPILE="$CROSS" \
    HOSTCC="${CROSS}gcc -static" \
    LD_XFLAGS=-static vmlinux)
ls -l         make_kernel.tmp/kernel/vmlinux
${CROSS}strip make_kernel.tmp/kernel/vmlinux
ls -l         make_kernel.tmp/kernel/vmlinux
rm -f uevalrun.linux.uml.tmp
cp make_kernel.tmp/kernel/vmlinux uevalrun.linux.uml.tmp
mv uevalrun.linux.uml{.tmp,}  # Atomic replace.
ls -l uevalrun.linux.xml

# Full compile and extract time on narancs:
# 118.13user 14.18system 2:24.38elapsed 91%CPU (0avgtext+0avgdata 80528maxresident)k
# 4936inputs+1118032outputs (58major+2190404minor)pagefaults 0swaps


: All OK.
