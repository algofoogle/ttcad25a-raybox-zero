# SPDX-FileCopyrightText: © 2025 Anton Maurovic
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, ClockCycles
import time
from os import environ as env
import re

HIGH_RES        = float(env.get('HIGH_RES')) if 'HIGH_RES' in env else None # If not None, scale H res by this, and step by CLOCK_PERIOD/HIGH_RES instead of unit clock cycles.
CLOCK_PERIOD    = float(env.get('CLOCK_PERIOD') or 40.0) # Default 40.0 (period of clk oscillator input, in nanoseconds)
FRAMES          =   int(env.get('FRAMES')       or   18) # Default 18 (total frames to render)
INC_PX          =   int(env.get('INC_PX')       or    1) # Default 1 (inc_px on)
INC_PY          =   int(env.get('INC_PY')       or    1) # Default 1 (inc_py on)
GEN_TEX         =   int(env.get('GEN_TEX')      or    0) # Default 0 (use tex ROM; no generated textures)
DEBUG_POV       =   int(env.get('DEBUG_POV')    or    1) # Default 1 (show POV vectors debug)
REG             =   int(env.get('REG')          or    0) # Default 0 (UNregistered outputs)

print(f"""
Test parameters (can be overridden using ENV vars):
---     HIGH_RES: {HIGH_RES}
--- CLOCK_PERIOD: {CLOCK_PERIOD}
---       FRAMES: {FRAMES}
---       INC_PX: {INC_PX}
---       INC_PY: {INC_PY}
---      GEN_TEX: {GEN_TEX}
---    DEBUG_POV: {DEBUG_POV}
---          REG: {REG}
""")

# Make sure all bidir pins are configured as they should be,
# for this design:
def check_uio_out(dut):
    # Make sure 2 LSB are outputs,
    # and all but [5] (bidir) of the rest are inputs:
    assert re.match('000010.1', dut.uio_oe.value.binstr)

# This can represent hard-wired stuff:
def set_default_start_state(dut):
    dut.ena.value                   = 1
    # REG SPI interface inactive:
    dut.spi_sclk.value              = 1
    dut.spi_mosi.value              = 1
    dut.spi_csb.value               = 1
    # Enable debug display on-screen?
    dut.debug.value                 = DEBUG_POV
    # Enable demo mode(s) (player position auto-increment)?
    dut.inc_px.value                = INC_PX
    dut.inc_py.value                = INC_PY
    # Use generated textures instead of external texture SPI memory?
    dut.tex_pmod_type.value         = 1 # Digilent SPI PMOD.
    dut.gen_texb.value              = not GEN_TEX
    # Present registered outputs?
    dut.registered_outputs.value    = REG


class SPI:
    def __init__(self, dut, interface):
        self.dut = dut
        self.interface = interface
        if interface == 'reg':
            self.csb  = dut.spi_csb
            self.sclk = dut.spi_sclk
            self.mosi = dut.spi_mosi
        # elif interface == 'pov':
        #     self.csb = dut.pov_ss_n
        #     self.sclk = dut.pov_sclk
        #     self.mosi = dut.pov_mosi
        else:
            raise ValueError(f"Invalid interface {repr(interface)}; must be 'reg'")

    def __repr__(self):
        return f'SPI({self.interface})'

    async def spi_tick(self):
        # SPI interface expected to be stable at up to 20% of clock speed:
        await Timer(CLOCK_PERIOD*5.0, units='ns')

    async def txn_start(self):
        self.csb.value = 1
        self.sclk.value = 0
        await self.spi_tick()
        self.csb.value = 0 # Active low.
    
    async def txn_send(self, data, count=None):
        if type(data) is int:
            data = bin(data)
            data = data[2:]
            if count is None:
                self.dut._log(f"WARNING: SPI.send_bits() called with int data {data} but no count")
        
        if count is not None:
            data = data.zfill(count)

        while len(data) > 0:
            self.mosi.value = int(data[0])
            data = data[1:]
            await self.spi_tick()
            self.sclk.value = 1 # Rising edge; clock in the bit.
            await self.spi_tick()
            self.sclk.value = 0 # Falling edge.

    async def txn_stop(self):
        await self.spi_tick()
        # Disable CSb; we're done:
        self.csb.value = 1
        self.sclk.value = 0
        await self.spi_tick()
    

async def spi_send_reg(dut, cmd, data, count=None, what=''):
    dut._log.info(f"spi_send_reg({repr(cmd)}, {repr(data)}) started [{what}]...")
    spi = SPI(dut, 'reg')
    await spi.txn_start()
    await spi.txn_send(cmd, 8)
    await spi.txn_send(data, count)
    await spi.txn_stop()
    dut._log.info(f"spi_send_reg() [{what}] DONE")


async def spi_send_pov(dut, data, what=''):
    dut._log.info(f"spi_send_pov({repr(data)}) started [{what}]...")
    spi = SPI(dut, 'reg')
    await spi.txn_start()
    await spi.txn_send(127, 8) # 127==CMD_POV
    await spi.txn_send(data, 74)
    await spi.txn_stop()
    dut._log.info(f"spi_send_pov() [{what}] DONE")


# async def spi_send_pov(dut, data, what=''):
#     dut._log.info(f"spi_send_pov({repr(data)}) started [{what}]...")
#     spi = SPI(dut, 'pov')
#     await spi.txn_start()
#     await spi.txn_send(data, 74)
#     await spi.txn_stop()
#     dut._log.info(f"spi_send_pov() [{what}] DONE")


@cocotb.test()
async def test_frames(dut):
    """
    Generate a number of full video frames and write to rbz_basic_frame-###.ppm
    """

    dut._log.info("Starting test_frames...")

    frame_count = FRAMES # No. of frames to render.
    hrange = 800
    frame_height = 525
    vrange = frame_height
    hres = HIGH_RES or 1

    print(f"Rendering {frame_count} full frame(s)...")

    set_default_start_state(dut)
    # Start with reset released:
    dut.rst_n.value = 1

    clk = Clock(dut.clk, CLOCK_PERIOD, units="ns")
    cocotb.start_soon(clk.start())

    # Wait 3 clocks...
    await ClockCycles(dut.clk, 3)
    check_uio_out(dut)
    dut._log.info("Assert reset...")
    # ...then assert reset:
    dut.rst_n.value = 0
    # ...and wait another 10 clocks...
    await ClockCycles(dut.clk, 10)
    check_uio_out(dut)
    dut._log.info("Release reset...")
    # ...then release reset:
    dut.rst_n.value = 1
    x_count = 0 # Counts unknown signal values.
    z_count = 0
    sample_count = 0 # Total count of pixels or samples.

    for frame in range(frame_count):
        render_start_time = time.time()

        nframe = frame + 1

        # --- Tests we do for each frame ---
        # (NOTE: New states pushed in one frame render in the next,
        # and this has been accounted for in the design below, hence `nframe`):
        # Frame index:
        # 000. Reset frame to initial view (slightly wonky; rayAddend in reset instead of prior vsync)
        # 001. Default behaviour (typically inc_px/py asserted from initial view)
        # 002. Default behaviour again
        # 003. inc_px/py disabled; frame should appear same as #2
        # 004. New POV loaded
        # 005. Should be same as #4
        # 006. inc_px/py reasserted; typically, existing POV should move slightly
        # 007. LEAK enabled
        # 008. VINF enabled
        # 009. LEAK disabled

        # NOTE: Each of these states are asserted at the start of the PRIOR
        # frame since they take effect on the NEXT frame, but the exceptions are
        # those which have an immediate combinatorial effect:
        # - gen_tex
        # - debug
        # - registered_outputs

        # Frame 0 will render as per normal (not really controllable).
        if nframe in [1,2]:
            # Frames 1 & 2 will render per typical design behaviour.
            pass

        elif nframe == 3:
            # Frame 3 will turn off inc_px/py:
            dut.inc_px.value = 0
            dut.inc_py.value = 0
            # ALSO, use the map rectangle register:
            cocotb.start_soon(spi_send_reg(dut, 7,
                '000110' + '001000' +   # mapr_ax/y
                '001100' + '010010' +   # mapr_bx/y
                '1' +                   # mapr_erase
                '110',                  # mapr_wall
                what='Map rectangle'
            ))

        elif nframe == 4:
            # Set up a nice view for this frame.
            cocotb.start_soon(spi_send_pov(dut, '00110100011011100011111011011000000111101110000001000001111111000000011110', what='a nice POV'))

        elif nframe == 5:
            # Keep the same view as last time.
            pass

        elif nframe == 6:
            # Reassert inc_px/py inputs to see if the view moves...
            dut.inc_px.value = INC_PX
            dut.inc_py.value = INC_PY
            # ...AND change ceiling colour:
            cocotb.start_soon(spi_send_reg(dut, 0, 0b01_00_01, count=6, what='SKY = dark purple'))

        elif nframe == 7:
            # Set a floor leak: Send SPI2 ('reg') command 2 (LEAK) and a corresponding value of 13:
            cocotb.start_soon(spi_send_reg(dut, 2, 13, count=6, what='set a LEAK'))

        elif nframe == 8:
            # Turn on VINF (cmd 5) mode:
            cocotb.start_soon(spi_send_reg(dut, 5, '1'+'0'+'000', what='VINF on, LEAK_FIXED off, map_mode=0'))

        elif nframe == 9:
            # Set VSHIFT to 15:
            cocotb.start_soon(spi_send_reg(dut, 4, 15, count=6, what='VSHIFT=15'))

        elif nframe == 10:
            # Enable LEAK_FIXED:
            cocotb.start_soon(spi_send_reg(dut, 5, '1'+'1'+'000', what='VINF on, LEAK_FIXED on, map_mode=0'))

        elif nframe == 11:
            # Turn off VINF and LEAK_FIXED:
            cocotb.start_soon(spi_send_reg(dut, 5, '0'+'0'+'000', what='VINF off, LEAK_FIXED off, map_mode=0'))

        elif nframe == 12:
            # Turn on generated textures (disable SPI textures; done with dut.gen_texb.value = 0 in IMMEDIATE inputs, below)...
            # ...AND map_mode=2:
            cocotb.start_soon(spi_send_reg(dut, 5, '0'+'0'+'010', what='VINF off, LEAK_FIXED off, map_mode=2'))

        elif nframe == 13:
            # Turn off generated textures (enable SPI textures again; dut.gen_texb.value = 1 in IMMEDIATE inputs, below)...
            # ...AND reset floor leak:
            # Send SPI2 ('reg') command 2 (LEAK) and payload 0:
            cocotb.start_soon(spi_send_reg(dut, 2, 0, count=6, what='LEAK=0'))

        elif nframe == 14:
            # Set MapDivX/Y to 12,3 with wall IDs 7,0:
            cocotb.start_soon(spi_send_reg(dut, 6, '001100'+'000011'+'111'+'000', what='MDX/Y=12,3 WX/Y=7,0'))

        elif nframe == 15:
            # Reset VSHIFT:
            cocotb.start_soon(spi_send_reg(dut, 4, 0, count=6, what='VSHIFT=0'))

        elif nframe == 16:
            # Set TEXADD6 to 30:
            cocotb.start_soon(spi_send_reg(dut, 38, 30, count=24, what='TEXADD6=30')) # NOTE: TEXADD6 is for wallID 7...
            
        elif nframe == 17:
            # Set TEXADD7 to 10:
            cocotb.start_soon(spi_send_reg(dut, 39, 10, count=24, what='TEXADD0=30')) # NOTE: ...TEXADD7 is for wallID 0.


        #TODO: @@@@@@@@@@@@@@@@ MORE FRAMES @@@@@@@@@@@@@@@@@@@@@@@
        # - Change floor/ceiling colours
        # - Show 'dirt village' textures

        # Now handle IMMEDIATE inputs that take effect on the current frame,
        # rather than the next:
        if frame == 12:
            # Turn on gen_tex (disable texture ROM; use generated textures instead):
            dut.gen_texb.value = 0 #NOTE: Immediate, so takes effect ON frame 10, not 11.

        elif frame == 13:
            # Turn off gen_tex (enable texture ROM):
            dut.gen_texb.value = 1 #NOTE: Immediate, so takes effect ON frame 13.

        # Create PPM file to visualise the frame, and write its header:
        img = open(f"frames_out/rbz_basic_frame-{frame:03d}.ppm", "w")
        img.write("P3\n")
        img.write(f"{int(hrange*hres)} {vrange:d}\n")
        img.write("255\n")

        for n in range(vrange): # 525 lines * however many frames in frame_count
            print(f"Rendering line {n} of frame {frame}")
            for n in range(int(hrange*hres)): # 800 pixel clocks per line.
                if n % 100 == 0:
                    print('.', end='')
                if 'x' in dut.rgb.value.binstr:
                    # Output is unknown; make it green:
                    r = 0
                    g = 255
                    b = 0
                elif 'z' in dut.rgb.value.binstr:
                    # Output is HiZ; make it magenta:
                    r = 255
                    g = 0
                    b = 255
                else:
                    rr = dut.rr.value
                    gg = dut.gg.value
                    bb = dut.bb.value
                    hsyncb = 255 if dut.hsync_n.value.binstr=='x' else (0==dut.hsync_n.value)*0b110000
                    vsyncb = 128 if dut.vsync_n.value.binstr=='x' else (0==dut.vsync_n.value)*0b110000
                    r = (rr << 6) | hsyncb
                    g = (gg << 6) | vsyncb
                    b = (bb << 6)
                sample_count += 1
                if 'x' in (dut.rgb.value.binstr + dut.hsync_n.value.binstr + dut.vsync_n.value.binstr):
                    x_count += 1
                if 'z' in (dut.rgb.value.binstr + dut.hsync_n.value.binstr + dut.vsync_n.value.binstr):
                    z_count += 1
                img.write(f"{r} {g} {b}\n")
                if HIGH_RES is None:
                    await ClockCycles(dut.clk, 1) 
                else:
                    await Timer(CLOCK_PERIOD/hres, units='ns')
        img.close()
        render_stop_time = time.time()
        delta = render_stop_time - render_start_time
        print(f"[{render_stop_time}: Frame simulated in {delta} seconds]")
    print("Waiting 1 more clock, for start of next line...")
    await ClockCycles(dut.clk, 1)

    # await toggler

    print(f"DONE: Out of {sample_count} pixels/samples, got: {x_count} 'x'; {z_count} 'z'")

