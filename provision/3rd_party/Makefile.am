SUBDIRS = GPL BSD

SYSLINUXTARGETS = pcbios/lpxelinux.0 pcbios/pxelinux.0 pcbios/ldlinux.c32 x86_64-efi/syslinux.efi x86_64-efi/ldlinux.e64 i386-efi/syslinux.efi i386-efi/ldlinux.e32

MAINTAINERCLEANFILES = Makefile.in

MACHINE:=$(shell uname -m)

all: $(SYSLINUXTARGETS)

SYSLINUX_VERSION = 6.04-pre1
SYSLINUX_SOURCE = $(top_srcdir)/3rd_party/GPL/syslinux-$(SYSLINUX_VERSION).tar.gz
SYSLINUX_DIR = syslinux-$(SYSLINUX_VERSION)


syslinuxprepare:
	@ if [ ! -d "_work/$(SYSLINUX_DIR)" ]; then \
		echo "Extracting syslinux distribution" ;\
		mkdir -p _work/ ;\
		tar xzf $(SYSLINUX_SOURCE) -C _work/ ;\
	fi
	touch prepare

pcbios/lpxelinux.0: syslinuxprepare
	mkdir -p pcbios
	cp _work/$(SYSLINUX_DIR)/bios/core/lpxelinux.0 pcbios/lpxelinux.0

pcbios/ldlinux.c32: syslinuxprepare
	mkdir -p pcbios
	cp _work/$(SYSLINUX_DIR)/bios/com32/elflink/ldlinux/ldlinux.c32 pcbios/ldlinux.c32

i386-efi/ldlinux.e32: syslinuxprepare
	mkdir -p i386-efi
	cp _work/$(SYSLINUX_DIR)/efi32/com32/elflink/ldlinux/ldlinux.e32 i386-efi/ldlinux.e32

x86_64-efi/ldlinux.e64: syslinuxprepare
	mkdir -p x86_64-efi
	cp _work/$(SYSLINUX_DIR)/efi64/com32/elflink/ldlinux/ldlinux.e64 x86_64-efi/ldlinux.e64

pcbios/pxelinux.0: syslinuxprepare
	mkdir -p pcbios
	cp _work/$(SYSLINUX_DIR)/bios/core/pxelinux.0 pcbios/pxelinux.0

x86_64-efi/syslinux.efi: syslinuxprepare
	mkdir -p x86_64-efi
	cp _work/$(SYSLINUX_DIR)/efi64/efi/syslinux.efi x86_64-efi/syslinux.efi

i386-efi/syslinux.efi: syslinuxprepare
	mkdir -p i386-efi
	cp _work/$(SYSLINUX_DIR)/efi32/efi/syslinux.efi i386-efi/syslinux.efi

install-data-local: $(SYSLINUXTARGETS)
	@ for i in $(SYSLINUXTARGETS) ; do \
		installdir=$$(dirname $(DESTDIR)/$(datadir)/warewulf/$$i) ; \
		mkdir -p $$installdir ; \
		install -m 644 $$i $$installdir/ ; \
	done

uninstall-local:
	@ for i in $(SYSLINUXTARGETS); do \
		installdir=$$(dirname $(DESTDIR)/$(datadir)/warewulf/$$i) ; \
		rm -f $(DESTDIR)/$(datadir)/warewulf/$$i ; \
    rmdir $$installdir 2>/dev/null || true ; \
	done
	rm -f prepare

clean-local:
	rm -rf _work prepare $(SYSLINUXTARGETS) i386-efi x86_64-efi pcbios
