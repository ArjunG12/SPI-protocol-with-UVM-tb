class spi_agent extends uvm_agent;
  `uvm_component_utils(spi_agent)

  spi_driver    driver;
  spi_monitor   monitor;
  spi_sequencer sequencer;

  uvm_analysis_port #(spi_seq_item) ap;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    ap      = new("ap", this);
    monitor = spi_monitor::type_id::create("monitor", this);

    if (is_active == UVM_ACTIVE) begin
      driver    = spi_driver::type_id::create("driver", this);
      sequencer = new("sequencer", this);
    end
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);

    monitor.ap.connect(ap);

    if (is_active == UVM_ACTIVE) begin
      driver.seq_item_port.connect(sequencer.seq_item_export);
    end
  endfunction

endclass
