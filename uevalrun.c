/*
 * uevalrun.c: Entry point executable for running solutions sandboxed.
 *
 * by pts@fazekas.hu at Sun Nov 21 20:00:22 CET 2010
 * --- Mon Nov 22 01:44:59 CET 2010
 *
 * This program is free software; you can redistribute it and/or modify   
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * TODO(pts): don't lock the block devices in UML (read-only)
 * * we have to set: CONFIG_HIGH_RES_TIMERS=y
 *   to avoid this kernel syslog message: Switched to NOHz mode on CPU #0
 */
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/resource.h>
#include <sys/signal.h>
#include <sys/wait.h>
#include <unistd.h>

#define ELF_SHF_ALLOC (1 << 1)

enum {
  ST_MIDLINE = 1,
  ST_BOL = 2,
};

#define PTS_ISDIGIT(c) ((c) - '0' + 0U <= 9U)

static void out_of_memory() {
  printf("@ error: out of memory\n");
  exit(2);
}

static char *xstrcat(char const *s1, char const *s2) {
  size_t ss1 = strlen(s1);
  char *t = malloc(ss1 + strlen(s2) + 1);
  if (t == NULL)
    out_of_memory();
  memcpy(t, s1, ss1);
  strcpy(t + ss1, s2);
  return t;
}

#if 0
static char *xstrcat3(char const *s1, char const *s2, char const *s3) {
  size_t ss1 = strlen(s1);
  size_t ss2 = strlen(s2);
  char *t = malloc(ss1 + ss2 + strlen(s3) + 1);
  if (t == NULL)
    out_of_memory();
  memcpy(t, s1, ss1);
  memcpy(t + ss1, s2, ss2);
  strcpy(t + ss1 + ss2, s3);
  return t;
}
#endif

static char *xslice(const char *s, size_t slen) {
  char *t = malloc(slen + 1);
  if (t == NULL)
    out_of_memory();
  memcpy(t, s, slen);
  t[slen] = '\0';
  return t;
}

static void usage(const char* argv0) {
  printf("@ info: usage: %s -M <mem_mb> -T <timeout> "
         "-E <excess_answer_limit_kb> -s <solution_binary> "
         "-t <test_input> -e <expected_output>\n", argv0);
}

int main(int argc, char** argv) {
  char mismatch_msg[128];
  char state;
  int pfd[2];
  int status;
  pid_t child;
  FILE *f, *fexp;
  int i, j, n, line, col, opt;
  int answer_remaining;
  char *args[16];
  char *envs[] = {NULL};
  char memarg[16];
  char *prog_dir;
  char *uml_linux_path;
  char *uml_rootfs_path;
  char *guestinit_path;

  int mem_mb = -1; /* -M */
  int timeout = -1;  /* -T */
  int excess_answer_limit_kb = -1; /* -E */
  char *solution_binary = NULL;  /* -s */
  char *test_input = NULL; /* -t */
  char *expected_output = NULL; /* -e */

  (void)argc; (void)argv;

  /* In our design, uevalrun writes everything to stdout (nothing to stderr),
   * so it can be easily redirected, and redirection order is predicatble.
   */
  setbuf(stdout, NULL);

  if (argv[1] == NULL) {
    usage(argv[0]);
    return 1;
  }
  if (0 == strcmp(argv[1], "--help")) {
    usage(argv[0]);
    return 0;
  }

  while ((opt = getopt(argc, argv, "M:T:E:s:t:e:h")) != -1) {
    if (opt == 'M') {
      if (1 != sscanf(optarg, "%i", &mem_mb)) {
        printf("@ error: bad -M syntax\n");
        return 1;
      }
    } else if (opt == 'T') {
      if (1 != sscanf(optarg, "%i", &timeout)) {
        printf("@ error: bad -T syntax\n");
        return 1;
      }
    } else if (opt == 'E') {
      if (1 != sscanf(optarg, "%i", &excess_answer_limit_kb)) {
        printf("@ error: bad -E syntax\n");
        return 1;
      }
    } else if (opt == 's') {
      if (optarg[0] == '\0') {
        printf("@ error: bad -s syntax\n");
        return 1;
      }
      solution_binary = optarg;
    } else if (opt == 't') {
      if (optarg[0] == '\0') {
        printf("@ error: bad -t syntax\n");
        return 1;
      }
      test_input = optarg;
    } else if (opt == 'e') {
      if (optarg[0] == '\0') {
        printf("@ error: bad -t syntax\n");
        return 1;
      }
      expected_output = optarg;
    } else {
      printf("@ error: unknown command-line flag\n");
      usage(argv[0]);
      return 1;
    }
  }
  if (optind < argc) {
    printf("@ error: too many command-line arguments\n");
    usage(argv[0]);
    return 1;
  }
  if (mem_mb < 0) {
    printf("@ error: missing -M\n");
    usage(argv[0]);
    return 1;
  }
  if (timeout < 0) {
    printf("@ error: missing -T\n");
    usage(argv[0]);
    return 1;
  }
  if (excess_answer_limit_kb < 0) {
    printf("@ error: missing -E\n");
    usage(argv[0]);
    return 1;
  }
  if (solution_binary == NULL) {
    printf("@ error: missing -s\n");
    usage(argv[0]);
    return 1;
  }
  if (test_input == NULL) {
    printf("@ error: missing -t\n");
    usage(argv[0]);
    return 1;
  }
  if (expected_output == NULL) {
    printf("@ error: missing -e\n");
    usage(argv[0]);
    return 1;
  }

  i = strlen(argv[0]);
  while (i > 0 && argv[0][i - 1] != '/')
    --i;
  if (i > 0)  /* prog_dir = "" means "/" */
    prog_dir = xslice(argv[0], i - 1);

  if (NULL == (fexp = fopen(expected_output, "r"))) {
    printf("@ error: open expected output: %s: %s\n", expected_output,
            strerror(errno));
    return 2;
  }

  if (NULL == (f = fopen(solution_binary, "r"))) {
    printf("@ error: open solution binary: %s: %s\n", solution_binary,
            strerror(errno));
    return 2;
  }
  { char elf_hdr[52];  /* Only applies to 32-bit ELF files */
    unsigned char *u;
    unsigned long sh_ofs;  /* Section header table offset */
    unsigned long flags;
    unsigned long long total_memsize;
    int sh_entsize;  /* Section header table entry size */
    int sh_num;  /* Section header table entry count */
    if (52 != fread(elf_hdr, 1, 52, f)) {
      printf("@ error: solution binary too small, cannot be ELF: %s\n",
             solution_binary);
      /* TODO(pts): fclose(f); fclose(fexp); everywhere */
      return 2;
    }
    if (0 != memcmp(elf_hdr, "\177ELF", 4)) {
      printf("@ error: solution binary not an ELF file (by magic): %s\n",
             solution_binary);
      return 2;
    }
    if (elf_hdr[4] != 1) {
      printf("@ error: solution binary not for 32-bit architecture: %s\n",
             solution_binary);
      return 2;
    }
    if (elf_hdr[5] != 1) {
      printf("@ error: solution binary not for LSB architecture: %s\n",
             solution_binary);
      return 2;
    }
    if (elf_hdr[16] != 2 || elf_hdr[17] != 0) {
      printf("@ error: solution binary not an executable: %s\n",
             solution_binary);
      return 2;
    }
    if (elf_hdr[18] != 3 || elf_hdr[19] != 0) {
      printf("@ error: solution binary not for x86 architecture: %s\n",
             solution_binary);
      return 2;
    }
    if (elf_hdr[20] != 1) {
      printf("@ error: solution binary not version 1: %s\n",
             solution_binary);
      return 2;
    }
    if ((elf_hdr[7] != 0 && elf_hdr[7] != 3) || elf_hdr[8] != 0) {
      printf("@ error: solution binary not for Linux: %s\n",
             solution_binary);
      return 2;
    }
    u = (unsigned char*)elf_hdr + 32;
    sh_ofs = u[0] | (u[1] << 8) | (u[2] << 16) | (u[3] << 24);
    u = (unsigned char*)elf_hdr + 46;
    sh_entsize = u[0] | (u[1] << 8);
    sh_num = u[2] | (u[3] << 8);
    printf("@ info: sh_ofs=%lu sh_entsize=%d sh_num=%d\n",
           sh_ofs, sh_entsize, sh_num);
    if (sh_entsize + 0U > sizeof(elf_hdr)) {
      printf("@ error: solution binary sh_entsize too large: %s: %d\n",
             solution_binary, sh_entsize);
      return 2;
    }
    if (sh_num < 1) {
      printf("@ error: solution binary sh_num too small: %s: %d\n",
             solution_binary, sh_num);
      return 2;
    }
    if (0 != fseek(f, sh_ofs, SEEK_SET)) {
      printf("@ error: cannot seek to sh_ofs: %s: %lu: %s\n",
             solution_binary, sh_ofs, strerror(errno));
      return 2;
    }
    total_memsize = 0;
    for (i = 0; i < sh_num; ++i) {
      if (sh_entsize + 0U != fread(elf_hdr, 1, sh_entsize, f)) {
        printf("@ error: cannot read section header in solution binary: "
               "%s: %d/%d: %s\n",
               solution_binary, i, sh_num, strerror(errno));
        return 2;
      }
      u = (unsigned char*)elf_hdr + 8;
      flags = u[0] | (u[1] << 8) | (u[2] << 16) | (u[3] << 24);
      if ((flags & ELF_SHF_ALLOC) != 0) {
        u = (unsigned char*)elf_hdr + 20;
        total_memsize += u[0] | (u[1] << 8) | (u[2] << 16) | (u[3] << 24);
      }
    }
    if ((total_memsize >> 31) != 0) {
      printf("@ result: memory exceeded, needs way too static memory\n");
      return 3;
    }
    if (((total_memsize + ((1 << 20) - 1)) >> 20) >= mem_mb + 0U) {
      printf("@ result: memory exceeded, needs too much static memory: %ldMB\n",
             (long)((total_memsize + ((1 << 20) - 1)) >> 20));
      return 3;
    }
    printf("@ info: total_memsize=%ldM\n",
           (long)((total_memsize + ((1 << 20) - 1)) >> 20));
  }
  fclose(f);

  if (mem_mb < 1 || mem_mb > 2000) {
    /* 4096MB is the absolute hard limit, since our UML is a 32-bit binary. */
    printf("@ error: expected 1 <= mem_mb <= 2000, got %d\n", mem_mb);
    return 2;
  }

  guestinit_path = xstrcat(prog_dir, "/uevalrun.guestinit");
  if (NULL == (f = fopen(guestinit_path, "r"))) {
    printf("@ error: guestinit not found: %s: %s\n",
           guestinit_path, strerror(errno));
    return 2;
  }
  fclose(f);

  uml_linux_path = xstrcat(prog_dir, "/uevalrun.linux.uml");
  if (NULL == (f = fopen(uml_linux_path, "r"))) {
    printf("@ error: uml_linux not found: %s: %s\n",
           uml_linux_path, strerror(errno));
    return 2;
  }
  fclose(f);

  uml_rootfs_path = xstrcat(prog_dir, "/uevalrun.rootfs.ext2.img");
  if (NULL == (f = fopen(uml_linux_path, "r"))) {
    printf("@ error: uml_linux not found: %s: %s\n",
           uml_linux_path, strerror(errno));
    return 2;
  }
  fclose(f);

  /* 6MB is needed by the UML kernel and its buffers. It wouldn't work with
   * 5MB (probed).
   */
  sprintf(memarg, "mem=%dM", mem_mb + 6);

  i = 0;
  args[i++] = uml_linux_path;
  args[i++] = "con=null";
  args[i++] = "ssl=null";
  args[i++] = "con0=fd:-1,fd:1";
  args[i++] = memarg;
  args[i++] = xstrcat("ubda=", uml_rootfs_path);
  args[i++] = xstrcat("ubdb=", solution_binary);
  /* TODO(pts): Verify that test_input etc. don't contain comma, space or
   * something UML would interpret.
   */
  args[i++] = xstrcat("ubdc=", test_input);
  args[i++] = xstrcat("ubdd=", guestinit_path);
  args[i++] = "init=/dev/ubdd";
  args[i] = NULL;

  if (0 != pipe(pfd)) {
    printf("@ error: pipe: %s\n", strerror(errno));
    return 2;
  }
  
  child = fork();
  if (child < 0) {
    printf("@ error: fork: %s\n", strerror(errno));
    return 2;
  }
  if (child == 0) {  /* Child */
    int fd;
    struct rlimit rl;
    close(0);
    close(pfd[0]);
    close(fileno(fexp));
    close(1);
    close(2);  /* TODO(pts): Report the errors nevertheless */
    if (0 <= (fd = open("/dev/tty", O_RDWR))) {
      ioctl(fd, TIOCNOTTY, 0);
      close(fd);
    }
    if ((pid_t)-1 == setsid())  /* Create a new process group (UML needs it). */
      exit(122);
    fd = open("/dev/null", O_RDONLY);
    if (fd != 0) {
      dup2(fd, 0);
      close(fd);
    }
    fd = open("/dev/null", O_WRONLY);
    if (fd != 2) {
      dup2(fd, 2);
      close(fd);
    }
    if (pfd[1] != 1) {
      if (1 != dup2(pfd[1], 1)) {
        printf("@ error: child: dup2: %s\n", strerror(errno));
        exit(121);
      }
      close(pfd[1]);
    }
    alarm(timeout + 3 + timeout / 10);
    /* UML needs more than 300 processes. This will be restricted to 0
     * just before the execve(...) to the temp binary.
     */
    rl.rlim_cur = 400;
    rl.rlim_max = 400; /* hard limit */
    setrlimit(RLIMIT_NPROC, &rl);
    rl.rlim_cur = 0;
    rl.rlim_max = 0;
    setrlimit(RLIMIT_CORE, &rl);
    rl.rlim_cur = timeout;
    rl.rlim_max = timeout + 2;
    /* This applies to all UML host subprocesses, but most of them don't
     * consume much CPU time, so this global limit should be fine.
     *
     * We don't want to impose this limit in the guest, because its timer
     * might not be accurate enough.
     */
    setrlimit(RLIMIT_CPU, &rl);
    execve(args[0], args, envs);
    printf("@ error: child: execve: %s\n", strerror(errno));
    exit(121);
  }
  close(pfd[1]);
  if (NULL == (f = fdopen(pfd[0], "r"))) {
    printf("@ error: read fdopen: %s\n", strerror(errno));
    return 2;
  }

  state = ST_MIDLINE;
  mismatch_msg[0] = '\0';
  line = 1;
  col = 1;
  answer_remaining = -1;
  /* TODO(pts): Limit the size of the answer */
  while (0 <= (i = getc(f))) {
    if (state == ST_MIDLINE) {
      while (i != '\n') {
        putchar(i);
        if (0 > (i = getc(f)))
          goto at_eof;
      }
      state = ST_BOL;
    }
    if (state == ST_BOL) {
      while (i == '\n') {
        putchar(i);
        if (0 > (i = getc(f)))
          goto at_eof;
      }
      if (!PTS_ISDIGIT(i) || i == '0') {
       at_badhead:
        putchar(i);
        state = i == '\n' ? ST_BOL : ST_MIDLINE;
        continue;
      }
      putchar(i);
      n = i - '0';
      while (1) {
        if (0 > (i = getc(f)))
          goto at_eof;
        if (!PTS_ISDIGIT(i))
          break;
        if (n > 9999)
          goto at_badhead;  /* Buffer size too long (would be >= 100000) */
        putchar(i);
        n = n * 10 + i - '0';
      }
      if (i != '>')
        goto at_badhead;
      putchar(i);
      /* Now read n bytes as the output of the solution. */
      for (; n > 0; --n) {
        if (0 > (i = getc(f)))
          goto at_eof;
        if (mismatch_msg[0] == '\0') {
          if (0 > (j = getc(fexp))) {
            answer_remaining = excess_answer_limit_kb << 10;
            sprintf(mismatch_msg, "@ result: wrong answer, .exp is shorter at %d:%d\n", line, col);
          } else if (i != j) {
            sprintf(mismatch_msg, "@ result: wrong answer, first mismatch at %d:%d\n", line, col);
          }
        }
        if (answer_remaining >= 0) {
          if (answer_remaining-- == 0) {
            /* TODO(pts): Limit the length> already emitted. */
            printf("\n@ info: excess answer limit exceeded\n");
            goto at_eof_nl;
          }
        }
        putchar(i);
        if (i == '\n') {
          state = ST_BOL;
          ++line;
          col = 1;
        } else {
          state = ST_MIDLINE;
          ++col;
        }
      }
      state = ST_BOL;
    }
  }
 at_eof:
  if (state == ST_MIDLINE)
    putchar('\n');
 at_eof_nl:
  if (mismatch_msg[0] == '\0' && !feof(fexp) && 0 <= (j = getc(fexp))) {
    sprintf(mismatch_msg, "@ result: wrong answer, .exp is longer at %d:%d\n", line, col);
  }
  if (ferror(fexp)) {
    printf("@ error: error reading .exp file\n");
    return 2;
  }
  fclose(fexp);
  if (ferror(f)) {
    printf("@ error: error reading from solution output pipe\n");
    return 2;
  }
  fclose(f);
  
  while (child != waitpid(child, &status, 0)) {}

  if (status != 0) {
    if (mismatch_msg[0] == '\0') {
      printf("@ FYI, output matches\n");
    } else {
      memcpy(mismatch_msg, "@ FYI   ", 8);
      fputs(mismatch_msg, stdout);  /* emit previous mismatch */
    }
    if (WIFSIGNALED(status) && WTERMSIG(status) == SIGALRM) {
      printf("@ result: time limit exceeded, wall time\n");
    } else if (status == 0x300) {
      printf("@ result: time limit exceeded, user time\n");
    } else if (status == 0x200) {
      printf("@ result: static memory limit exceeded\n");
    } else if (status == 0x100) {
      /* Non-zero exit code or killed by signal. */
      printf("@ result: runtime error\n");
    } else {
      printf("@ result: framework error, status: 0x%x\n", status);
    }
    return 3;
  }
  if (mismatch_msg[0] != '\0') {
    fputs(mismatch_msg, stdout);
    return 3;
  }
  printf("@ result: pass\n");
  return 0;
}
