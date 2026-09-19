/**
 * @file riscv_virt.ld
 * @brief Linker script for RISC-V RV32I on QEMU virt machine.
 */

ENTRY(_start)

MEMORY
{
    RAM (rwx) : ORIGIN = 0x80000000, LENGTH = 128M
}

SECTIONS
{
    .text :
    {
        KEEP(*(.text.init))
        *(.text*)
        *(.rodata*)
        KEEP(*(.init))
        KEEP(*(.fini))
    } > RAM

    . = ALIGN(8);
    _sidata = LOADADDR(.data);

    .data :
    {
        _sdata = .;
        *(.data*)
        *(.sdata*)
        _edata = .;
    } > RAM

    . = ALIGN(8);
    __global_pointer$ = . + 0x800;

    .bss :
    {
        . = ALIGN(8);
        PROVIDE(__bss_start = .);
        PROVIDE(__bss_start__ = .);
        _sbss = .;
        *(.bss*)
        *(.sbss*)
        *(COMMON)
        _ebss = .;
        PROVIDE(__bss_end = .);
        PROVIDE(__bss_end__ = .);
    } > RAM

    . = ALIGN(16);
    /* 64 KB initial boot stack */
    _estack = . + 0x10000;
    . = _estack;
    _end = .;
    end = .;
    __end__ = .;

    /DISCARD/ :
    {
        *(.eh_frame)
        *(.eh_frame_hdr)
    }
}
