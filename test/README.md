# `test/`: Files supporting basic cocotb automated tests

This testbench uses [cocotb](https://docs.cocotb.org/en/stable/) to drive the DUT and check the outputs of raybox-zero wrapped within this Tiny Tapeout submission template. It was copied from: https://github.com/algofoogle/ttihp0p2-raybox-zero/tree/main/test

This builds on:
* https://github.com/algofoogle/tt05-vga-spi-rom/tree/main/src/test
* https://github.com/algofoogle/tt04-raybox-zero/tree/1.0-test/src/test
* https://github.com/TinyTapeout/tt07-verilog-template/tree/main/test

For other background on this, see [0197], [0198], and [0204].

**To actually run the tests,** go into this `test/` directory (i.e. where the `Makefile` is) and run `make -B`.


## More information

[0204] now probably has my most comprehensive notes on how to set up your environment for local hardening (on sky130 Tiny Tapeout, at least) and testing. Note that it includes lots of stuff from my original TT04 re-testing, but further down on the page are the additional details that work for this repo and TT07.

If you run `make clean && make -B` it will run the RTL test. These render frames on my machine at about 26 seconds each.

If you run `make clean && make -B GATES=yes` it will run the GL (gate-level) test. These take about 70 seconds per frame.

Frame output files are `test/frames_out/rbz_basic_frame-???.ppm`.

> [!NOTE]
> If you change the RTL and want to do GL, remember that you'll need to reharden and then copy `../runs/wokwi/final/pnl/tt_um_algofoogle_raybox_zero.pnl.v` to `./gate_level_netlist.v`.

To view the VCD file, run: `make wave`


[0197]: https://github.com/algofoogle/journal/blob/master/0197-2024-04-02.md
[0198]: https://github.com/algofoogle/journal/blob/master/0198-2024-04-03.md
[0204]: https://github.com/algofoogle/journal/blob/master/0204-2024-05-25.md

