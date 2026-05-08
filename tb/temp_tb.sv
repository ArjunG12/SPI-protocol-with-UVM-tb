module temp_tb;

    // -------------------------------------------------------------------------
    // Signals
    // -------------------------------------------------------------------------
    logic        sys_clk;
    logic        sys_rst_n;
    logic        pi_sck;
    logic        pi_csn;
    logic        pi_mosi;
    logic        po_miso;
    logic        po_miso_oe;
    logic [31:0] hw_fault_in;

    // Captured MISO response
    logic [47:0] miso_captured;

    // -------------------------------------------------------------------------
    // DUT
    // -------------------------------------------------------------------------
    spi_slave_top spi_slave (.*);

    // -------------------------------------------------------------------------
    // Clock Generation: 20MHz sys_clk (50ns period)
    // -------------------------------------------------------------------------
    initial sys_clk = 0;
    always #25 sys_clk = ~sys_clk;

    // -------------------------------------------------------------------------
    // SPI Mode 3 defaults: SCK idles HIGH, CSN idles HIGH
    // -------------------------------------------------------------------------
    initial begin
        pi_sck        = 1;
        pi_csn        = 1;
        pi_mosi       = 0;
        hw_fault_in   = 32'd0;
    end

    // -------------------------------------------------------------------------
    // CRC-6 Computation Function
    // Polynomial: x^6+x^5+x^2+x^1+x^0 = 7'b1100111
    // Init: 6'b111111, MSB-first over bits [47:6]
    // -------------------------------------------------------------------------
    function automatic logic [5:0] calc_crc(input logic [47:0] frame);
        logic [5:0] crc;
        crc = 6'b111111;
        for (int i = 47; i >= 6; i--) begin
            if (crc[5] ^ frame[i])
                crc = {crc[4:0], 1'b0} ^ 6'b100111;
            else
                crc = {crc[4:0], 1'b0};
        end
        return crc;
    endfunction

    // -------------------------------------------------------------------------
    // Task: spi_transfer
    // Sends a 48-bit MOSI frame and captures 48-bit MISO response.
    // SPI Mode 3: shift on negedge SCK, sample on posedge SCK.
    // -------------------------------------------------------------------------
    task automatic spi_transfer(
        input  logic [47:0] mosi_frame,
        output logic [47:0] miso_frame
    );
        // Assert CSN - start of frame
        pi_csn = 0;
        #100ns; // tSTLD: CSN low to first SCK edge setup time

        for (int i = 47; i >= 0; i--) begin
            // Drive MOSI on negedge SCK (SCK goes low)
            pi_sck = 0;
            pi_mosi = mosi_frame[i];
            #50ns; // tSCKL: SCK low half-period

            // Rising edge: slave captures MOSI, we capture MISO
            pi_sck = 1;
            miso_frame[i] = po_miso;
            #50ns; // tSCKH: SCK high half-period
        end

        // Deassert CSN - end of frame
        #30ns; // tSTLG: last SCK edge to CSN rise
        pi_csn = 1;
        #1000ns; // tSTRH: CSN high time between frames (idle)
    endtask

    logic [47:0] mosi_frame;
    logic [47:0] miso_response;
    logic [5:0]  crc;

    // -------------------------------------------------------------------------
    // Task: spi_write
    // Builds a WRITE frame (CMD=2'b00) and sends it.
    // -------------------------------------------------------------------------
    task automatic spi_write(
        input logic [5:0]  addr,
        input logic [31:0] wdata
    );
        // Assemble frame: ADDR[47:42], CMD[41:40]=00, HC[39:38]=00, DATA[37:6]
        mosi_frame = {addr, 2'b00, 2'b00, wdata, 6'd0};
        crc = calc_crc(mosi_frame);
        mosi_frame[5:0] = crc;

        $display("[%0t] SPI WRITE: addr=0x%02h, data=0x%08h, crc=0x%02h",
                 $time, addr, wdata, crc);

        spi_transfer(mosi_frame, miso_response);

        $display("[%0t] MISO response: 0x%012h  (FF=%0b, V=%0b, RC=%0d, DATA=0x%08h)",
                 $time,
                 miso_response,
                 miso_response[43],      // FF
                 miso_response[42],      // V
                 miso_response[41:38],   // RC
                 miso_response[37:6]);   // DATA
    endtask

    // -------------------------------------------------------------------------
    // Task: spi_read
    // Builds a READ frame (CMD=2'b01) and sends it.
    // Returns the data from the MISO response.
    // -------------------------------------------------------------------------
    task automatic spi_read(
        input  logic [5:0]  addr,
        output logic [31:0] rdata
    );
        // Assemble frame: ADDR[47:42], CMD[41:40]=01, HC[39:38]=00, DATA[37:6]=don't care, C
        mosi_frame = {addr, 2'b01, 2'b00, 32'd0, 6'd0};
        crc = calc_crc(mosi_frame);
        mosi_frame[5:0] = crc;

        $display("[%0t] SPI READ:  addr=0x%02h, crc=0x%02h",
                 $time, addr, crc);

        spi_transfer(mosi_frame, miso_response);

        rdata = miso_response[37:6];

        $display("[%0t] MISO response: 0x%012h  (FF=%0b, V=%0b, RC=%0d, DATA=0x%08h)",
                 $time,
                 miso_response,
                 miso_response[43],      // FF
                 miso_response[42],      // V
                 miso_response[41:38],   // RC
                 miso_response[37:6]);   // DATA
    endtask

    // -------------------------------------------------------------------------
    // Main Test Sequence
    // -------------------------------------------------------------------------
    initial begin
        logic [31:0] read_data;

        // ---- Reset ----
        sys_rst_n = 0;
        #200ns;
        sys_rst_n = 1;
        #200ns;

        $display("===================================================================");
        $display("  TEST 1: Write 0xDEAD_BEEF to Register 5");
        $display("===================================================================");
        spi_write(6'd5, 32'hDEAD_BEEF);

        // Wait for system domain to process the write
        repeat (10) @(posedge sys_clk);

        $display("===================================================================");
        $display("  TEST 2: Read back Register 5");
        $display("===================================================================");
        spi_read(6'd5, read_data);

        repeat (10) @(posedge sys_clk);

        // Check
        if (read_data == 32'hDEAD_BEEF)
            $display("[PASS] Register 5 readback matches: 0x%08h", read_data);
        else
            $display("[FAIL] Register 5 readback mismatch: expected 0xDEAD_BEEF, got 0x%08h", read_data);

        $display("===================================================================");
        $display("  TEST 3: Write 0x1234_5678 to Register 10");
        $display("===================================================================");
        spi_write(6'd10, 32'h12345678);

        repeat (10) @(posedge sys_clk);

        $display("===================================================================");
        $display("  TEST 4: Read back Register 10");
        $display("===================================================================");
        spi_read(6'd10, read_data);

        repeat (10) @(posedge sys_clk);

        if (read_data == 32'h12345678)
            $display("[PASS] Register 10 readback matches: 0x%08h", read_data);
        else
            $display("[FAIL] Register 10 readback mismatch: expected 0x12345678, got 0x%08h", read_data);

        $display("===================================================================");
        $display("  TEST 5: Read Register 5 again (should still be DEADBEEF)");
        $display("===================================================================");
        spi_read(6'd5, read_data);

        repeat (10) @(posedge sys_clk);

        if (read_data == 32'hDEAD_BEEF)
            $display("[PASS] Register 5 still holds: 0x%08h", read_data);
        else
            $display("[FAIL] Register 5 changed unexpectedly: 0x%08h", read_data);

        $display("===================================================================");
        $display("  TEST 6: V-bit and RC check");
        $display("  (After 5 valid frames, V should be 1 and RC should be 5)");
        $display("===================================================================");
        // We've done 5 frames (write, read, write, read, read).
        // The MISO of the *next* frame will reflect V=1 and RC=5.
        spi_read(6'd0, read_data);

        repeat (10) @(posedge sys_clk);

        $display("===================================================================");
        $display("  All tests complete.");
        $display("===================================================================");

        #500ns;
        $finish;
    end

    // -------------------------------------------------------------------------
    // Waveform dump
    // -------------------------------------------------------------------------
    initial begin
        $dumpfile("spi_slave_tb.vcd");
        $dumpvars(0, temp_tb);
    end

endmodule
