module spi_crc_generator (
    // Inputs
    input  wire  [47:6] tx_data_no_crc, // Top 42 bits of the TX frame
    // Outputs
    output logic [5:0]  tx_crc          // 6-bit generated CRC
);

    logic [5:0] crc_calc; // Internal variable for the unrolled LFSR

    always_comb begin
        crc_calc = 6'b111111; // Initialize to all 1s

        for (int i = 47; i >= 6; i--) begin
            // If the MSB XOR current frame bit is 1, shift and XOR polynomial
            if (crc_calc[5] ^ tx_data_no_crc[i]) begin
                crc_calc = {crc_calc[4:0], 1'b0} ^ 6'b100111;
            end else begin
                // Otherwise, just shift
                crc_calc = {crc_calc[4:0], 1'b0};
            end
        end

        // Drive the final calculated values to the output ports
        tx_crc = crc_calc;
    end

endmodule