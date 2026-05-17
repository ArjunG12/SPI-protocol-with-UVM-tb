module spi_slave_top (
    // System Domain
    input  wire        sys_clk,       // 20MHz system clock
    input  wire        sys_rst_n,     // Asynchronous reset (active low)
    // SPI Pins
    input  wire        pi_sck,        // SPI clock (Mode 3)
    input  wire        pi_csn,        // Chip select (active low)
    input  wire        pi_mosi,       // Master Out Slave In
    output wire        po_miso,       // Master In Slave Out
    output wire        po_miso_oe,    // MISO output enable
    // Hardware Fault Interface
    input  wire [31:0] hw_fault_in    // Hardware fault signals (set bits in status reg)
);

    // -------------------------------------------------------------------------
    // Internal Wires
    // -------------------------------------------------------------------------

    // RX path (SPI domain)
    wire [47:0] mosi_frame;
    wire [47:0] mosi_payload_held;
    wire        rx_done_pulse;
    wire        rx_done_held;
    wire        frame_err;
    wire        frame_err_held;

    // Frame decoder (combinational)
    wire [5:0]  rx_addr;
    wire [1:0]  rx_cmd;
    wire [1:0]  rx_hc;
    wire [31:0] rx_data;
    wire [5:0]  rx_crc;

    // CRC checker (combinational)
    wire        crc_error;
    wire [5:0]  crc_computed;

    // CDC
    wire        write_en_pulse_sys;

    // Controller (system domain)
    wire        v_bit;
    wire [3:0]  rc;
    wire        reg_write_en;

    // Register map (system domain)
    wire [31:0] reg_read_data;
    wire        ff;

    // TX path (combinational + SPI domain)
    wire [47:6] tx_data_no_crc;
    wire [5:0]  tx_crc;
    wire [47:0] miso_frame;

    // CSN synchronizer for quasi-static freeze
    logic       csn_meta;
    logic       csn_sync;
    wire        spi_active_sync;

    // -------------------------------------------------------------------------
    // 2-Flop Synchronizer for pi_csn -> spi_active_sync
    // -------------------------------------------------------------------------
    always_ff @(posedge sys_clk or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            csn_meta <= 1'b1;  // Idle high
            csn_sync <= 1'b1;
        end
        else begin
            csn_meta <= pi_csn;
            csn_sync <= csn_meta;
        end
    end

    // spi_active_sync = 1 when CSN is low (SPI transaction in progress)
    assign spi_active_sync = ~csn_sync;

    // -------------------------------------------------------------------------
    // 1. RX Shift Register (SPI Domain)
    // -------------------------------------------------------------------------
    spi_rx_shift_reg u_rx_shift_reg (
        .sys_rst_n        (sys_rst_n),
        .pi_sck           (pi_sck),
        .pi_csn           (pi_csn),
        .pi_mosi          (pi_mosi),
        .mosi_frame_out   (mosi_frame),
        .mosi_payload_held(mosi_payload_held),
        .rx_done_pulse    (rx_done_pulse),
        .rx_done_held     (rx_done_held),
        .frame_err        (frame_err),
        .frame_err_held   (frame_err_held)
    );

    // -------------------------------------------------------------------------
    // 2. Frame Decoder (Combinational)
    // -------------------------------------------------------------------------
    spi_frame_decoder u_frame_decoder (
        .mosi_data (mosi_payload_held),
        .rx_addr   (rx_addr),
        .rx_cmd    (rx_cmd),
        .rx_hc     (rx_hc),
        .rx_data   (rx_data),
        .rx_crc    (rx_crc)
    );

    // -------------------------------------------------------------------------
    // 3. CRC Checker (Combinational)
    // -------------------------------------------------------------------------
    spi_crc_checker u_crc_checker (
        .frame      (mosi_payload_held),
        .crc_error  (crc_error),
        .crc        (crc_computed)
    );

    // -------------------------------------------------------------------------
    // 4. CDC Toggle Synchronizer (SPI -> System Domain)
    // -------------------------------------------------------------------------
    spi_cdc_sync u_cdc_sync (
        .pi_sck             (pi_sck),
        .pi_csn             (pi_csn),
        .rx_done_pulse      (rx_done_pulse),
        .sys_clk            (sys_clk),
        .sys_rst_n          (sys_rst_n),
        .write_en_pulse_sys (write_en_pulse_sys)
    );

    // -------------------------------------------------------------------------
    // 5. Slave Controller (System Domain)
    // -------------------------------------------------------------------------
    spi_slave_ctrl u_slave_ctrl (
        .sys_clk            (sys_clk),
        .sys_rst_n          (sys_rst_n),
        .write_en_pulse_sys (write_en_pulse_sys),
        .crc_error          (crc_error),
        .frame_err          (frame_err_held),
        .rx_cmd             (rx_cmd),
        .v_bit              (v_bit),
        .rc                 (rc),
        .reg_write_en       (reg_write_en)
    );
    logic v_bit_prev;
    always@(negedge pi_csn)begin
        v_bit_prev<=v_bit;
    end
    // -------------------------------------------------------------------------
    // 6. Register Map (System Domain)
    // -------------------------------------------------------------------------
    spi_reg_map u_reg_map (
        .sys_clk            (sys_clk),
        .sys_rst_n          (sys_rst_n),
        .spi_active_sync    (spi_active_sync),
        .write_en_pulse_sys (reg_write_en),
        .rx_addr            (rx_addr),
        .rx_data            (rx_data),
        .hw_fault_in        (hw_fault_in),
        .reg_read_data      (reg_read_data),
        .ff                 (ff)
    );

    // -------------------------------------------------------------------------
    // 7. TX CRC Generator (Combinational)
    //    Feed the upper 42 bits BEFORE CRC is appended to break
    //    the circular dependency.
    // -------------------------------------------------------------------------
    assign tx_data_no_crc = {4'd0, ff, v_bit_prev, rc, reg_read_data};

    spi_crc_generator u_crc_gen (
        .tx_data_no_crc (tx_data_no_crc),
        .tx_crc         (tx_crc)
    );

    // -------------------------------------------------------------------------
    // 8. TX Frame Formatter (Combinational)
    // -------------------------------------------------------------------------
    spi_tx_formatter u_tx_formatter (
        .ff             (ff),
        .v              (v_bit_prev),
        .rc             (rc),
        .reg_read_data  (reg_read_data),
        .tx_crc         (tx_crc),
        .miso_frame_out (miso_frame)
    );

    // -------------------------------------------------------------------------
    // 9. TX Shift Register (SPI Domain)
    // -------------------------------------------------------------------------
    spi_tx_shift_reg u_tx_shift_reg (
        .sys_rst_n      (sys_rst_n),
        .pi_sck         (pi_sck),
        .pi_csn         (pi_csn),
        .miso_frame_in  (miso_frame),
        .po_miso        (po_miso),
        .po_miso_oe     (po_miso_oe)
    );

endmodule