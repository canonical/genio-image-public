STAGEDIR ?= "$(CURDIR)/stage"
DESTDIR ?= "$(CURDIR)/install"
ARCH ?= arm64

SOURCES_HOST ?= "/etc/apt/sources.list"

CHDIST_DIR = $(STAGEDIR)/chdist


# Call apt utilities
define chdist 
	chdist -a $(ARCH) -d $(CHDIST_DIR) $(1) ubuntu $(2)
endef

# Download package $1 and unpacking it into $(STAGEDIR).
# Example:
#  $(call stage_package,linux-modules-*-mtk)
#
define stage_package
	mkdir -p $(STAGEDIR)/tmp-deb
	cd $(STAGEDIR)/tmp-deb && ( \
		$(call chdist,apt-get,download $(1)) && \
		dpkg-deb --extract *.deb $(STAGEDIR))
	rm -rf $(STAGEDIR)/tmp-deb
endef

classic: config-classic boot-assets-classic gadget

core: config-core gadget

config-core: $(DESTDIR)/boot-assets
	# TODO:UC20: currently we use an empty uboot.conf as a landmark for the new
	#            uboot style where there is no uboot.env installed onto the root
	#            of the partition and instead the boot.scr is used. this may
	#            change for the final release
	touch $(DESTDIR)/uboot.conf
	# the boot.sel file is currently installed onto ubuntu-boot from the gadget
	# but that will probably change soon so that snapd installs it instead
	# it is empty now, but snapd will write vars to it
	mkenvimage -r -s 4096 -o $(DESTDIR)/boot.sel - < /dev/null

ubuntu-archive:
	mkdir -p $(CHDIST_DIR)
	$(call chdist,create)
	cp -r apt $(CHDIST_DIR)/ubuntu/etc/
	$(call chdist,apt-get,update)

grub: ubuntu-archive
	cp grub.cfg $(DESTDIR)/grub.cfg
	$(call stage_package,grub-efi-arm64-signed)
	cp -a $(STAGEDIR)/usr/lib/grub/arm64-efi-signed/grubaa64.efi.signed \
		$(DESTDIR)/grubaa64.efi.signed
	$(call stage_package,shim-signed)
	cp -a $(STAGEDIR)/usr/lib/shim/shimaa64.efi.signed.latest \
		$(DESTDIR)/shimaa64.efi.signed
	cp -a $(STAGEDIR)/usr/lib/shim/fbaa64.efi \
		$(DESTDIR)/fbaa64.efi
	cp -a $(STAGEDIR)/usr/lib/shim/mmaa64.efi \
		$(DESTDIR)/mmaa64.efi
	cp -a $(STAGEDIR)/usr/lib/shim/BOOTAA64.CSV \
		$(DESTDIR)/BOOTAA64.CSV

config-classic: configs/classic/user-data configs/classic/meta-data configs/classic/network-config
	install -D --target-directory=$(DESTDIR)/boot-assets $^

boot-assets-classic: grub

gadget:
	mkdir -p $(DESTDIR)/meta
	install -D --target-directory=$(DESTDIR)/meta gadget.yaml

clean:
	-rm -rf $(DESTDIR)
	-rm -rf $(STAGEDIR)

