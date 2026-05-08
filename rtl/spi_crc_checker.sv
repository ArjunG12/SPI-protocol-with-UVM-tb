module spi_crc_checker (
    // Inputs
    input  wire  [47:0] frame,      // 48-bit captured MOSI frame
    // Outputs
    output logic        crc_error,  // 1 if CRC mismatch
    output logic [5:0]  crc         // Calculated CRC value
);

    logic [5:0] crc_calc; // Internal variable for the unrolled LFSR

    always_comb begin
        crc_calc = 6'b111111; // Initialize to all 1s

        for (int i = 47; i >= 6; i--) begin
            // If the MSB XOR current frame bit is 1, shift and XOR polynomial
            if (crc_calc[5] ^ frame[i]) begin
                crc_calc = {crc_calc[4:0], 1'b0} ^ 6'b100111;
            end else begin
                // Otherwise, just shift
                crc_calc = {crc_calc[4:0], 1'b0};
            end
        end

        // Drive the final calculated values to the output ports
        crc = crc_calc;
        crc_error = (crc_calc != frame[5:0]);
    end

endmodule