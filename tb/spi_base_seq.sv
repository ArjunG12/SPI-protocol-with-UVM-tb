class spi_base_seq extends uvm_sequence #(spi_seq_item);
  `uvm_object_utils(spi_base_seq)

  function new(string name="spi_base_seq");
    super.new(name);
  endfunction

  task send_frame(spi_seq_item req, output spi_seq_item rsp);
    start_item(req);
    if(!req.randomize())
      `uvm_fatal("RAND_FAIL","spi_seq_item rand() failed")
      finish_item(req);
      get_response(rsp);
  endtask
endclass

