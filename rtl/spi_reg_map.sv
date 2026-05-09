module spi_reg_map (
    input  wire        sys_clk,
    input  wire        sys_rst_n,
    input  wire        spi_active_sync,
    input  wire        write_en_pulse_sys,
    input  wire [5:0]  rx_addr,
    input  wire [31:0] rx_data,
    input  wire [31:0] hw_fault_in,
    output logic [31:0] reg_read_data,
    output logic        ff
);

    logic [31:0] status_reg;
    logic [31:0] rw_regs [1:31];
    logic [1:0] write_en_pulse_sys_buff;
    assign ff = |status_reg;

    assign reg_read_data = (rx_addr == 6'd0)  ? status_reg :
                           (rx_addr <= 6'd31) ? rw_regs[rx_addr] :
                                                32'hFEDCBA98;
    
    always_ff @(posedge sys_clk,negedge sys_rst_n)begin
        if(!sys_rst_n)write_en_pulse_sys_buff<=0;
        else begin
            write_en_pulse_sys_buff<={write_en_pulse_sys_buff[0],write_en_pulse_sys};
        end
    end
    
    always_ff @(posedge sys_clk or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            status_reg <= 32'h0;
            for (int i = 1; i < 32; i++) begin
                rw_regs[i] <= 32'h0;
            end
        end
        else begin
            // 1. Status Register (Address 0)
            // HW faults are ALWAYS accumulated, regardless of SPI state
            if (!spi_active_sync && write_en_pulse_sys_buff[1] && (rx_addr == 6'd0)) begin
                // W1C logic COMBINED with Hardware Set
                status_reg <= (status_reg & ~rx_data) | hw_fault_in;
            end else begin
                // No SPI write - just accumulate hardware faults
                status_reg <= status_reg | hw_fault_in;
            end

            // 2. RW Registers (Addresses 1 to 31) - frozen during SPI active
            if (write_en_pulse_sys_buff[1] && (rx_addr > 6'd0) && (rx_addr < 6'd32)) begin
                rw_regs[rx_addr] <= rx_data;
            end
        end
    end
endmodule
