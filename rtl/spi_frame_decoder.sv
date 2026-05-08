module spi_frame_decoder (
    // Inputs
    input  wire  [47:0] mosi_data, // 48-bit captured MOSI frame
    // Outputs
    output logic [5:0]  rx_addr,   // 6-bit register address
    output logic [1:0]  rx_cmd,    // 2-bit command
    output logic [1:0]  rx_hc,     // 2-bit header count
    output logic [31:0] rx_data,   // 32-bit payload
    output logic [5:0]  rx_crc     // 6-bit received CRC
);

    //internal parameters
    
    localparam ADDR_MSB = 47;
    localparam ADDR_LSB = 42;
    
    localparam CMD_BIT_MSB = 41;
    localparam CMD_BIT_LSB = 40;
    
    localparam HC_MSB    = 39;
    localparam HC_LSB    = 38;
    
    localparam DATA_MSB  = 37;
    localparam DATA_LSB  = 6;
    
    localparam CRC_MSB   = 5;
    localparam CRC_LSB   = 0;

    assign rx_addr = mosi_data[ADDR_MSB : ADDR_LSB];
    assign rx_cmd  = mosi_data[CMD_BIT_MSB:CMD_BIT_LSB];
    assign rx_hc   = mosi_data[HC_MSB:HC_LSB];
    assign rx_data = mosi_data[DATA_MSB:DATA_LSB];
    assign rx_crc  = mosi_data[CRC_MSB:CRC_LSB];

endmodule