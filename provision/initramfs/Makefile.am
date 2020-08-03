SUBDIRS = capabilities

all: initramfs.cpio

top_srcdir = @top_srcdir@

MACHINE:=$(shell uname -m)

BUSYBOX_VERSION = 1.26.2
BUSYBOX_SOURCE = $(top_srcdir)/3rd_party/GPL/busybox-$(BUSYBOX_VERSION).tar.bz2
BUSYBOX_DIR = busybox-$(BUSYBOX_VERSION)
BUSYBOX_PATCHES =

E2FSPROGS_VERSION = 1.42.12
E2FSPROGS_SOURCE = $(top_srcdir)/3rd_party/GPL/e2fsprogs-$(E2FSPROGS_VERSION).tar.gz
E2FSPROGS_DIR = e2fsprogs-$(E2FSPROGS_VERSION)
E2FSPROGS_CONFIGARGS = --disable-testio-debug --disable-debugfs --disable-imager --disable-resizer  --disable-defrag --disable-fsck --disable-tls --disable-uuidd --disable-nls --disable-profile

LIBARCHIVE_VERSION = 3.3.1
LIBARCHIVE_SOURCE = $(top_srcdir)/3rd_party/BSD/libarchive-$(LIBARCHIVE_VERSION).tar.gz
LIBARCHIVE_DIR = libarchive-$(LIBARCHIVE_VERSION)
LIBARCHIVE_CONFIGARGS = --enable-bsdtar=static --disable-bsdcpio --enable-xattr --enable-acl --enable-static --disable-shared  --without-zlib --without-bz2lib --without-iconv --without-lzma --without-lzo2 --without-lz4 --without-nettle --without-openssl --without-xml2 --without-expat

PARTED_VERSION = 3.2
PARTED_SOURCE = $(top_srcdir)/3rd_party/GPL/parted-$(PARTED_VERSION).tar.xz
PARTED_DIR = parted-$(PARTED_VERSION)
PARTED_CONFIGARGS = --prefix=/usr --without-readline --disable-static --disable-nls --disable-dynamic-loading --disable-debug

e2fsprogs:
	@ if [ -n "@local_e2fsprogs_path@" -a -f "@local_e2fsprogs_path@" ]; then \
		echo "Detected local install of e2fsprogs. Bypassing e2fsprogs build process." ;\
	else \
		if [ ! -d "_work/$(E2FSPROGS_DIR)" ]; then \
			echo "Preparing to build e2fsprogs" ;\
			mkdir -p _work/ ;\
			tar xzf $(E2FSPROGS_SOURCE) -C _work/ ;\
		fi ;\
		if [ ! -f "_work/$(E2FSPROGS_DIR)/misc/mke2fs" ]; then \
			echo "Building e2fsprogs" ;\
			if [ -f "/usr/lib/rpm/config.guess" ]; then \
				cp /usr/lib/rpm/config.guess _work/$(E2FSPROGS_DIR)/config;\
			fi; \
			if [ -f "/usr/lib/rpm/config.sub" ]; then \
				cp /usr/lib/rpm/config.sub _work/$(E2FSPROGS_DIR)/config;\
			fi; \
			(cd _work/$(E2FSPROGS_DIR)/; ./configure $(E2FSPROGS_CONFIGARGS)) ;\
			$(MAKE) -C _work/$(E2FSPROGS_DIR);\
		fi ;\
	fi

xfsprogs:
	@ if [ -n "@local_xfsprogs_path@" -a -f "@local_xfsprogs_path@" ]; then \
                echo "Detected local install of xfsprogs. Bypassing xfsprogs build process." ;\
	fi

busybox:
	@ if [ -n "@local_busybox_path@" -a -f "@local_busybox_path@" -a \
	    -n "@busybox_links_path@" -a -f "@busybox_links_path@" ]; then \
		echo "Detected local install of busybox. Bypassing busybox build process." ;\
	else \
		if [ ! -d "_work/$(BUSYBOX_DIR)" ]; then \
			echo "Preparing to build initramfs core" ;\
			mkdir -p _work/ ;\
			tar xjf $(BUSYBOX_SOURCE) -C _work/ ;\
			for i in $(BUSYBOX_PATCHES); do \
				(cd _work/$(BUSYBOX_DIR); patch -p1 < ../../$${i} || exit 1) ;\
			done ;\
			cp $(srcdir)/busybox.config _work/busybox-$(BUSYBOX_VERSION)/.config ;\
		fi ;\
		if [ ! -f "_work/$(BUSYBOX_DIR)/" ]; then \
			echo "Building initramfs core" ;\
			$(MAKE) -C _work/$(BUSYBOX_DIR) busybox ;\
		fi ;\
		if [ ! -d "_work/$(BUSYBOX_DIR)/_install" ]; then \
			echo "Installing initramfs core" ;\
			$(MAKE) -C _work/$(BUSYBOX_DIR) install ;\
		fi ;\
	fi

libarchive:
	@ if [ -n "@local_libarchive_path@" -a -f "@local_libarchive_path@" ]; then \
		echo "Detected local install of bsdtar. Bypassing libarchive build process." ;\
	else \
		if [ ! -d "_work/$(LIBARCHIVE_DIR)" ]; then \
			echo "Preparing to build libarchive" ;\
			mkdir -p _work/ ;\
			tar xzf $(LIBARCHIVE_SOURCE) -C _work/ ;\
		fi ;\
		if [ ! -f "_work/$(LIBARCHIVE_DIR)/" ]; then \
			echo "Building libarchive" ;\
			(cd _work/$(LIBARCHIVE_DIR)/; ./configure $(LIBARCHIVE_CONFIGARGS)) ;\
			$(MAKE) -C _work/$(LIBARCHIVE_DIR);\
		fi ;\
	fi

parted:
	@ if [ -n "@local_parted_path@" -a -f "@local_parted_path@" -a \
	  -n "@local_partprobe_path@" -a -f "@local_partprobe_path@" ]; then \
		echo "Detected local install of parted. Bypassing parted build process." ;\
	else \
		if [ ! -d "_work/$(PARTED_DIR)" ]; then \
			echo "Preparing to build parted" ;\
			mkdir -p _work/ ;\
		echo In directory `pwd` ;\
			tar Jxf $(PARTED_SOURCE) -C _work/ ;\
		fi; \
		if [ ! -f "_work/$(PARTED_DIR)/" ]; then \
			echo "Building parted" ;\
			(cd _work/$(PARTED_DIR)/; ./configure $(PARTED_CONFIGARGS)) ;\
			$(MAKE) -C _work/$(PARTED_DIR);\
		fi \
	fi

rootfs: busybox e2fsprogs xfsprogs libarchive parted
	rm -rf rootfs
	mkdir rootfs
	mkdir rootfs/bin
	mkdir rootfs/sbin
	mkdir rootfs/etc
	mkdir rootfs/proc
	mkdir rootfs/var
	mkdir rootfs/tmp
	mkdir rootfs/usr
	mkdir rootfs/lib
	mkdir rootfs/lib64
	chmod -R u+w rootfs/
	if [ -n "@local_busybox_path@" -a -f "@local_busybox_path@" -a \
	    -n "@local_busybox_path@" -a -f "@busybox_links_path@" ]; then \
		while read lfpath; do \
			if [ ! -d rootfs$$(dirname $${lfpath}) ]; then \
				mkdir -p rootfs$$(dirname $${lfpath}); \
			fi; \
			ln -vs /bin/busybox rootfs$${lfpath}; \
		done < "@busybox_links_path@" ;\
		cp -av "@local_busybox_path@" rootfs/bin/busybox ;\
	else \
		cp -av _work/$(BUSYBOX_DIR)/_install/* rootfs/ ;\
	fi
	if [ -n "@local_e2fsprogs_path@" -a -f "@local_e2fsprogs_path@" ]; then \
		cp -av "@local_e2fsprogs_path@" rootfs/sbin/mkfs.ext4 ;\
	else \
		cp -av _work/$(E2FSPROGS_DIR)/misc/mke2fs rootfs/sbin/mkfs.ext4 ;\
	fi
	ln -s mkfs.ext4 rootfs/sbin/mkfs.ext3
	if [ -n "@local_xfsprogs_path@" -a -f "@local_xfsprogs_path@" ]; then \
		cp -av "@local_xfsprogs_path@" rootfs/sbin/mkfs.xfs ; \
        fi
	if [ -n "@local_libarchive_path@" -a -f "@local_libarchive_path@" ]; then \
		cp -av "@local_libarchive_path@" rootfs/bin/bsdtar; \
	else \
		cp -av _work/$(LIBARCHIVE_DIR)/bsdtar rootfs/bin/bsdtar; \
	fi
	if [ -n "@local_parted_path@" -a -f "@local_parted_path@" -a \
	  -n "@local_partprobe_path@" -a -f "@local_partprobe_path@" ]; then \
		cp -av "@local_parted_path@" rootfs/usr/sbin/parted; \
		cp -av "@local_partprobe_path@" rootfs/usr/sbin/partprobe; \
	else \
		$(MAKE) -C _work/$(PARTED_DIR)/ DESTDIR=`pwd`/rootfs install; \
	fi
	cp -L --parents /lib*/ld-linux* rootfs/
	find rootfs -type f -perm -o+x -print | grep -v ld-linux | xargs ldd | grep "=>" | awk '{print $$3}' | grep "^/" | sort | uniq | while read i; do cp -L --parents $$i rootfs/ && chmod 755 rootfs/$$i; done
	rm -f rootfs/linuxrc rootfs/lib64/*.la rootfs/lib/*.la rootfs/usr/lib64/*.la rootfs/usr/lib/*.la
	rm -rf rootfs/usr/share rootfs/usr/include rootfs/usr/lib/pkgconfig
	find -type d \! -perm -u=w -exec chmod u+w {} \;
	find rootfs -type f -perm -o+x -print | xargs strip -g

	install -m 755 $(srcdir)/init rootfs/init
	install -m 755 $(srcdir)/functions rootfs/etc/functions
	install -m 755 $(srcdir)/dhcp-script rootfs/sbin/
	install -m 755 $(srcdir)/detect rootfs/sbin/
	install -m 755 $(srcdir)/transporthandler rootfs/sbin/
	install -m 755 $(srcdir)/provisionhandler rootfs/sbin/
	install -m 755 $(srcdir)/wwlogger rootfs/sbin/
	ln -s transporthandler rootfs/sbin/wwgetvnfs
	ln -s transporthandler rootfs/sbin/wwgetscript
	ln -s transporthandler rootfs/sbin/wwgetnodeconfig
	ln -s transporthandler rootfs/sbin/wwgetfiles

initramfs.cpio: rootfs
	install -m 644 $(srcdir)/devs.cpio initramfs.cpio
	cd rootfs/; find . | cpio -o -H newc -A -F ../initramfs.cpio

install-data-local: initramfs.cpio
	install -d -m 755 $(DESTDIR)/$(WAREWULF_STATEDIR)/warewulf/initramfs/
	install -d -m 755 $(DESTDIR)/$(WAREWULF_STATEDIR)/warewulf/initramfs/$(MACHINE)
	install -m 644 initramfs.cpio $(DESTDIR)/$(WAREWULF_STATEDIR)/warewulf/initramfs/$(MACHINE)/base

uninstall-local:
	rm -rf $(DESTDIR)/$(WAREWULF_STATEDIR)/warewulf/initramfs/$(MACHINE)/base

clean-local:
	rm -rf _work rootfs initramfs.cpio



EXTRA_DIST = busybox.config init devs.cpio functions dhcp-script detect transporthandler provisionhandler wwlogger

MAINTAINERCLEANFILES = Makefile.in
