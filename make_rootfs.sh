#! /bin/bash --
#
# make_rootfs.sh: Create the ext2 root filesystem for uevalrun UML guests
# by pts@fazekas.hu at Sat Nov 20 16:42:03 CET 2010
#
set -ex

test "${0%/*}" != "$0" && cd "${0%/*}"

test -f busybox
BUSYBOX_KB=$(./busybox ls -l busybox | ./busybox awk '{printf "%d", (($5+1024)/1024)}')
test "$BUSYBOX_KB"
let MINIX_KB=60+BUSYBOX_KB

rm -f uevalrun.rootfs.minix.img  # Make sure it's not mounted.
./busybox dd if=/dev/zero of=uevalrun.rootfs.minix.img bs=${MINIX_KB}K count=1
# Increase `-i 100' here to increase the file size limit if you get a
# `No space left on device' when running this script.
./busybox mkfs.minix -n 14 -i 100 uevalrun.rootfs.minix.img

./busybox tar cvf mkroot.tmp.tar busybox
cat >mkroot.tmp.sh <<'ENDMKROOT'
#! /bin/sh
# Don't autorun /sbin/halt, so we'll get a kernel panic in the UML guest,
# thus we'll get a nonzero exit code in the UML host if this script fails.
#trap /sbin/halt EXIT
set -ex
echo "Hello, World!"
#ls /proc  # Works.

mkdir /fs/dev /fs/bin /fs/sbin /fs/proc /fs/etc
mkdir /fs/etc/init.d
cat >/fs/etc/init.d/rcS <<'END'
#! /bin/sh
/bin/mount proc /proc -t proc
END
chmod +x /fs/etc/init.d/rcS
cp -a /dev/console /fs/dev/
cp -a /dev/ttyS0 /fs/dev/
cp -a /dev/ttyS1 /fs/dev/
cp -a /dev/tty0 /fs/dev/
cp -a /dev/tty1 /fs/dev/
cp -a /dev/tty2 /fs/dev/
cp -a /dev/tty3 /fs/dev/
cp -a /dev/tty4 /fs/dev/
cp -a /dev/null /fs/dev/
cp -a /dev/zero /fs/dev/
mknod /fs/dev/ubdb b 98 16
mknod /fs/dev/ubdc b 98 32
mknod /fs/dev/ubdd b 98 48
chmod 711 /fs/dev/ubdb
chmod 600 /fs/dev/ubdc
chmod 700 /fs/dev/ubdd
(cd /fs && tar xf /dev/ubdd)  # creates /fs/busybox
mv /fs/busybox /fs/bin/busybox
# cp hello bincat /fs/bin  # Custom binaries.
ln -s ../bin/busybox /fs/sbin/init
ln -s ../bin/busybox /fs/sbin/halt
ln -s ../bin/busybox /fs/sbin/reboot
ln -s ../bin/busybox /fs/sbin/swapoff
ln -s ../bin/busybox /fs/bin/mount
ln -s ../bin/busybox /fs/bin/umount
ln -s ../bin/busybox /fs/bin/sh
ln -s ../bin/busybox /fs/bin/ls
ln -s ../bin/busybox /fs/bin/mkdir
ln -s ../bin/busybox /fs/bin/rmdir
ln -s ../bin/busybox /fs/bin/cp
ln -s ../bin/busybox /fs/bin/mv
ln -s ../bin/busybox /fs/bin/rm
ln -s ../bin/busybox /fs/bin/du
ln -s ../bin/busybox /fs/bin/df
ln -s ../bin/busybox /fs/bin/awk
ln -s ../bin/busybox /fs/bin/sed
ln -s ../bin/busybox /fs/bin/cat
ln -s ../bin/busybox /fs/bin/vi
ln -s ../bin/busybox /fs/bin/stty

: guest-creator script OK, halting.
/sbin/halt
ENDMKROOT

# Use the ext2 driver in uevalrun.linux.uml to populate our rootfs
# (uevalrun.rootfs.minix.img).
./uevalrun.linux.uml con=null ssl=null con0=fd:0,fd:1 mem=10M \
    ubda=uevalrun.rootfs.mini.minix.img ubdb=uevalrun.rootfs.minix.img \
    ubdc=mkroot.tmp.sh ubdd=mkroot.tmp.tar init=/sbin/halt
# TODO(pts): Detect if the shell script has succeeded.
rm -f mkroot.tmp.sh mkroot.tmp.tar

: make_rootfs.sh OK.
