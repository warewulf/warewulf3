SUBDIRS = GPL BSD

IPXETARGETS = bin/undionly.kpxe bin-x86_64-efi/ipxe.efi bin-i386-efi/ipxe.efi

MAINTAINERCLEANFILES = Makefile.in

all: $(IPXETARGETS)

IPXE_VERSION = 9ccd8fe5
IPXE_SOURCE = $(top_srcdir)/3rd_party/GPL/ipxe-$(IPXE_VERSION).tar.xz
IPXE_DIR = ipxe-$(IPXE_VERSION)


prep:
	@ if [ ! -d "_work/$(IPXE_DIR)" ]; then \
		echo "Extracting IPXE" ;\
		mkdir -p _work/ ;\
		tar -xJf $(IPXE_SOURCE) -C _work/ ;\
	fi

bin/undionly.kpxe: prep
	make -C _work/$(IPXE_DIR)/src bin/undionly.kpxe

bin-x86_64-efi/ipxe.efi: prep
	make -C _work/$(IPXE_DIR)/src bin-x86_64-efi/ipxe.efi

bin-i386-efi/ipxe.efi: prep
	make -C _work/$(IPXE_DIR)/src bin-i386-efi/ipxe.efi

install-data-local: $(IPXETARGETS)
	mkdir -p $(DESTDIR)/$(datadir)/warewulf/
	@ for i in $(IPXETARGETS); do \
		installdir=$$(dirname $(DESTDIR)/$(datadir)/warewulf/ipxe/$$i) ; \
		mkdir -p $$installdir ; \
		install -m 644 _work/$(IPXE_DIR)/src/$$i $$installdir/ ; \
	done

uninstall-local:
	@ for i in $(IPXETARGETS); do \
		installdir=$$(dirname $(DESTDIR)/$(datadir)/warewulf/ipxe/$$i) ; \
		rm -f $(DESTDIR)/$(datadir)/warewulf/ipxe/$$i ; \
		rmdir $$installdir 2>/dev/null || true ; \
	done

clean-local:
	rm -rf _work 
