module spi_cdc_sync (
  // Inputs (SPI Domain)
  input  wire pi_sck,          // SPI clock
  input  wire pi_csn,          // SPI Chip Select (Active low)
  input  wire rx_done_pulse,   // 1-cycle pulse in SPI domain
  // Inputs (System Domain)
  input  wire sys_clk,         // 20MHz System clock
  input  wire sys_rst_n,       // Global asynchronous reset (Active low)
  // Outputs
  output logic write_en_pulse_sys // 1-cycle pulse in System domain
);

  logic spi_rst_n;
  logic pi_q, sys_q1, sys_q2, sys_q3;
  
  assign spi_rst_n= sys_rst_n & ~pi_csn;
  
  always_ff@(posedge pi_sck, negedge spi_rst_n)begin
    if(!spi_rst_n)pi_q<=0;
    else pi_q<=rx_done_pulse?~pi_q:pi_q;
  end

  always_ff@(posedge sys_clk, negedge sys_rst_n)begin
    if(!sys_rst_n)begin
      sys_q1<=0;
      sys_q2<=0;
      sys_q3<=0;
    end
    else begin
      sys_q1<=pi_q;
      sys_q2<=sys_q1;
      sys_q3<=sys_q2;
    end
  end
  
  assign write_en_pulse_sys= sys_q2 ^ sys_q3;
endmodule