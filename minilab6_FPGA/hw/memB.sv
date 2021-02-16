module memB
    #(
    parameter BITS_AB=8,
    parameter DIM=8
    )
    (
    input clk, rst_n, en,
    input signed [BITS_AB-1:0] Bin [DIM-1:0],
    output signed [BITS_AB-1:0] Bout [DIM-1:0]
    );
    logic signed [BITS_AB-1:0] MACBdata[DIM-1:0][DIM*2-2:0];
    logic [$clog2(DIM)+2:0] count;
    genvar i;

    generate        
    for (i = 0; i < DIM ; i++) begin
        assign Bout[i] = MACBdata[i][0];
    end
    endgenerate 

    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0 ; i < DIM ; i++) begin
                for (int j = 0 ; j < DIM*2-1 ; j++) begin
                    MACBdata[i][j] <= 0;
                end
            end
            count <= 0;
        end else if (en) begin
            if (count >= 8) begin
                automatic int temp = 0;
                for (int i = 0 ; i < DIM*2-1 ; i++) begin
                    if (MACBdata[7][i] != 0) temp++;
                end
                if (temp == 0) count <= 0;
            end
            for (int i = 0 ; i < DIM ; i++) begin
                for (int j = 0 ; j < DIM*2-1 ; j++) begin
                    if (count < DIM && j == 7 + i) begin
                        // MACBdata[i][j-1] <= MACBdata[i][j];
                        MACBdata[i][j] <= Bin[j-7];
                    end
                    else if (j == DIM*2-2) MACBdata[i][j] <= 0;
                    else MACBdata[i][j] <= MACBdata[i][j+1];
                end
            end
            count <= count + 1;
        end
    end

endmodule
