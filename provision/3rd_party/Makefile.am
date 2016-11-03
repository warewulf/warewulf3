SUBDIRS = GPL BSD

SYSLINUXTARGETS = lpxelinux.0 pxelinux.0 ldlinux.c32 syslinux64.efi syslinux32.efi ldlinux.e32 ldlinux.e64

MAINTAINERCLEANFILES = Makefile.in

all: $(SYSLINUXTARGETS)

SYSLINUX_VERSION = 6.03
SYSLINUX_SOURCE = $(top_srcdir)/3rd_party/GPL/syslinux-$(SYSLINUX_VERSION).tar.gz
SYSLINUX_DIR = syslinux-$(SYSLINUX_VERSION)


syslinuxprepare:
	@ if [ ! -d "_work/$(SYSLINUX_DIR)" ]; then \
		echo "Extracting syslinux distribution" ;\
		mkdir -p _work/ ;\
		tar xzf $(SYSLINUX_SOURCE) -C _work/ ;\
	fi
	touch prepare

lpxelinux.0: syslinuxprepare
	cp _work/$(SYSLINUX_DIR)/bios/core/lpxelinux.0 .

ldlinux.c32: syslinuxprepare
	cp _work/$(SYSLINUX_DIR)/bios/com32/elflink/ldlinux/ldlinux.c32 .

ldlinux.e32: syslinuxprepare
	cp _work/$(SYSLINUX_DIR)/efi32/com32/elflink/ldlinux/ldlinux.e32 .

ldlinux.e64: syslinuxprepare
	cp _work/$(SYSLINUX_DIR)/efi64/com32/elflink/ldlinux/ldlinux.e64 .

pxelinux.0: syslinuxprepare
	cp _work/$(SYSLINUX_DIR)/bios/core/pxelinux.0 .

syslinux64.efi: syslinuxprepare
	cp _work/$(SYSLINUX_DIR)/efi64/efi/syslinux.efi syslinux64.efi

syslinux32.efi: syslinuxprepare
	cp _work/$(SYSLINUX_DIR)/efi32/efi/syslinux.efi syslinux32.efi

install-data-local: $(SYSLINUXTARGETS)
	mkdir -p $(DESTDIR)/$(datadir)/warewulf/
	@ for i in $(SYSLINUXTARGETS); do \
		install -m 644 $$i $(DESTDIR)/$(datadir)/warewulf/ ; \
	done

uninstall-local:
	@ for i in $(SYSLINUXTARGETS); do \
		rm -f $(DESTDIR)/$(datadir)/warewulf/$$i ; \
	done
	rm -f prepare

clean-local:
	rm -rf _work prepare $(SYSLINUXTARGETS)
