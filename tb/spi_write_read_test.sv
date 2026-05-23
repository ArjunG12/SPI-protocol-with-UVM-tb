class spi_write_read_test extends spi_base_test;
  `uvm_component_utils(spi_write_read_test)
  function new(string name = "spi_write_read_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction
  task run_phase(uvm_phase phase);
      spi_write_read_seq seq;
      phase.raise_objection(this);

      seq       = spi_write_read_seq::type_id::create("seq");
      seq.addr  = 6'd10;
      seq.wdata = 32'h12345678;
      seq.start(env.agent.sequencer);

      phase.drop_objection(this);
  endtask
endclass
