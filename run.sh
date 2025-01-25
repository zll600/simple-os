#!/bin/bash
set -xue

# QEMU file path
QEMU=qemu-system-riscv32

OBJCOPY=$(which llvm-objcopy)

# Path to clang and compiler flags
CC=$(which clang)
CFLAGS="-std=c11 -O2 -g3 -Wall -Wextra --target=riscv32 -ffreestanding -nostdlib"

# Build the shell (application)
$CC $CFLAGS -Wl,-Tuser.ld -Wl,-Map=shell.map -o shell.elf shell.c user.c common.c
$OBJCOPY --set-section-flags .bss=alloc,contents -O binary shell.elf shell.bin
$OBJCOPY -Ibinary -Oelf32-littleriscv shell.bin shell.bin.o

# Build the kernel
$CC $CFLAGS -Wl,-Tkernel.ld -Wl,-Map=kernel.map -o kernel.elf \
	kernel.c common.c shell.bin.o

(cd disk && tar cf ../disk.tar --format=ustar ./*.txt)

# Start QEMU
$QEMU -machine virt -bios default -nographic -serial mon:stdio --no-reboot \
	-d unimp,guest_errors,int,cpu_reset -D qemu.log \
	-drive id=drive0,file=disk.tar,format=raw,if=none \
	-device virtio-blk-device,drive=drive0,bus=virtio-mmio-bus.0 \
	-kernel kernel.elf
