class spi_write_read_seq extends spi_base_seq;
  `uvm_object_utils(spi_write_read_seq)

  //knobs
  bit [5:0] addr=6'd1;
  bit [31:0] wdata=32'HDEAD_BEED;
  bit [31:0] rdata;
  function new(string name="spi_write_read_seq");
    super.new(name);
  endfunction

  task body();
    spi_seq_item req1,rsp1,req2,rsp2;

    req1= spi_seq_item::type_id::create("req1");

    start_item(req1);

    if(!req1.randomize() with {
      cmd==2'b00;
      address== local::addr;
      data== local::wdata;
      inject_crc_error==0;

    }) 
      `uvm_fatal("RAND_FAIL","write_read_seq rand() failed")

    finish_item(req1);
    get_response(rsp1);

    req2= spi_seq_item::type_id::create("req2");
    
    start_item(req2);

    if(!req2.randomize() with {
      cmd==2'b11;
      address== local::addr;
      data== local::wdata;
      inject_crc_error==0;

    }) 
      `uvm_fatal("RAND_FAIL","write_read_seq rand() failed")

    finish_item(req2);
    get_response(rsp2);

    `uvm_info("WRITE_SEQ",
            $sformatf("WRITE addr=0x%02h data=0x%08h → V=%0b RC=%0d",
                      addr, wdata, rsp1.resp_v, rsp1.resp_rc),
            UVM_MEDIUM)
    `uvm_info("READ_SEQ",
            $sformatf("read addr=0x%02h data=0x%08h → V=%0b RC=%0d",
                      req2.address, rsp2.resp_data, rsp2.resp_v, rsp2.resp_rc),
            UVM_MEDIUM)
  endtask
endclass
