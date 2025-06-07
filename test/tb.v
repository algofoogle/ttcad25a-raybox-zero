`default_nettype none
`timescale 1ns / 1ps

/* This testbench just instantiates the module and makes some convenient wires
   that can be driven / tested by the cocotb test.py.
*/

// `define DUMP_VCD

module tb ();

  //NOTE: DON'T write VCD file, because it'd be huge!
`ifdef DUMP_VCD
  // Dump the signals to a VCD file. You can view it with gtkwave.
  initial begin
    $dumpfile("tb.vcd");
    $dumpvars(0, tb);
    #1;
  end
`endif

  // --- Named inputs controlled by test: ---
  // Universal TT inputs:
  reg clk;
  reg rst_n;
  reg ena;
  // Specific inputs for raybox-zero:
  reg debug;
  reg inc_px;
  reg inc_py;
  reg registered_outputs; // aka just 'reg'
  reg spi_sclk;
  reg spi_mosi;
  reg spi_csb;
  reg tex_in0;
  reg tex_pmod_type;
  reg gen_texb;

  // --- DUT's generic IOs from the TT wrapper ---
  wire [7:0] ui_in;       // Dedicated inputs
  wire [7:0] uo_out;      // Dedicated outputs
  wire [7:0] uio_in;      // Bidir IOs: Input path
  wire [7:0] uio_out;     // Bidir IOs: Output path
  wire [7:0] uio_oe;      // Bidir IOs: Enable path (active high: 0=input, 1=output).

  // Specific outputs for raybox-zero:
  // RrGgBb and H/Vsync pin ordering is per Tiny VGA PMOD
  // (https://tinytapeout.com/specs/pinouts/#vga-output)
  wire [1:0] rr = {uo_out[0],uo_out[4]};
  wire [1:0] gg = {uo_out[1],uo_out[5]};
  wire [1:0] bb = {uo_out[2],uo_out[6]};
  wire [5:0] rgb = {rr,gg,bb}; // Just used by cocotb test bench for convenient checks.
  wire hsync_n    = uo_out[7];
  wire vsync_n    = uo_out[3];
  wire tex_csb    = uio_out[0];
  wire tex_out0   = uio_out[1];
  wire tex_sclk   = uio_out[3];

  wire [2:0] tex_io;

  // ====== Inputs coming from cocotb ======

  assign ui_in[0] = spi_sclk;
  assign ui_in[1] = spi_mosi;
  assign ui_in[2] = spi_csb;
  assign ui_in[3] = debug;
  assign ui_in[4] = inc_px;
  assign ui_in[5] = inc_py;
  assign ui_in[6] = registered_outputs;
  assign ui_in[7] = tex_pmod_type;

  assign uio_in[0] = 1'b0; // output only
  assign uio_in[1] = tex_io[0];
  assign uio_in[2] = tex_io[1];
  assign uio_in[3] = 1'b0; // output only
  assign uio_in[4] = 1'b0; // SPARE input
  assign uio_in[5] = gen_texb;
  assign uio_in[6] = tex_io[2];
  assign uio_in[7] = 1'b0; // UNUSED tex_io[3];

  assign tex_io[0] =
    (uio_oe[1] == 1)  ? uio_out[1]  // raybox-zero is asserting an output.
                      : 1'bz;       // raybox-zero is reading (or not using).

`ifdef GL_TEST
  wire VPWR = 1'b1;
  wire VGND = 1'b0;
`endif

  tt_um_algofoogle_raybox_zero user_project (

      // Include power ports for the Gate Level test:
`ifdef GL_TEST
      .VPWR(VPWR),
      .VGND(VGND),
`endif

      .ui_in  (ui_in),    // Dedicated inputs
      .uo_out (uo_out),   // Dedicated outputs
      .uio_in (uio_in),   // IOs: Input path
      .uio_out(uio_out),  // IOs: Output path
      .uio_oe (uio_oe),   // IOs: Enable path (active high: 0=input, 1=output)
      .ena    (ena),      // enable - goes high when design is selected
      .clk    (clk),      // clock
      .rst_n  (rst_n)     // not reset
  );

  // Connect our relevant TT pins to our texture SPI flash ROM:
  W25Q128JVxIM texture_rom(
      .DIO    (tex_io[0]),  // SPI io0 (MOSI) - BIDIRECTIONAL
      .DO     (tex_io[1]),  // SPI io1 (MISO)
      .WPn    (tex_io[2]),  // SPI io2
      //.HOLDn  (1'b1),     // SPI io3. //NOTE: Not used in raybox-zero.
      .CSn    (tex_csb),    // SPI /CS
      .CLK    (tex_sclk)    // SPI SCLK
  );

endmodule
