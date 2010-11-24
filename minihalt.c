/* by pts@fazekas.hu at Wed Nov 24 02:14:18 CET 2010 */
/* i386-uclibc-gcc -s -static -W -Wall -o minihalt minihalt.c */
/* TODO(pts): Make this binary smaller by writing assembly code. */
#include <unistd.h>
#include <sys/reboot.h>
extern char** environ;
int main() {
  if (getpid() == 1) {
    char *args[] = { "/bin/sh", "/dev/ubdc", NULL };
    return execve("/bin/sh", args, environ);
  }
  sync();
  return reboot(RB_HALT_SYSTEM);
}
