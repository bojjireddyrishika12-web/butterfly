import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

@cocotb.test()
async def test_ntt_butterfly(dut):
    # Establish system clock driving at 10 MHz periods
    clock = Clock(dut.clk, 100, units="ns")
    cocotb.start_soon(clock.start())

    # Initialization stage
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    
    # Pulse Asynchronous Hardware Reset
    dut.rst_n.value = 0
    await Timer(200, units="ns")
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test Case 1: Standard Modular Operations
    # Input Values: A = 10, B = 4, W = 3
    # Anticipated math: 
    # B * W = 12
    # X = (10 + 12) mod 3329 = 22
    # Y = (10 - 12) mod 3329 = -2 + 3329 = 3327 (Lower 8-bits: 3327 & 0xFF = 0xFF = 255)
    dut.ui_in.value = 10                       # A_in
    dut.uio_in.value = (3 << 4) | (4 & 0x0F)   # W_in = 3 (upper), B_in = 4 (lower)
    
    await RisingEdge(dut.clk)
    await Timer(1, units="ns") # Allow signals to settle
    
    assert int(dut.uo_out.value) == 22, f"X Error: Got {int(dut.uo_out.value)}, expected 22"
    assert int(dut.uio_out.value) == 255, f"Y Error: Got {int(dut.uio_out.value)}, expected 255"
    
    dut._log.info("NTT Butterfly Core verification successfully verified and passed!")
