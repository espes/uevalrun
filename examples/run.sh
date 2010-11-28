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
elif test "$1" = php; then
  ../uevalrun -M 32 -T 3 -E 20 -s scat.php -t answer.in -e answer.exp
elif test "$1" = perl; then
  ../uevalrun -M 32 -T 3 -E 20 -s scat.pl -t answer.in -e answer.exp
elif test "$1" = gcc; then
  ../uevalrun -M 3 -T 9 -E 20 -s scat.c  -C 2 -N 32 -U 10 -t answer.in -e answer.exp
elif test "$1" = gxx; then
  ../uevalrun -M 3 -T 9 -E 20 -s scat.cc -C 2 -N 32 -U 20 -t answer.in -e answer.exp
elif test "$1" = long; then
  perl scatlong.pl >long.exp  # TODO(pts): Do this without Perl.
  ../uevalrun -M 32 -T 3 -E 20 -s scatlong.pl -t answer.in -e long.exp
elif test "$#" = 1; then
  $CC -W -Wall -s -O2 -static -o xcat xcat.c
  ../uevalrun -M 3 -T 3 -E 20 -s xcat -t answer.in -e answer.bad.exp
else
  $CC -W -Wall -s -O2 -static -o xcat xcat.c
  ../uevalrun -M 3 -T 3 -E 20 -s xcat -t answer.in -e answer.exp
fi
