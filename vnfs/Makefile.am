SUBDIRS = lib bin etc libexec share

MAINTAINERCLEANFILES = Makefile.in aclocal.m4 configure compile config.* ltmain.sh install-sh missing
DISTCLEANFILES = 
CLEANFILES = 
EXTRA_DIST = warewulf-vnfs.spec LICENSE .gitversion

# Fix for make distcheck
DISTCHECK_CONFIGURE_FLAGS = --with-perllibdir=$$dc_install_base/perllibs
