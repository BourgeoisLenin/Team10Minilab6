module memA
    #(
    parameter BITS_AB=8,
    parameter DIM=8
    )
    (
    input clk, rst_n, en, WrEn,
    input signed [BITS_AB-1:0] Ain [DIM-1:0],
    input [$clog2(DIM)-1:0] Arow,
    output signed [BITS_AB-1:0] Aout [DIM-1:0]
    );

    logic signed [BITS_AB-1:0] MACAdata [DIM-1:0][DIM*2-2:0];
    genvar i;

    generate        
    for (i = 0; i < DIM ; i++) begin
        assign Aout[i] = MACAdata[i][0];
    end
    endgenerate 

    always_ff @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0 ; i < DIM ; i++) begin
                for (int j = 0 ; j < DIM*2-1 ; j++) begin
                    MACAdata[i][j] <= 0;
                    // MACBdata[i][j] <= 0;
                end
            end
        end else if (en) begin  
            for (int i = 0 ; i < DIM ; i++) begin
                for (int j = 0 ; j < DIM*2-1 ; j++) begin
                    if (j == DIM*2-2) MACAdata[i][j] <= 0;
                    else MACAdata[i][j] <= MACAdata[i][j+1];
                end
            end
        end else if (WrEn) begin  
            for (int i = 0 ; i < DIM ; i++) begin
                for (int j = 0 ; j < DIM*2-1 ; j++) begin
                    if (i == Arow && j >= 7) MACAdata[i][j] <= Ain[j-7];
                    else if (i == Arow || j == DIM*2-2) MACAdata[i][j] <= 0;
                    else MACAdata[i][j] <= MACAdata[i][j+1];
                end
            end
        end
    end

    

    
   endmodule