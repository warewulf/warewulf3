SUBDIRS = GPL BSD MIT

IPXETARGETS = bin-i386-pcbios/undionly.kpxe bin-x86_64-efi/snp.efi bin-i386-efi/snp.efi bin-arm64-efi/snp.efi

MAINTAINERCLEANFILES = Makefile.in

all: $(IPXETARGETS)

IPXE_VERSION = 133f4c4
IPXE_SOURCE = $(top_srcdir)/3rd_party/GPL/ipxe-$(IPXE_VERSION).tar.xz
IPXE_DIR = ipxe-$(IPXE_VERSION)


prep:
	@ if [ ! -d "_work/$(IPXE_DIR)" ]; then \
		echo "Extracting IPXE" ;\
		mkdir -p _work/ ;\
		tar -xJf $(IPXE_SOURCE) -C _work/ ;\
		echo '#define DOWNLOAD_PROTO_HTTPS' >> "_work/$(IPXE_DIR)/src/config/local/general.h" ;\
		echo '#define NTP_CMD' >> "_work/$(IPXE_DIR)/src/config/local/general.h" ;\
	fi

bin-i386-pcbios/undionly.kpxe: prep

if BUILD_X86_64
	@ if [ -n "@local_ipxe_undionly_path@" -a -f "@local_ipxe_undionly_path@" ]; then \
		echo "Detected local install of undionly.kpxe boot image. Bypassing build process." ;\
		mkdir -p _work/$(IPXE_DIR)/src/bin-i386-pcbios ;\
		cp "@local_ipxe_undionly_path@" _work/$(IPXE_DIR)/src/bin-i386-pcbios/undionly.kpxe ;\
	else \
		$(MAKE) -C _work/$(IPXE_DIR)/src CROSS_COMPILE=$(CROSS_COMPILE_X86_64) bin-i386-pcbios/undionly.kpxe; \
	fi
endif

bin-x86_64-efi/snp.efi: prep

if BUILD_X86_64
	@ if [ -n "@local_ipxe_snp_x86_64_path@" -a -f "@local_ipxe_snp_x86_64_path@" ]; then \
		echo "Detected local install of x86_64 snp.efi boot image. Bypassing build process." ;\
		mkdir -p _work/$(IPXE_DIR)/src/bin-x86_64-efi ;\
		cp "@local_ipxe_snp_x86_64_path@" _work/$(IPXE_DIR)/src/bin-x86_64-efi/snp.efi ;\
	else \
		$(MAKE) -C _work/$(IPXE_DIR)/src CROSS_COMPILE=$(CROSS_COMPILE_X86_64) bin-x86_64-efi/snp.efi; \
	fi
endif

bin-i386-efi/snp.efi: prep

if BUILD_X86_64
	@ if [ -n "@local_ipxe_snp_i386_path@" -a -f "@local_ipxe_snp_i386_path@" ]; then \
		echo "Detected local install of i386 snp.efi boot image. Bypassing build process." ;\
		mkdir -p _work/$(IPXE_DIR)/src/bin-i386-efi ;\
		cp "@local_ipxe_snp_i386_path@" _work/$(IPXE_DIR)/src/bin-i386-efi/snp.efi ;\
	else \
		$(MAKE) -C _work/$(IPXE_DIR)/src CROSS_COMPILE=$(CROSS_COMPILE_X86_64) bin-i386-efi/snp.efi; \
	fi
endif

bin-arm64-efi/snp.efi: prep

if BUILD_ARM64
	@ if [ -n "@local_ipxe_snp_arm64_path@" -a -f "@local_ipxe_snp_arm64_path@" ]; then \
		echo "Detected local install of arm64 snp.efi boot image. Bypassing build process." ;\
		mkdir -p _work/$(IPXE_DIR)/src/bin-arm64-efi ;\
		cp "@local_ipxe_snp_arm64_path@" _work/$(IPXE_DIR)/src/bin-arm64-efi/snp.efi ;\
	else \
	$(MAKE) -C _work/$(IPXE_DIR)/src CROSS_COMPILE=$(CROSS_COMPILE_ARM64) bin-arm64-efi/snp.efi; \
        fi
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
