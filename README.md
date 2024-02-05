# pKVM tester #

This repository contains a bare-bones Linux boot environment, meant to run pKVM
tests.

It runs entirely from the initramfs image (normally provided alongside the
kernel to both real systems and Qemu). It does almost no system bring-up. After
boot, it runs a given set of executables, and then halts the system.

## Executables ##

Executables can be added to the `payload/` directory. The image will run all
executables in that directory.

Executables must be either statically compiled aarch64 binaries, or shell
scripts compatible with `busybox ash`.

## Running ##

Add any executables to `payload/`, and run `make`. This produces
`_build/{var,efi,initramfs}.img` which can be used with Qemu. The kernel must be
provided separately.

Alternatively, just run `scripts/run-vm --kernel <KERNEL>`. This rebuilds the
images and boots Qemu.

If Qemu is not instelled system-wide, or to use a different UEFI image, run
`make UEFI=<IMAGE>` instead.

## Dependencies ##

Requires `make`, `jq`, a few Linux utilities which are usually installed, a Qemu
installation providing `qemu-system-aarch64`, and an UEFI compatible with it.
These are all provided by distribution packages on regular Linux distributions.
