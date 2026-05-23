interface spi_if(input logic sys_clk);
  	logic pi_sck;
    logic sys_rst_n;
    logic po_miso,pi_mosi, pi_csn, po_miso_oe;
    
    //system domain
    logic [31:0] hw_fault_in;
    
    clocking driver_cb @(negedge pi_sck);
        default input #1step output #1ns;
        output pi_mosi;
        output pi_csn;
        input  po_miso;
    endclocking
    
    clocking monitor_cb @(posedge pi_sck);
        default input #1step;
        input pi_mosi;
        input po_miso;
        input pi_csn;
    endclocking
    
    modport driver_mp  (clocking driver_cb,  output sys_rst_n, output hw_fault_in,
                        output pi_csn, output pi_mosi, input po_miso, input po_miso_oe);
    modport monitor_mp (clocking monitor_cb, input sys_rst_n,
                        input pi_csn, input pi_mosi, input po_miso, input po_miso_oe);

endinterface
