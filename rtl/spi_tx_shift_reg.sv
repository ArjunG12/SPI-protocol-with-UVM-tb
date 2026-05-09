module spi_tx_shift_reg (
    input  wire        sys_rst_n,
    input  wire        pi_sck,
    input  wire        pi_csn,
    input  wire [47:0] miso_frame_in,
    output logic       po_miso,
    output logic       po_miso_oe
);
    logic       po_miso_r;
    logic       spi_rst_n;
    logic [5:0] bit_index;

    assign spi_rst_n = sys_rst_n & ~pi_csn;
    assign po_miso_oe = ~pi_csn;

    always_ff @(negedge pi_sck or negedge spi_rst_n) begin
        if (!spi_rst_n) begin
            bit_index <= 6'd47;
            po_miso_r  <= miso_frame_in[47];
        end
        else 
        begin
             po_miso_r <= miso_frame_in[bit_index]; 
            if (bit_index > 6'd0) begin
                bit_index <= bit_index - 6'd1;
            end
        end
    end

    assign po_miso = po_miso_r;

endmodule
