module spi_tx_formatter (
    input  wire        ff,
    input  wire        v,
    input  wire [3:0]  rc,
    input  wire [31:0] reg_read_data,
    input  wire [5:0]  tx_crc,
    output logic [47:0] miso_frame_out
);

    assign miso_frame_out = {4'd0, ff, v, rc, reg_read_data, tx_crc};

endmodule