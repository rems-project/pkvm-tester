BUILD=_build

# Try to find UEFI image using the Qemu system-wide install.
# If it fails, specify UEFI=... on the command line.
UEFI=$(shell scripts/find-uefi)

images: $(BUILD)/var.img $(BUILD)/efi.img $(BUILD)/initramfs.img

$(BUILD)/var.img:
	@mkdir -p $(BUILD)
	@truncate -s 64m $@

$(BUILD)/efi.img: $(UEFI)
	@mkdir -p $(BUILD)
	@cp $< $@
	@chmod +rw $@
	@truncate -s 64m $@

$(BUILD)/initramfs.img: $(BUILD)/initramfs.root.img $(BUILD)/initramfs.exe.img
	@cat $^ > $@

$(BUILD)/initramfs.root.img: ramfs/*
	@mkdir -p $(BUILD)
	@(cd ramfs && find .|cpio -o -H newc)|zstdmt > $@

$(BUILD)/initramfs.exe.img: payload/*
	@mkdir -p $(BUILD)
	@(find payload|cpio -o -H newc)|zstdmt > $@

clean: 
	@rm -f $(BUILD)/var.img $(BUILD)/efi.img $(BUILD)/initramfs*.img
