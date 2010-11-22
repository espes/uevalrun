#! /bin/bash --
# by pts@fazekas.hu at Sat Nov 20 16:42:03 CET 2010
set -ex
test "$EUID" = 0
dd if=/dev/zero of=uevalrun.rootfs.ext2.img bs=800K count=1
mkfs.ext2 -F uevalrun.rootfs.ext2.img
umount rp || true
rm -rf rp
mkdir -p rp
mount -o loop uevalrun.rootfs.ext2.img rp
mkdir rp/{dev,bin,sbin,proc,etc}
mkdir rp/etc/init.d
cat >rp/etc/init.d/rcS <<'END'
#! /bin/sh
/bin/mount proc /proc -t proc
END
chmod +x rp/etc/init.d/rcS
cp -a /dev/console rp/dev/
cp -a /dev/ttyS0 rp/dev/
cp -a /dev/ttyS1 rp/dev/
cp -a /dev/tty0 rp/dev/
cp -a /dev/tty1 rp/dev/
cp -a /dev/tty2 rp/dev/
cp -a /dev/tty3 rp/dev/
cp -a /dev/tty4 rp/dev/
cp -a /dev/null rp/dev/
cp -a /dev/zero rp/dev/
mknod rp/dev/ubdb b 98 16
mknod rp/dev/ubdc b 98 32
mknod rp/dev/ubdd b 98 48
chmod 711 rp/dev/ubdb
chmod 600 rp/dev/ubdc
chmod 700 rp/dev/ubdd
cp busybox rp/bin
# cp hello bincat rp/bin  # Custom binaries.
ln -s ../bin/busybox rp/sbin/init
ln -s ../bin/busybox rp/sbin/halt
ln -s ../bin/busybox rp/sbin/reboot
ln -s ../bin/busybox rp/sbin/swapoff
ln -s ../bin/busybox rp/bin/mount
ln -s ../bin/busybox rp/bin/umount
ln -s ../bin/busybox rp/bin/sh
ln -s ../bin/busybox rp/bin/ls
ln -s ../bin/busybox rp/bin/mkdir
ln -s ../bin/busybox rp/bin/rmdir
ln -s ../bin/busybox rp/bin/cp
ln -s ../bin/busybox rp/bin/mv
ln -s ../bin/busybox rp/bin/rm
ln -s ../bin/busybox rp/bin/du
ln -s ../bin/busybox rp/bin/df
ln -s ../bin/busybox rp/bin/awk
ln -s ../bin/busybox rp/bin/sed
ln -s ../bin/busybox rp/bin/cat
ln -s ../bin/busybox rp/bin/vi
ln -s ../bin/busybox rp/bin/stty
umount rp || true
