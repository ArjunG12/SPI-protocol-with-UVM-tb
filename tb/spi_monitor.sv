class spi_monitor extends uvm_monitor;
  `uvm_component_utils(spi_monitor)

  virtual spi_if vif;
  uvm_analysis_port #(spi_seq_item) ap;

  // Samples MOSI and MISO in the same CSN-low frame.

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap = new("ap", this);
    if (!uvm_config_db#(virtual spi_if)::get(this, "", "spi_vif", vif))
      `uvm_fatal("NO_VIF", "spi_if not found in config_db")
  endfunction

  task run_phase(uvm_phase phase);
    forever begin
      spi_seq_item  current_item;
      logic [47:0]  mosi_bits;
      logic [47:0]  miso_bits;
      bit           frame_error;

      // ------------------------------------------------------------------
      // 1. Wait for frame start
      // ------------------------------------------------------------------
      @(negedge vif.pi_csn);

      mosi_bits  = '0;
      miso_bits  = '0;
      frame_error = 0;

      // ------------------------------------------------------------------
      // 2. Sample 48 bits on posedge SCK (SPI Mode 3)
      //
      //    MOSI: master drives on negedge SCK, slave (and monitor) samples
      //          on posedge SCK — correct.
      //
      //    MISO: slave drives bit[47] immediately at CSN↓ via async reset
      //          in spi_tx_shift_reg, then shifts on negedge SCK.
      //          It is stable before every posedge SCK, so sampling here
      //          is correct — no change needed from the original.
      // ------------------------------------------------------------------
      for (int i = 47; i >= 0; i--) begin
        @(posedge vif.pi_sck);
        mosi_bits[i] = vif.pi_mosi;
        miso_bits[i] = vif.po_miso;
      end

      // ------------------------------------------------------------------
      // 3. Wait for CSN deassert; detect frame errors (Bug 2 + Bug 3 fix)
      //
      //    RTL sets frame_err when counter > 47 (a 49th SCK edge arrives
      //    before CSN goes high). Mirror that here.
      // ------------------------------------------------------------------
      fork
        begin : wait_csn_high
          @(posedge vif.pi_csn);
        end
        begin : detect_extra_sck
          @(posedge vif.pi_sck);      // 49th edge — matches RTL frame_err condition
          frame_error = 1;
          @(posedge vif.pi_csn);      // still let the frame close cleanly
        end
      join_any
      disable fork;

      // ------------------------------------------------------------------
      // 4. Build the current frame's MOSI item
      // ------------------------------------------------------------------
      current_item            = spi_seq_item::type_id::create("current_item");
      current_item.pi_mosi    = mosi_bits;
      current_item.frame_err  = frame_error;

      // Unpack MOSI fields — matches spi_frame_decoder bit positions:
      //   [47:42]=addr, [41:40]=cmd, [39:38]=hc, [37:6]=data, [5:0]=crc
      {current_item.address,
       current_item.cmd,
       current_item.hc,
       current_item.data,
       current_item.crc}      = mosi_bits;

      // ------------------------------------------------------------------
      // 5. Attach same-frame MISO and broadcast.
      //
      //    The data field corresponds to the current MOSI address; v/rc
      //    describe the DUT state at frame start.
      //
      //    MISO frame layout from spi_tx_formatter:
      //      {4'b0, ff[43], v[42], rc[41:38], reg_read_data[37:6], tx_crc[5:0]}
      // ------------------------------------------------------------------
      current_item.po_miso       = miso_bits;
      current_item.po_miso_oe    = vif.po_miso_oe;
      current_item.resp_crc      = miso_bits[5:0];
      current_item.resp_data     = miso_bits[37:6];
      current_item.resp_rc       = miso_bits[41:38];
      current_item.resp_v        = miso_bits[42];
      current_item.resp_ff       = miso_bits[43];

      ap.write(current_item);

    end
  endtask

endclass
