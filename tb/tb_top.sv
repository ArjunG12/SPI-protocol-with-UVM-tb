`timescale 1ns/1ps
`include "uvm_macros.svh"
import uvm_pkg::*;

module tb_top;
 
    // -------------------------------------------------------------------------
    // System clock: 20 MHz  →  50 ns period (25 ns half-period)
    // -------------------------------------------------------------------------
    logic sys_clk;
 
    initial sys_clk = 1'b0;
    always #25ns sys_clk = ~sys_clk;
 
    // -------------------------------------------------------------------------
    // Interface instance
    //   pi_sck is a plain logic INSIDE the interface (not a port).
    //   The driver writes vif.pi_sck directly — no conflict.
    //   sys_clk is the only port.
    // -------------------------------------------------------------------------
    spi_if u_spi_if (.sys_clk(sys_clk));
 
    // -------------------------------------------------------------------------
    // DUT
    //   All SPI signals and hw_fault_in are wired through the interface.
    //   sys_clk is driven independently so both the DUT and the interface
    //   receive the same physical net.
    // -------------------------------------------------------------------------
    spi_slave_top u_dut (
        .sys_clk     (sys_clk),
        .sys_rst_n   (u_spi_if.sys_rst_n),
        .pi_sck      (u_spi_if.pi_sck),
        .pi_csn      (u_spi_if.pi_csn),
        .pi_mosi     (u_spi_if.pi_mosi),
        .po_miso     (u_spi_if.po_miso),
        .po_miso_oe  (u_spi_if.po_miso_oe),
        .hw_fault_in (u_spi_if.hw_fault_in)
    );

    // Reset/default stimulus. Keep reset asserted long enough for the
    // system-clock and SPI-clock domain state to start from known values.
    initial begin
        u_spi_if.sys_rst_n   = 1'b0;
        u_spi_if.hw_fault_in = 32'h0;
        u_spi_if.pi_csn      = 1'b1;
        u_spi_if.pi_mosi     = 1'b0;
        u_spi_if.pi_sck      = 1'b1;

        repeat (5) @(posedge sys_clk);
        u_spi_if.sys_rst_n = 1'b1;
    end
 
    // -------------------------------------------------------------------------
    // UVM kickoff
    //   1. Publish the virtual-interface handle so every component that calls
    //      uvm_config_db#(virtual spi_if)::get(..., "spi_vif", vif) finds it.
    //   2. run_test() picks the test class from +UVM_TESTNAME at runtime,
    //      or falls back to the string argument when the plusarg is absent.
    // -------------------------------------------------------------------------
    initial begin
        uvm_config_db #(virtual spi_if)::set(
            null,              // registering context: top-level (null = uvm_root)
            "uvm_test_top.*",  // path scope: test + all descendants
            "spi_vif",         // key — must match the ::get() call in driver/monitor
            u_spi_if           // value: the actual interface handle
        );
 
        run_test("spi_write_read_test");
    end
 
    // -------------------------------------------------------------------------
    // Safety timeout
    //   Kills the simulation if a test hangs (missed objection drop, deadlock
    //   in a sequence, etc.).  Adjust the limit to suit the longest test.
    // -------------------------------------------------------------------------
    initial begin
        #5ms;
        `uvm_fatal("TB_TIMEOUT",
            "Simulation exceeded 5 ms — check for dropped objections or deadlock")
    end
 
    // -------------------------------------------------------------------------
    // Waveform capture
    // -------------------------------------------------------------------------
    initial begin
        $dumpfile("spi_uvm_tb.vcd");
        $dumpvars(0, tb_top);
    end
 
endmodule
