/*
 * Copyright (c) 2025 Anton Maurovic
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none
// `timescale 1ns / 1ps

module tt_um_algofoogle_raybox_zero (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

  // List all unused inputs to prevent warnings
  wire _unused = &{uio_in[3], uio_in[0], ena, 1'b0};

  wire  [5:0] rgb;
  wire        vsync_n, hsync_n;
  reg   [7:0] registered_vga_output;
  wire  [7:0] unregistered_vga_output = {
    // Original `rgb` order is {BbGgRr}. Map this order, plus H/Vsync, per Tiny VGA PMOD
    // (https://tinytapeout.com/specs/pinouts/#vga-output):
    hsync_n, rgb[4], rgb[2], rgb[0], // [7:4] = {hbgr}
    vsync_n, rgb[5], rgb[3], rgb[1]  // [3:0] = {vBGR}
  };

  always @(posedge clk) registered_vga_output <= unregistered_vga_output;

  wire [9:0] hpos, vpos;

  wire spi_sclk       = ui_in[0];
  wire spi_mosi       = ui_in[1];
  wire spi_csb        = ui_in[2];
  wire debug          = ui_in[3];
  wire inc_px         = ui_in[4];
  wire inc_py         = ui_in[5];
  wire i_reg          = ui_in[6];
  wire tex_pmod_type  = ui_in[7];
  //NOTE: For tex_pmod_type:
  //   0=Moser's QSPI PMOD; can have a weak pull-up on uio[5] (io3), and ensure io3 bits are 1 in ROM to avoid GEN_TEXb. NOTE: Looks like there are jumpers to enable/disable the chips...?
  //   1=Digilent SPI PMOD; hence expect uio[5] (RSTb) is weakly pulled up anyway, but can be pulled low for GEN_TEXb instead.

  wire tex_csb;
  wire tex_out0;
  wire tex_oeb0;
  wire tex_sclk;
  wire [3:0] tex_in = 
    tex_pmod_type ?
    {
      // tex_pmod_type==1: Digilent SPI PMOD
      uio_in[7],  // (io3 unused)
      uio_in[6],
      uio_in[2],
      uio_in[1]
    } : {
      // tex_pmod_type==0: Moser's QSPI PMOD
      uio_in[5],  // (io3 unused)
      uio_in[4],
      uio_in[2],
      uio_in[1]
    };

  wire gen_tex = tex_pmod_type ?
    ~uio_in[5] :  // gen_tex (actually gen_texb) can be used in 'Digilent SPI PMOD'-mode.
    1'b0;         // Disable gen_tex when using Moser's QSPI PMOD.

  assign uo_out = i_reg ? registered_vga_output : unregistered_vga_output;

  rbzero rbzero(
    .clk        (clk),
    .reset      (~rst_n),

    // SPI peripheral for POV and REG access:
    .i_reg_sclk (spi_sclk),
    .i_reg_mosi (spi_mosi),
    .i_reg_ss_n (spi_csb),

    // SPI controller interface for reading SPI flash memory (i.e. textures):
    .o_tex_csb  (tex_csb),
    .o_tex_sclk (tex_sclk),
    .o_tex_out0 (tex_out0),
    .o_tex_oeb0 (tex_oeb0), // Direction control for io[0] (WARNING: OEb, not OE).
    .i_tex_in   (tex_in), //NOTE: io[3] is unused, currently.
    
    // Debug/demo signals:
    .i_debug_m  (debug), // Map debug overlay
    .i_debug_t  (debug), // Trace debug overlay
    .i_debug_v  (debug), // Vectors debug overlay
    .i_inc_px   (inc_px),
    .i_inc_py   (inc_py),
    .i_gen_tex  (gen_tex), // 1=Use bitwise-generated textures instead of SPI texture memory.
    // .o_vinf     (vinf),
    // .o_hmax     (hmax),
    // .o_vmax     (vmax),
    // VGA outputs:
    // .o_hblank   (uio_out[0]),
    // .o_vblank   (uio_out[1]),
    .hpos       (hpos),
    .vpos       (vpos),
    .hsync_n    (hsync_n), // Unregistered.
    .vsync_n    (vsync_n), // Unregistered.
    .rgb        (rgb)
  );

  // 1 = output, 0 = input:
  //NOTE: Only uio_oe[7:6] directions are different between these two sets,
  // but both are included in full to help highlight their pin differences.
  assign uio_oe = 
    tex_pmod_type ?
    {
      // tex_pmod_type==1: Digilent SPI PMOD
      1'b0,       // uio[7]: tex_io3        input (UNUSED).
      1'b0,       // uio[6]: tex_io2        input.
      1'b0,       // uio[5]: gen_texb       input.
      1'b0,       // uio[4]: SPARE          input.
      1'b1,       // uio[3]: tex_sclk       OUTPUT.
      1'b0,       // uio[2]: tex_io1        input.
      ~tex_oeb0,  // uio[1]: tex_io0        BIDIRECTIONAL. Inverted; rbzero gives OEb, need OE.
      1'b1        // uio[0]: tex_csb        OUTPUT.
    } : {
      // tex_pmod_type==0: Moser's QSPI PMOD
      1'b1,       // uio[7]: CS2            OUTPUT.
      1'b1,       // uio[6]: CS1            OUTPUT.
      1'b0,       // uio[5]: tex_io3        input (UNUSED).
      1'b0,       // uio[4]: tex_io2        input.
      1'b1,       // uio[3]: tex_sclk       OUTPUT.
      1'b0,       // uio[2]: tex_io1        input.
      ~tex_oeb0,  // uio[1]: tex_io0        BIDIRECTIONAL. Inverted; rbzero gives OEb, need OE.
      1'b1        // uio[0]: tex_csb        OUTPUT.
    };

  assign uio_out =
    tex_pmod_type ?
    {
      // tex_pmod_type==1: Digilent SPI PMOD
      1'b0,       // uio[7]: 
      1'b0,       // uio[6]: 
      1'b0,       // uio[5]: 
      1'b0,       // uio[4]: 
      tex_sclk,   // uio[3]: tex_sclk
      1'b0,       // uio[2]: 
      tex_out0,   // uio[1]: tex_io0 (BIDIR)
      tex_csb     // uio[0]: tex_csb
    } : {
      // tex_pmod_type==0: Moser's QSPI PMOD
      1'b1,       // uio[7]: CS2 (permanently high, i.e. disabled)
      1'b1,       // uio[6]: CS1 (permanently high, i.e. disabled)
      1'b0,       // uio[5]: 
      1'b0,       // uio[4]: 
      tex_sclk,   // uio[3]: tex_sclk
      1'b0,       // uio[2]: 
      tex_out0,   // uio[1]: tex_io0 (BIDIR)
      tex_csb     // uio[0]: tex_csb
    };

endmodule
