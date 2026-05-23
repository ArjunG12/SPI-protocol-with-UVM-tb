class spi_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(spi_scoreboard)

  uvm_analysis_imp #(spi_seq_item, spi_scoreboard) item_collected_imp;

  localparam bit [1:0] CMD_WRITE = 2'b00;
  localparam bit [1:0] CMD_READ  = 2'b11;

  bit [31:0] ref_regs [1:31];
  bit [31:0] status_reg;
  bit        exp_v;
  bit [3:0]  exp_rc;

  int pass_count;
  int fail_count;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    item_collected_imp = new("item_collected_imp", this);

    foreach (ref_regs[i])
      ref_regs[i] = 32'h0;

    status_reg = 32'h0;
    exp_v      = 1'b0;
    exp_rc     = 4'd0;
  endfunction

  virtual function void write(spi_seq_item item);
    logic [5:0]  mosi_crc_calc;
    logic [5:0]  miso_crc_calc;
    logic        frame_valid;
    logic [3:0]  expected_resp_rc;
    logic        expected_resp_v;
    logic        expected_resp_ff;
    logic [31:0] expected_resp_data;

    `uvm_info("SCB_RCV", $sformatf("Captured Frame Observed:\n%s", item.sprint()), UVM_HIGH)

    // 1. Independently calculate whether MOSI frame was valid.
    mosi_crc_calc = item.generate_spi_crc(item.pi_mosi);
    frame_valid   = (mosi_crc_calc == item.crc) && !item.frame_err;

    if (mosi_crc_calc !== item.crc) begin
      `uvm_info("MOSI_CRC_INVALID",
        $sformatf("Observed invalid MOSI CRC: got=0x%0h expected=0x%0h",
                  item.crc, mosi_crc_calc), UVM_MEDIUM)
    end
    else begin
      pass_count++;
    end

    // 2. Predict same-frame response fields before applying this frame's write.
    expected_resp_v  = exp_v;
    expected_resp_rc = exp_rc;
    expected_resp_ff = |status_reg;

    if (item.address == 6'd0)
      expected_resp_data = status_reg;
    else if (item.address < 6'd32)
      expected_resp_data = ref_regs[item.address];
    else
      expected_resp_data = 32'hFEDC_BA98;

    // 4. Check fixed MISO header.
    if (item.po_miso[47:44] !== 4'b0000) begin
      `uvm_error("MISO_HDR_ERR",
        $sformatf("MISO[47:44] expected 0000, got %04b", item.po_miso[47:44]))
      fail_count++;
    end
    else begin
      pass_count++;
    end

    // 5. Check MISO CRC.
    miso_crc_calc = item.generate_spi_crc(item.po_miso);

    if (miso_crc_calc !== item.resp_crc) begin
      `uvm_error("MISO_CRC_ERR",
        $sformatf("MISO CRC mismatch: got=0x%0h expected=0x%0h",
                  item.resp_crc, miso_crc_calc))
      fail_count++;
    end
    else begin
      pass_count++;
    end

    // 6. Check V bit.
    if (item.resp_v !== expected_resp_v) begin
      `uvm_error("V_BIT_ERR",
        $sformatf("V mismatch: got=%0b expected=%0b frame_valid=%0b",
                  item.resp_v, expected_resp_v, frame_valid))
      fail_count++;
    end
    else begin
      pass_count++;
    end

    // 7. Check rolling counter.
    if (item.resp_rc !== expected_resp_rc) begin
      `uvm_error("RC_ERR",
        $sformatf("RC mismatch: got=%0d expected=%0d frame_valid=%0b",
                  item.resp_rc, expected_resp_rc, frame_valid))
      fail_count++;
    end
    else begin
      pass_count++;
    end

    // 8. Check fault flag.
    if (item.resp_ff !== expected_resp_ff) begin
      `uvm_error("FF_ERR",
        $sformatf("FF mismatch: got=%0b expected=%0b",
                  item.resp_ff, expected_resp_ff))
      fail_count++;
    end
    else begin
      pass_count++;
    end

    // 9. Check response data.
    if (item.resp_data !== expected_resp_data) begin
      `uvm_error("DATA_ERR",
        $sformatf("Data mismatch addr=0x%0h cmd=%0b got=0x%08h expected=0x%08h",
                  item.address, item.cmd, item.resp_data, expected_resp_data))
      fail_count++;
    end
    else begin
      pass_count++;
    end

    if (!frame_valid) begin
      `uvm_info("SCB_INVALID_FRAME",
        $sformatf("Invalid frame correctly modeled: crc_ok=%0b frame_err=%0b",
                  (mosi_crc_calc == item.crc), item.frame_err), UVM_MEDIUM)
    end

    // 10. Commit this frame into the reference model for the next response.
    if (frame_valid && item.cmd == CMD_WRITE) begin
      if (item.address == 6'd0) begin
        // Address 0 is status register, W1C behavior.
        // This assumes hw_fault_in is 0 in current tests.
        status_reg = status_reg & ~item.data;
      end
      else if (item.address < 6'd32) begin
        ref_regs[item.address] = item.data;
      end
    end

    exp_v = frame_valid;
    if (frame_valid)
      exp_rc = exp_rc + 4'd1;
  endfunction

  function void report_phase(uvm_phase phase);
    `uvm_info("SCB_REPORT",
      $sformatf("Scoreboard PASS=%0d FAIL=%0d", pass_count, fail_count),
      UVM_NONE)

    if (fail_count != 0)
      `uvm_error("SCB_REPORT", "SPI scoreboard detected failures")
  endfunction

endclass
