AC_PREREQ(2.59)
AC_INIT(warewulf-vnfs, 3.7, warewulf-devel@lbl.gov)
AC_CONFIG_SRCDIR([.])

AC_PROG_INSTALL
AM_INIT_AUTOMAKE([foreign])

AC_PATH_PROG(PERLBIN, perl)
if test -z "$PERLBIN"; then
   AC_MSG_ERROR([perl not found])
fi
AC_SUBST(PERLBIN)

AC_MSG_CHECKING(for Perl vendor lib path)
eval `perl -V:installvendorlib`
PERL_VENDORLIB=$installvendorlib
AC_ARG_WITH(perllibdir, [  --with-perllibdir=path  Manually specify where the perl modules should go], [
if test -n "$withval" -a "x$withval" != "xno" ; then
   PERL_VENDORLIB=$withval
fi
])
AC_MSG_RESULT($PERL_VENDORLIB)
AC_SUBST(PERL_VENDORLIB)


AC_SUBST(PERLBIN)

dnl# Try to get SVN revision
SVNVERSION=`svnversion -c | sed 's/^.*://g' 2>/dev/null || echo 0000`
if test "$SVNVERSION" = "0000" ; then
    SVNVERSION=`svnversion 2>/dev/null || echo 0000`
elif test "$SVNVERSION" = "exported" -o "$SVNVERSION" = "Unversioned directory" ; then
    SVNVERSION=`git show -s --pretty=format:%h 2>/dev/null`
    if test -n "$SVNVERSION" ; then
        SVNVERSION=`git svn find-rev $SVNVERSION`
        if test $? -eq 0 ; then
            if test -z "$SVNVERSION" ; then
                for REV in 1 2 3 4 5 6 7 8 9 10 ; do
                    SVNVERSION=`git svn find-rev HEAD~$REV`
                    test -n "$SVNVERSION" && break
                done
            fi
            if test -n "$SVNVERSION" ; then
                git diff --no-ext-diff --quiet --exit-code || SVNVERSION="${SVNVERSION}M"
            fi
        fi
    fi
    if test -z "$SVNVERSION" ; then
        SVNVERSION="0000"
    fi
fi
AC_SUBST(SVNVERSION)

AC_OUTPUT(Makefile
   warewulf-vnfs.spec
   bin/wwmkchroot
   bin/Makefile
   etc/Makefile
   etc/wwmkchroot/Makefile
   lib/Makefile
   lib/Warewulf/Makefile
   libexec/Makefile
   libexec/wwmkchroot/Makefile
)

