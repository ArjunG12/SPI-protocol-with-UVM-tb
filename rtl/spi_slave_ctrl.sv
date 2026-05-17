module spi_slave_ctrl (
    // System Domain
    input  wire        sys_clk,            // 20MHz system clock
    input  wire        sys_rst_n,          // Asynchronous reset (active low)
    // Frame Status (latched in sys domain by CDC pulse)
    input  wire        write_en_pulse_sys, // 1-cycle pulse from toggle synchronizer
    input  wire        crc_error,          // CRC mismatch from spi_crc_checker
    input  wire        frame_err,          // Length error from spi_rx_shift_reg
    input  wire [1:0]  rx_cmd,             // Decoded command field
    // Control Outputs
    output logic       v_bit,              // Valid-frame bit for MISO (previous frame was go...
    output logic [3:0] rc,                 // Rolling counter (binary, 4-bit)
    output logic       reg_write_en        // Qualified write enable to register map
);

    // -------------------------------------------------------------------------
    // On every CDC pulse (one per completed SPI frame), evaluate
    // whether the frame that just arrived was error-free.
    // If it was: set V=1, increment RC, and allow the write.
    // If it wasn't: set V=0, hold RC, block the write.
    // -------------------------------------------------------------------------

    logic frame_valid;

    // A frame is valid only when there is no CRC error and no length error
    assign frame_valid = ~crc_error & ~frame_err;

    always_ff @(posedge sys_clk or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            v_bit <= 1'b0;
            rc    <= 4'd0;
        end
        else if (write_en_pulse_sys) begin
            // Update V bit: reflects validity of the frame that just completed
            v_bit <= frame_valid;

            // Increment rolling counter only on a valid frame
            if (frame_valid) begin
                rc <= rc + 4'd1;
            end
        end
    end

    // Qualify the write enable: only allow register writes on valid frames
    // with a WRITE command (CMD == 2'b00 for write per your protocol)
    assign reg_write_en = write_en_pulse_sys & frame_valid & (rx_cmd == 2'b00);

endmodule