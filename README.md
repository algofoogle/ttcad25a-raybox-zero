![](../../workflows/gds/badge.svg) ![](../../workflows/docs/badge.svg) ![](../../workflows/test/badge.svg) ![](../../workflows/fpga/badge.svg)

# TTCAD25a resubmission of tt07-raybox-zero and ttihp0p2-raybox-zero

This project is made from a clone of the [tt10-verilog-template](https://github.com/TinyTapeout/tt10-verilog-template) repo.

It is a sky130 resubmission of [ttihp0p2-raybox-zero](https://github.com/algofoogle/ttihp0p2-raybox-zero) (an updated version of [tt07-raybox-zero](https://github.com/algofoogle/tt07-raybox-zero), from the [raybox-zero](https://github.com/algofoogle/raybox-zero) project).

*   [Read the documentation for project](docs/info.md)

The TT07 version used raybox-zero version 1.5, while this one uses 1.6. This includes the following improvements (some of which are now optional extras, selected by [`rbz_options.v`](./src/rbz_options.v)):
*   `USE_POV_VIA_SPI_REGS`:
    *   POV now is set via the same SPI as all other registers, so it doesn't use a dedicated SPI interface.
*   `tex_pmod_type` input can select between the Tiny QSPI PMOD and the Digilent SPI PMOD.
*   `debug` overlays show all of:
    *   `USE_MAP_OVERLAY` (shows the map)
    *   `USE_DEBUG_OVERLAY` (shows POV registers)
    *   `TRACE_STATE_DEBUG` (shows map ray casting state per each line)
*   `USE_LEAK_FIXED`:
    *   In this case, 'FIXED' means 'anchored'.
    *   `CMD_VINF` supports an extra bit controlling whether LEAK is floating (default) or fixed.
*   Leak underflow/overflow glitches are corrected...?
*   `ALT_FIXED_POINT_PARAMS`:
    *   Fixed-point maths uses Q12.12 in this version (TT07 used Q11.11).


## What is Tiny Tapeout?

Tiny Tapeout is an educational project that aims to make it easier and cheaper than ever to get your digital and analog designs manufactured on a real chip.

To learn more and get started, visit https://tinytapeout.com.

## Resources

*   [FAQ](https://tinytapeout.com/faq/)
*   [Digital design lessons](https://tinytapeout.com/digital_design/)
*   [Learn how semiconductors work](https://tinytapeout.com/siliwiz/)
*   [Join the community](https://tinytapeout.com/discord)
*   [Build your design locally](https://www.tinytapeout.com/guides/local-hardening/)
