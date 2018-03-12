AC_PREREQ(2.59)
AC_INIT(warewulf-vnfs, 3.8.1, warewulf-devel@lbl.gov)
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

dnl# Get git version
GITVERSION=`cat .gitversion | tr -d '\n'`
AC_SUBST(GITVERSION)

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
   share/Makefile
)

