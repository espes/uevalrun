#! /bin/bash --
#
# make_root_fs_mini.sh: create the mini filesystem
# by pts@fazekas.hu at Wed Nov 24 02:04:14 CET 2010
#
# The mini filesystem is used for bootstrapping the real filesystem creation.
#
# Creating the mini filesystem needs root privileges, but then it can be
# redistributed.

set -ex

test "${0%/*}" != "$0" && cd "${0%/*}"

test -f busybox
BUSYBOX_KB=$(ls -l busybox.mini | ./busybox awk '{printf "%d", (($5+1024)/1024)}')
test "$BUSYBOX_KB"
let EXT2_KB=303+BUSYBOX_KB
let BYTES_PER_INODE=3\*EXT2_KB

rm -f uevalrun.rootfs.mini.ext2.img  # Make sure it's not mounted.
./busybox dd if=/dev/zero of=uevalrun.rootfs.mini.ext2.img bs=${EXT2_KB}K count=1
./busybox mkfs.ext2 -i "$BYTES_PER_INODE" -F uevalrun.rootfs.mini.ext2.img

test "$EUID" = 0
umount rp || true
rm -rf rp
mkdir -p rp
mount -o loop uevalrun.rootfs.mini.ext2.img rp
mkdir rp/{dev,bin,sbin,proc,fs}
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

cp busybox.mini rp/bin/busybox
for CMD in \
  mount umount [ [[ ash awk cat chgrp chmod chown cmp cp dd echo egrep \
  expr false fgrep grep install ls ln mkdir mkfifo mknod mv \
  pwd readlink realpath rm rmdir sh sync tar  \
  test true uncompress wc xargs yes \
; do
  ln -s ../bin/busybox rp/bin/"$CMD"
done

# busybox can't halt without /proc, so we'll use minihalt
#ln -s ../bin/busybox rp/sbin/haltt
if test -x minihalt; then
  cp minihalt rp/sbin/halt
else
  test -x precompiled/minihalt
  cp precompiled/minihalt rp/sbin/halt
fi

umount rp || true
: make_rootfs_mini.sh OK.
