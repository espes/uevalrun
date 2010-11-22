#! /bin/bash --
set -ex
if i386-uclibc-gcc -v >/dev/null 2>&1; then
  CC='i386-uclibc-gcc -static'
else
  CC='gcc -static'
fi
$CC -W -Wall -s -O2 -static -o xcat xcat.c
make -C ..
../uevalrun -M 32 -T 3 -E 20 -s xcat -t answer.in -e answer.exp
