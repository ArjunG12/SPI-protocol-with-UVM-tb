class spi_env extends uvm_env;
  `uvm_component_utils(spi_env)

  spi_agent      agent;
  spi_scoreboard scoreboard;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    agent      = spi_agent::type_id::create("agent", this);
    scoreboard = spi_scoreboard::type_id::create("scoreboard", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);

    agent.ap.connect(scoreboard.item_collected_imp);
  endfunction

endclass
