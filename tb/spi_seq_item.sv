class spi_seq_item extends uvm_sequence_item;

    // --- MOSI fields (driven by master) ---
    rand bit [5:0]  address;
    rand bit [1:0]  cmd;
    rand bit [1:0]  hc;
    rand bit [31:0] data;
    bit      [5:0]      crc;       // non-rand: always computed in post_randomize
    rand bit [47:0] pi_mosi;

    // --- Raw MISO capture ---
    bit [47:0] po_miso;
    bit        po_miso_oe;

    // --- Decoded MISO response fields ---
    // Layout from spi_tx_formatter: {4'b0, ff[43], v[42], rc[41:38], data[37:6], crc[5:0]}
    // These are sampled from MISO during the same CSN-low frame.
    bit        frame_err;   // >48 SCK edges received (mirrors RTL frame_err_held)
    bit        resp_ff;     // po_miso[43]: fault flag
    bit        resp_v;      // po_miso[42]: was previous frame valid? (v_bit_prev)
    bit [3:0]  resp_rc;     // po_miso[41:38]: rolling counter
    bit [31:0] resp_data;   // po_miso[37:6]: register read data
    bit [5:0]  resp_crc;    // po_miso[5:0]: CRC over MISO upper 42 bits

    rand bit inject_crc_error;

    `uvm_object_utils_begin(spi_seq_item)
    `uvm_field_int(address,    UVM_ALL_ON)
    `uvm_field_int(cmd,        UVM_ALL_ON)
    `uvm_field_int(hc,         UVM_ALL_ON)
    `uvm_field_int(data,       UVM_ALL_ON)
    `uvm_field_int(crc,        UVM_ALL_ON)
    `uvm_field_int(pi_mosi,    UVM_ALL_ON)
    `uvm_field_int(po_miso,    UVM_ALL_ON)
    `uvm_field_int(po_miso_oe, UVM_ALL_ON)
    `uvm_field_int(frame_err,  UVM_ALL_ON)
    `uvm_field_int(resp_ff,    UVM_ALL_ON)
    `uvm_field_int(resp_v,     UVM_ALL_ON)
    `uvm_field_int(resp_rc,    UVM_ALL_ON)
    `uvm_field_int(resp_data,  UVM_ALL_ON)
    `uvm_field_int(resp_crc,   UVM_ALL_ON)
    `uvm_field_int(inject_crc_error, UVM_ALL_ON)
    `uvm_object_utils_end

    constraint crc_error_default {
        soft inject_crc_error == 0;
    }

    constraint c_mosi_packing {
        pi_mosi[47:6] == {address, cmd, hc, data};
    }

    constraint c_address_range {
        address < 32;
    }

    constraint cmd_limit {
        cmd inside {2'b00, 2'b11};
    }

    function new(string name = "spi_seq_item");
        super.new(name);
    endfunction

    function automatic logic [5:0] generate_spi_crc(input logic [47:0] frame);
        logic [5:0] crc_calc;
        crc_calc = 6'b111111;
        for (int i = 47; i >= 6; i--) begin
            if (crc_calc[5] ^ frame[i])
                crc_calc = {crc_calc[4:0], 1'b0} ^ 6'b100111;
            else
                crc_calc = {crc_calc[4:0], 1'b0};
        end
        return crc_calc;
    endfunction

    function void post_randomize();
        // Compute CRC over [47:6] only; [5:0] is a don't-care placeholder at this point

        this.crc          = inject_crc_error?(~generate_spi_crc({this.pi_mosi[47:6], 6'd0})):(generate_spi_crc({this.pi_mosi[47:6], 6'd0}));
        this.pi_mosi[5:0] = this.crc;
       
    endfunction

    function string convert2string();
        return $sformatf(
        "MOSI: addr=0x%02h cmd=%02b hc=%02b data=0x%08h crc=0x%02h crc_err_inj=%0b | MISO: ff=%0b v=%0b rc=%0d data=0x%08h crc=0x%02h frame_err=%0b",
        address, cmd, hc, data, crc, inject_crc_error,
        resp_ff, resp_v, resp_rc, resp_data, resp_crc, frame_err
        );
    endfunction

endclass
