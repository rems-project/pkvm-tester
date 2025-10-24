# pKVM tester #

This repository contains a bare-bones Linux boot environment, meant to run pKVM
tests.

It runs entirely from the initramfs image (normally provided alongside the
kernel to both real systems and Qemu). It does almost no system bring-up. After
boot, it runs a given set of executables, and then halts the system.

## Executables ##

Executables can be added to the `ramfs.exe/` directory. The image will run all
executables in that directory.

Executables must be either statically compiled aarch64 binaries, or shell
scripts compatible with `busybox ash`.

## Running ##

Add any executables to `ramfs.exe/`, and run `make`. This produces
`_build/{var,efi,initramfs}.img` which can be used with Qemu. The kernel must be
provided separately.

Alternatively, just run `scripts/run-vm <KERNEL>`. This rebuilds the images and
boots Qemu. The arg syntax of `run-vm` is:
```bash
run-vm KERNEL [ARG] [-- [QEMU-ARG]]
```

- `KERNEL` is the kernel to boot. Mandatory.
- `ARG` can be:
  + `-C|--no-lcov` — suppress LCOV capture
  + `-T|--tag` — add tag to output dir name (repeats)
  + `-d|--debug PORT` — wait for GDB on tcp::PORT (default 1234)"
- `QEMU-ARG` are passed to Qemu.

For instance, to run `Image.v4` run on 8 cores, with no coverage, use:
```bash
run-vm Image.v4 --no-cov -- --smp 8
```

If Qemu is not installed system-wide, or to use a different UEFI image, run
`make UEFI=<IMAGE>` instead.

## Output ##

Each run produces various outputs, in a subdirectory of `output`. For instance,
the terminal output is captured as `serial`.

## Additional ramfs components ##

Transient, unversioned things can be added to `ramfs.extra/`. For instance, this
is a good place to put kernel modules. In your kernel build directory, just do
something like:

```bash
make INSTALL_MOD_PATH=<PATH-TO-HERE>/ramfs.extra modules_install
```

## Coverage ##

If the kernel was built with EL2 GCOV coverage, the raw coverage data (`.gcda`
files) is saved as archives in the output directory.

After Qemu exits, the raw coverage is immediately "captured" into LCOV info
files. This requires the `lcov` and `llvm-cov` (part of `llvm`) executables;
and it requires that the kernel build directory is accessible, and in the same
state it was when the kernel was built. The coverage is stored in LCOV `.info`
files in the output dir, and can be rendered as HTML with, for instance:

```bash
genhtml --branch-coverage /path/to/info /path/to/output/dir
```

## Dependencies ##

Requires `zsh`, `make`, `jq`, a few Linux utilities which are usually installed, a Qemu
installation providing `qemu-system-aarch64`, and an UEFI compatible with it.
These are all provided by distribution packages on regular Linux distributions.
