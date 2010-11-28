#! /bin/bash --
#
# download.sh: Download external components for uevalrun.
# by pts@fazekas.hu at Sun Nov 28 12:08:05 CET 2010
#

download_stbx86_pkg() {
  local F="$1.stbx86.tbz2"  # e.g. F=gcc.stbx86.tbz2
  if ! test -f "$F.downloaded"; then
    ./busybox wget -c -O "$F" \
        http://pts-mini-gpl.googlecode.com/svn/trunk/stbx86/"$F"
    ./busybox touch "$F".downloaded
  fi
  test -s "$F"
}

set +x -e

test "${0%/*}" != "$0" && cd "${0%/*}"

# Make sure we fail unless weuse ./busybox for all non-built-in commands.
export PATH=/dev/null

if ! test -f busybox; then
  echo "errnor: $PWD/busybox: not found" >&2
fi

for F in "$@"; do
  if test -f "$F.downloaded"; then
    if test -s "$F"; then
      echo "info: already downloaded: $F" >&2
      continue
    fi
    rm -f "$F"  # Remove empty file.
  fi
  echo "info: downloading: $F" >&2
  if test "${F%.stbx86.tbz2}" != "$F"; then
    set -x
    download_stbx86_pkg "${F%.stbx86.tbz2}"
    set +x
  elif test "$F" = php5.3 ||
       test "$F" = perl5.10 ||
       test "$F" = ruby1.8 ||
       test "$F" = ruby1.9 ||
       test "$F" = stackless2.7 ||
       test "$F" = python2.7; then
    set -x
    download_stbx86_pkg "$F"
    ./busybox tar -Oxjf "$F".stbx86.tbz2 bin/"$F" >"$F"
    ./busybox chmod +x "$F"
    ./busybox touch "$F".downloaded
    set +x
  else
    set +x
    echo "error: unknown download target: $F" >&2
    exit 2
  fi
  if ! test -s "$F"; then
    rm -f "$F"
    echo "info: download failed: $F" >&2
    exit 3
  fi
done

echo "info: all downloads OK" >&2
