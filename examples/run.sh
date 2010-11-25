#! /bin/bash --
set -ex
test "${0%/*}" != "$0" && cd "${0%/*}"
if test "$CC"; then
  :
elif i386-uclibc-gcc -v >/dev/null 2>&1; then
  CC='i386-uclibc-gcc -static'
else
  CC='gcc -static'
fi
../make -C ..
if test "$1" = python; then
  ../uevalrun -M 32 -T 3 -E 20 -s scat.py -t answer.in -e answer.exp
elif test "$1" = ruby; then
  ../uevalrun -M 32 -T 3 -E 20 -s scat.rb -t answer.in -e answer.exp
elif test "$#" = 1; then
  $CC -W -Wall -s -O2 -static -o xcat xcat.c
  ../uevalrun -M 32 -T 3 -E 20 -s xcat -t answer.in -e answer.bad.exp
else
  $CC -W -Wall -s -O2 -static -o xcat xcat.c
  ../uevalrun -M 32 -T 3 -E 20 -s xcat -t answer.in -e answer.exp
fi
