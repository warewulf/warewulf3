all: ipmitool

top_srcdir = @top_srcdir@

MACHINE:=$(shell uname -m)

IPMITOOL_VERSION = 1.8.18
IPMITOOL_SOURCE = $(top_srcdir)/3rd_party/BSD/ipmitool-$(IPMITOOL_VERSION).tar.bz2

ipmitool:
	@ if [ -n "@local_ipmitool_path@" -a -f "@local_ipmitool_path@" ]; then \
            echo "Detected local install of ipmitool. Bypassing the build process." ;\
	else \
	    if [ ! -d "_work/ipmitool/ipmitool-$(IPMITOOL_VERSION)" ]; then \
	        echo "Preparing to build ipmitool" ;\
	        mkdir -p _work/ipmitool;\
	        tar xjf $(srcdir)/$(IPMITOOL_SOURCE) -C _work/ipmitool/ ;\
	    fi; \
	    if [ ! -f "_work/ipmitool/ipmitool-$(IPMITOOL_VERSION)/src/ipmitool" ]; then \
	        echo "Building ipmitool" ;\
		if [ -f "/usr/lib/rpm/config.guess" ]; then \
			cp -a /usr/lib/rpm/config.guess _work/ipmitool/ipmitool-$(IPMITOOL_VERSION) ;\
		fi; \
		if [ -f "/usr/lib/rpm/config.sub" ]; then \
			cp -a /usr/lib/rpm/config.sub _work/ipmitool/ipmitool-$(IPMITOOL_VERSION) ;\
		fi; \
	        cd _work/ipmitool/ipmitool-$(IPMITOOL_VERSION) ;\
	        ./configure --enable-static --disable-ipmishell ;\
	        $(MAKE) LDFLAGS=-static ;\
		cd -;\
	    fi; \
	fi

# Preserve time stamps of archived files for build reproducibility
rootfs: ipmitool
	rm -rf rootfs
	mkdir rootfs
	mkdir rootfs/sbin
	mkdir rootfs/lib
	mkdir rootfs/lib64
	mkdir -p rootfs/warewulf/provision/
	chmod -R u+w rootfs/
	if [ -n "@local_ipmitool_path@" -a -f "@local_ipmitool_path@" ]; then \
            cp -av "@local_ipmitool_path@" rootfs/sbin/; \
	else \
            cp -v _work/ipmitool/ipmitool-$(IPMITOOL_VERSION)/src/ipmitool rootfs/sbin/ ;\
            touch -r 10-ipmiconfig rootfs/sbin/ipmitool; \
	fi
	find rootfs -type f -perm -o+x  -print | xargs ldd | grep "=>" | awk '{print $$3}' | grep "^/" | sort | uniq | while read i; do cp -avL --parents $$i rootfs/; done
	chmod -R +w rootfs/
	find rootfs -type f -perm -o+x -print | xargs strip -pg
	install -p -m 755 $(srcdir)/10-ipmiconfig rootfs/warewulf/provision/10-ipmiconfig

capability.cpio: rootfs
	find rootfs/ -type d | xargs touch -r $(srcdir)/10-ipmiconfig
	cd rootfs/; find . | cpio -o -H newc --reproducible -F ../capability.cpio

install-data-local: capability.cpio
	install -d -m 755 $(DESTDIR)/$(WAREWULF_STATEDIR)/warewulf/initramfs/$(MACHINE)
	install -d -m 755 $(DESTDIR)/$(WAREWULF_STATEDIR)/warewulf/initramfs/$(MACHINE)/capabilities
	install -m 644 capability.cpio $(DESTDIR)/$(WAREWULF_STATEDIR)/warewulf/initramfs/$(MACHINE)/capabilities/setup-ipmi
	@ if [ -z "@local_ipmitool_path@" -o ! -f "@local_ipmitool_path@" ]; then \
	   install -d -m 755 $(DESTDIR)/$(WAREWULF_LIBEXECDIR)/warewulf; \
	   install -m 755 rootfs/sbin/ipmitool $(DESTDIR)/$(WAREWULF_LIBEXECDIR)/warewulf; \
        fi

uninstall-local:
	rm -rf $(DESTDIR)/$(WAREWULF_STATEDIR)/warewulf/initramfs/$(MACHINE)/capabilities/setup-ipmi
	rm -rf $(DESTDIR)/$(WAREWULF_LIBEXECDIR)/warewulf/ipmitool

clean-local:
	rm -rf _work rootfs ipmitool capability.cpio


EXTRA_DIST = 10-ipmiconfig
