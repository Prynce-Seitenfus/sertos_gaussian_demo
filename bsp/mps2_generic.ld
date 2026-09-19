/**
 * @file mps2_generic.ld
 * @brief Linker script for ARM Cortex-M0/M3/M4 on ARM MPS2 FPGA / QEMU emulation.
 */

MEMORY
{
    FLASH (rx) : ORIGIN = 0x00000000, LENGTH = 4M
    RAM  (rwx) : ORIGIN = 0x20000000, LENGTH = 4M
}

_estack = ORIGIN(RAM) + LENGTH(RAM);

SECTIONS
{
    .vectors :
    {
        KEEP(*(.vectors))
    } > FLASH

    .text :
    {
        *(.text*)
        *(.rodata*)
        KEEP(*(.init))
        KEEP(*(.fini))
    } > FLASH

    _sidata = LOADADDR(.data);

    .data :
    {
        _sdata = .;
        *(.data*)
        _edata = .;
    } > RAM AT > FLASH

    .bss :
    {
        __bss_start__ = .;
        _sbss = .;
        *(.bss*)
        *(COMMON)
        _ebss = .;
        __bss_end__ = .;
    } > RAM

    . = ALIGN(8);
    _end = .;
    end = .;
    __end__ = .;

    /DISCARD/ :
    {
        *(.ARM.exidx*)
    }
}
