AC_PREREQ(2.59)
AC_INIT(warewulf-cluster, 3.8.1, warewulf-devel@lbl.gov)
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

dnl Make it so we can do @[SOMEVAR]@ in a file and
dnl   have it replaced with the configured path for
dnl   any of the main variables
dnl
dnl We do it through an eval call, as otherwise the
dnl   the variable is something like:
dnl       ${prefix}/var
dnl   and ${prefix} was never expanded.
AS_IF([test -n $localstatedir], [
    eval $(echo dir=$localstatedir)
    AC_SUBST(LOCALSTATEDIR, $dir)
])

dnl# Get git version
GITVERSION=`cat .gitversion | tr -d '\n'`
AC_SUBST(GITVERSION)

AC_OUTPUT(
   Makefile
   warewulf-cluster.spec
   bin/Makefile
   etc/Makefile
   lib/Makefile
   lib/Warewulf/Makefile
   lib/Warewulf/Module/Makefile
   lib/Warewulf/Module/Cli/Makefile
   libexec/Makefile
   libexec/wwinit/Makefile
   libexec/wwfirstboot/Makefile
)

