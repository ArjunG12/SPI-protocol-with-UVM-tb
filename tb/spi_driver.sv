class spi_driver extends uvm_driver #(spi_seq_item);
  `uvm_component_utils(spi_driver)
  
  // Fix 2: Match the type used in uvm_config_db::get
  virtual spi_if vif;
  
  localparam T_CSN_SETUP  = 100ns;
  localparam T_SCK_HALF   = 50ns;
  localparam T_CSN_HOLD   = 30ns;
  localparam T_IDLE       = 1000ns;
  
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual spi_if)::get(this, "", "spi_vif", vif))
      `uvm_fatal("NO_VIF", "spi_if not found in config_db")
  endfunction
      
  task run_phase(uvm_phase phase);
    // SPI Mode 3 Idle State setup
    wait (vif.sys_rst_n === 1'b1);
    vif.pi_csn  <= 1'b1;
    vif.pi_mosi <= 1'b0;
    vif.pi_sck  <= 1'b1; // Mode 3 idles HIGH

    forever begin
      spi_seq_item req, rsp;
      seq_item_port.get_next_item(req);

      rsp = spi_seq_item::type_id::create("rsp");
      rsp.set_id_info(req); // Better than copy(req) for keeping transaction IDs intact

      drive_frame(req, rsp);

      seq_item_port.item_done(rsp);
    end
  endtask
    
task drive_frame(spi_seq_item req, spi_seq_item rsp);
  logic [47:0] mosi_bits;
  logic [47:0] miso_bits;

  mosi_bits = req.pi_mosi;

  vif.pi_csn <= 1'b0;
  #T_CSN_SETUP;

  for (int i = 47; i >= 0; i--) begin
    vif.pi_sck  <= 1'b0;
    vif.pi_mosi <= mosi_bits[i];
    #T_SCK_HALF;

    vif.pi_sck <= 1'b1;
    #1step;                       // let NBA settle before sampling MISO
    miso_bits[i] = vif.po_miso;
    #(T_SCK_HALF - 1step);
  end

  #T_CSN_HOLD;
  vif.pi_csn <= 1'b1;

  // Echo driven MOSI fields back into response
  rsp.pi_mosi  = mosi_bits;
  rsp.address  = req.address;
  rsp.cmd      = req.cmd;
  rsp.hc       = req.hc;
  rsp.data     = req.data;
  rsp.crc      = req.crc;

  // Populate raw MISO capture
  rsp.po_miso    = miso_bits;
  rsp.po_miso_oe = vif.po_miso_oe; // read from interface, don't hardcode

  // Unpack MISO response fields per spi_tx_formatter layout
  rsp.resp_crc   = miso_bits[5:0];
  rsp.resp_data  = miso_bits[37:6];
  rsp.resp_rc    = miso_bits[41:38];
  rsp.resp_v     = miso_bits[42];
  rsp.resp_ff    = miso_bits[43];

  #T_IDLE;
endtask
  
endclass
