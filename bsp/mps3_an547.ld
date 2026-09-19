/**
 * @file mps3_an547.ld
 * @brief Linker script for ARM Cortex-M55 on ARM MPS3-AN547 FPGA / QEMU emulation.
 */

MEMORY
{
    FLASH (rx) : ORIGIN = 0x00000000, LENGTH = 512K
    RAM  (rwx) : ORIGIN = 0x20000000, LENGTH = 512K
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
