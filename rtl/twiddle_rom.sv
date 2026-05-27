// twiddle_rom.sv
// Combinational-read ROM for twiddle factors.
// Loads {tw_re[DATA_W-1:0], tw_im[DATA_W-1:0]} from a hex file.
// Each ROM word is 2*DATA_W bits wide.
// No clock required for read — purely combinational output.

module twiddle_rom #(
    parameter int  DATA_W   = 16,
    parameter int  ADDR_W   = 8,
    parameter      ROM_FILE = "tw256.hex"
)(
    input  logic [ADDR_W-1:0]        addr,
    output logic signed [DATA_W-1:0] tw_re,
    output logic signed [DATA_W-1:0] tw_im
);

    localparam int DEPTH = 2**ADDR_W;
    localparam int WORD_W = 2 * DATA_W;

    // ROM storage
    logic [WORD_W-1:0] rom [0:DEPTH-1];

    // Load hex file at elaboration time
    initial begin
        $readmemh(ROM_FILE, rom);
    end

    // Combinational read — upper half = tw_re, lower half = tw_im
    assign tw_re = rom[addr][WORD_W-1:DATA_W];
    assign tw_im = rom[addr][DATA_W-1:0];

endmodule
