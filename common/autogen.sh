#!/bin/sh

if autoreconf -V >/dev/null 2>&1 ; then
    set -x
    autoreconf -f -i
else
    set -x
    aclocal
    autoconf
    automake -ca -Wno-portability
fi

git show -s --pretty=format:%h > .gitversion

if [ -z "$NO_CONFIGURE" ]; then
   ./configure "$@"
fi

