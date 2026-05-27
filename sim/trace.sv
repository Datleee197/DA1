module tb;
    localparam DW = 16;
    logic clk, rst_n, valid_in, sync_in;
    logic [2:0] tb_cnt;
    logic phase_sel_i, phase_sel_ii;
    logic [1:0] rot_sel;
    
    // Instantiate raw block to trace its exact cycle behavior
    logic v_out, s_out;
    logic [DW-1:0] dout_re, dout_im;
    logic [15:0] din_re;
    
    r22sdf_block #(
        .DATA_W(DW), .DELAY_I(8), .DELAY_II(4), .HAS_CMUL(0)
    ) dut (
        .clk(clk), .rst_n(rst_n), .valid_in(valid_in), .sync_in(sync_in),
        .phase_sel_i(phase_sel_i), .phase_sel_ii(phase_sel_ii),
        .rot_sel(rot_sel), .tw_addr(8'd0),
        .din_re(din_re), .din_im(16'd0),
        .valid_out(v_out), .sync_out(s_out),
        .dout_re(dout_re), .dout_im(dout_im)
    );

    initial clk = 0; always #5 clk = ~clk;

    initial begin
        rst_n <= 0; valid_in <= 0; sync_in <= 0; tb_cnt <= 0; din_re <= 0;
        phase_sel_i <= 0; phase_sel_ii <= 0; rot_sel <= 0;
        repeat (3) @(posedge clk);
        rst_n <= 1;
        @(posedge clk); 
        
        for (int cycle = 0; cycle < 32; cycle++) begin
            valid_in <= 1;
            sync_in <= (cycle == 0);
            din_re <= cycle + 1;
            
            phase_sel_i <= 1'((cycle / 8) % 2);
            phase_sel_ii <= 1'((cycle / 4) % 2);
            rot_sel <= { 1'((cycle / 4) % 2), 1'((cycle / 8) % 2) };
            
            #1; // active region eval
            $display("cyc %2d: v_in=%b ph_i=%b ph_ii=%b | v_out=%b dout=%d", 
                cycle, valid_in, phase_sel_i, phase_sel_ii, v_out, dout_re);
            @(posedge clk);
        end
        $finish;
    end
endmodule
