# SPI UVM Verification Project

This project contains the initial RTL and UVM verification environment for an SPI slave design. The current work establishes a basic SystemVerilog RTL implementation, a UVM testbench, and a passing write/read smoke test.

## Project Structure

The project is intended to be organized module-wise as follows:

```text
SPI_project/
  rtl/
    spi_if.sv
    spi_slave_top.sv
    spi_cdc_sync.sv
    spi_crc_checker.sv
    spi_crc_generator.sv
    spi_frame_decoder.sv
    spi_reg_map.sv
    spi_rx_shift_reg.sv
    spi_slave_ctrl.sv
    spi_tx_formatter.sv
    spi_tx_shift_reg.sv

  tb/
    tb_top.sv
    spi_seq_item.sv
    spi_driver.sv
    spi_monitor.sv
    spi_scoreboard.sv
    spi_agent.sv
    spi_env.sv
    spi_base_seq.sv
    spi_write_read_seq.sv
    spi_base_test.sv
    spi_write_read_test.sv
```


## Current Status

Initial work has been completed:

- SPI slave RTL modules have been implemented.
- A UVM testbench has been created.
- A basic write/read sequence has been added.
- A scoreboard checks the observed MISO response.
- The current write/read smoke test passes in Cadence Xcelium.

The passing test writes `32'h12345678` to address `6'h0a`, then reads back from the same address.

## Simulation Command

The project was simulated using Cadence Xcelium with a command similar to:

```sh
xrun -Q -unbuffered -timescale 1ns/1ns -sysv -access +rw \
  -uvmnocdnsextra -uvmhome $UVM_HOME \
  $UVM_HOME/src/uvm_macros.svh design.sv testbench.sv
```

## Simulation Result

The following is the important output printed by the simulation:

```text
UVM_INFO @ 0: reporter [RNTST] Running test spi_write_read_test...
UVM_INFO testbench.sv(682) @ 12085000: uvm_test_top.env.agent.sequencer@@seq [WRITE_SEQ] WRITE addr=0x0a data=0x12345678  V=0 RC=0
UVM_INFO testbench.sv(686) @ 12085000: uvm_test_top.env.agent.sequencer@@seq [READ_SEQ] read addr=0x0a data=0x12345678  V=1 RC=1
UVM_INFO /xcelium25.03/tools/methodology/UVM/CDNS-1.2/sv/src/base/uvm_objection.svh(1271) @ 12085000: reporter [TEST_DONE] 'run' phase is ready to proceed to the 'extract' phase
UVM_INFO testbench.sv(547) @ 12085000: uvm_test_top.env.scoreboard [SCB_REPORT] Scoreboard PASS=14 FAIL=0

--- UVM Report Summary ---

** Report counts by severity
UVM_INFO :    6
UVM_WARNING :    0
UVM_ERROR :    0
UVM_FATAL :    0

** Report counts by id
[READ_SEQ]     1
[RNTST]        1
[SCB_REPORT]   1
[TEST_DONE]    1
[UVM/RELNOTES] 1
[WRITE_SEQ]    1

Simulation complete via $finish(1) at time 12085 NS + 63
```

The key result is:

```text
Scoreboard PASS=14 FAIL=0
UVM_ERROR : 0
UVM_FATAL : 0
```

This confirms that the current write/read smoke test is passing.

## Waveform

The simulation waveform was also checked. Add the waveform screenshot to the repository and update the image path below if needed.

<img width="2396" height="229" alt="image" src="https://github.com/user-attachments/assets/524c94a3-1a35-47f8-9da0-b49bc7b9583c" />

## Notes

Some simulator warnings may still appear:

- `NONPRT`: caused by non-ASCII characters in comments or strings, such as arrows or long dashes.
- `SAWSTP`: caused by use of `1step` timing in the driver.

These warnings did not stop the simulation and did not produce UVM errors or failures in the current smoke test.

## Future Work

Future verification work should include:

- Adding more directed sequences.
- Adding constrained-random sequences.
- Adding negative tests for CRC errors.
- Adding frame-length error tests.
- Adding reset-during-transfer tests.
- Adding tests for invalid addresses.
- Adding tests for status register and hardware fault behavior.
- Adding functional coverage.
- Adding regression scripts and a filelist.

The current project is a good starting point: the environment builds, the basic SPI write/read flow works, and the scoreboard reports a clean pass for the initial test.
