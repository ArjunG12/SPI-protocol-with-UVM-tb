module spi_rx_shift_reg (
    // Inputs
    input  wire        sys_rst_n,      // Asynchronous reset (active low)
    input  wire        pi_sck,         // SPI clock
    input  wire        pi_csn,         // Chip select / Frame enable (active low)
    input  wire        pi_mosi,        // Serial data input
    // Outputs
    output logic [47:0] mosi_frame_out,    // Live shift register (cleared by CSN)
    output logic [47:0] mosi_payload_held, // Held frame - stable after CSN deasserts
    output logic        rx_done_pulse,     // High when exactly 48 bits received
    output logic        rx_done_held,      // Held copy - stable after CSN deasserts
    output logic        frame_err,         // High if >48 bits received
    output logic        frame_err_held     // Held copy - stable after CSN deasserts
);

    logic [5:0] counter;
    logic       spi_rst_n;

    assign spi_rst_n = sys_rst_n & ~pi_csn;

    // -------------------------------------------------------------------------
    // Live shift register - resets when CSN goes high (between frames)
    // -------------------------------------------------------------------------
    always_ff @(posedge pi_sck or negedge spi_rst_n) begin
        if (!spi_rst_n) begin
            mosi_frame_out <= 48'd0;
            counter        <= 6'd0;
        end
        else begin
            mosi_frame_out[46-counter] <= pi_mosi;
            if (counter < 6'd49) begin
                counter <= counter + 6'd1;
            end
        end
    end
    
    // NOTE: These use counter == 47 (not 48) because all posedge pi_sck
    // blocks read the OLD (pre-update) counter value due to non-blocking
    // assignments. At the 48th SCK edge, the old counter is 47.
    // The holding register and CDC toggle sample these signals at the
    // same posedge, so the comparison must match the pre-update value.
    assign rx_done_pulse = (counter == 6'd47);
    assign frame_err     = (counter > 6'd47);

    // -------------------------------------------------------------------------
    // Holding register - NOT reset by pi_csn.
    // Captures the frame at rx_done_pulse and holds it stable
    // so the system clock domain can safely read it after CSN deasserts.
    // -------------------------------------------------------------------------
    always_ff @(posedge pi_sck or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            mosi_payload_held <= 48'd0;
            rx_done_held      <= 1'b0;
            frame_err_held    <= 1'b0;
        end
        else if (rx_done_pulse) begin
            
            rx_done_held      <= 1'b1;
            frame_err_held    <= 1'b0;
        end
        else if (frame_err) begin
            frame_err_held    <= 1'b1;
        end
        mosi_payload_held <= {mosi_frame_out[46:0], pi_mosi};
    end

endmodule