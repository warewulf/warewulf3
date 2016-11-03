SUBDIRS = lib share etc bin libexec

MAINTAINERCLEANFILES = Makefile.in aclocal.m4 configure compile config.* install-sh missing
DISTCLEANFILES = 
CLEANFILES = 
EXTRA_DIST = warewulf-common.spec LICENSE

# Fix for make distcheck
DISTCHECK_CONFIGURE_FLAGS = --with-perllibdir=$$dc_install_base/perllibs

TESTVERBOSE=0

test: all
	perl -I$(srcdir)/lib -MTest::Harness -e '$$Test::Harness::verbose='$(TESTVERBOSE)'; runtests(@ARGV);' t/*.t

test-verbose:
	$(MAKE) test TESTVERBOSE=1
