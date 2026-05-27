module tb;
    logic clk, rst_n, valid_in, valid_out;
    logic [4:0] v_sr;
    assign valid_out = v_sr[4];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) v_sr <= 0;
        else v_sr <= {v_sr[3:0], valid_in};
    end

    initial clk = 0; always #5 clk = ~clk;

    initial begin
        rst_n = 0; valid_in = 0;
        repeat (3) @(posedge clk);
        rst_n = 1;
        @(posedge clk); // t=35
        
        for (int cycle = 0; cycle < 6; cycle++) begin
            valid_in = 1;
            #1; // t=36, 46, ...
            $display("cyc %0d: valid_out=%b, v_sr=%b", cycle, valid_out, v_sr);
            @(posedge clk); // t=45, 55, ...
        end
        $finish;
    end
endmodule
