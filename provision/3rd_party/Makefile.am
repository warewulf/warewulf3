SUBDIRS = GPL BSD

IPXETARGETS = bin-i386-pcbios/undionly.kpxe bin-x86_64-efi/snp.efi bin-i386-efi/snp.efi bin-arm64-efi/snp.efi

MAINTAINERCLEANFILES = Makefile.in

all: $(IPXETARGETS)

IPXE_VERSION = 041d362
IPXE_SOURCE = $(top_srcdir)/3rd_party/GPL/ipxe-$(IPXE_VERSION).tar.xz
IPXE_DIR = ipxe-$(IPXE_VERSION)


prep:
	@ if [ ! -d "_work/$(IPXE_DIR)" ]; then \
		echo "Extracting IPXE" ;\
		mkdir -p _work/ ;\
		tar -xJf $(IPXE_SOURCE) -C _work/ ;\
	fi

bin-i386-pcbios/undionly.kpxe: prep

if BUILD_X86_64
	$(MAKE) -C _work/$(IPXE_DIR)/src CROSS_COMPILE=$(CROSS_COMPILE_X86_64) bin-i386-pcbios/undionly.kpxe
endif

bin-x86_64-efi/snp.efi: prep

if BUILD_X86_64
	$(MAKE) -C _work/$(IPXE_DIR)/src CROSS_COMPILE=$(CROSS_COMPILE_X86_64) bin-x86_64-efi/snp.efi
endif

bin-i386-efi/snp.efi: prep

if BUILD_X86_64
	$(MAKE) -C _work/$(IPXE_DIR)/src CROSS_COMPILE=$(CROSS_COMPILE_X86_64) bin-i386-efi/snp.efi
endif

bin-arm64-efi/snp.efi: prep

if BUILD_ARM64
	$(MAKE) -C _work/$(IPXE_DIR)/src CROSS_COMPILE=$(CROSS_COMPILE_ARM64) bin-arm64-efi/snp.efi
endif

install-data-local: $(IPXETARGETS)
	mkdir -p $(DESTDIR)/$(datadir)/warewulf/
	@ for i in $(IPXETARGETS); do \
		if [ -f _work/$(IPXE_DIR)/src/$$i ]; then \
			installdir=$$(dirname $(DESTDIR)/$(datadir)/warewulf/ipxe/$$i) ; \
			mkdir -p $$installdir ; \
			install -m 644 _work/$(IPXE_DIR)/src/$$i $$installdir/ ; \
		fi ; \
	done

uninstall-local:
	@ for i in $(IPXETARGETS); do \
		installdir=$$(dirname $(DESTDIR)/$(datadir)/warewulf/ipxe/$$i) ; \
		rm -f $(DESTDIR)/$(datadir)/warewulf/ipxe/$$i ; \
		rmdir $$installdir 2>/dev/null || true ; \
	done

clean-local:
	rm -rf _work 
