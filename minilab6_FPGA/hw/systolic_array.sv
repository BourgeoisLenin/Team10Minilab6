module systolic_array
    #(
    parameter BITS_AB=8,
    parameter BITS_C=16,
    parameter DIM=8
    )
    (
    input clk,rst_n,WrEn,en,
    input signed [BITS_AB-1:0] A [DIM-1:0],
    input signed [BITS_AB-1:0] B [DIM-1:0],
    input signed [BITS_C-1:0]  Cin [DIM-1:0],
    input [$clog2(DIM)-1:0]    Crow,
    output signed [BITS_C-1:0] Cout [DIM-1:0]
    );

    // logic signed [BITS_AB-1:0] MACAdata[BITS_AB-1:0][BITS_AB-1:0],
    // MACBdata[BITS_AB-1:0][BITS_AB-1:0];
    logic signed [BITS_AB-1:0] MACAin[BITS_AB-1:0][BITS_AB-1:0],
    MACBin[BITS_AB-1:0][BITS_AB-1:0],
    MACAout[BITS_AB-1:0][BITS_AB-1:0],
    MACBout[BITS_AB-1:0][BITS_AB-1:0];
    logic signed [BITS_C-1:0] MACCin[BITS_AB-1:0][BITS_AB-1:0],
    MACCout[BITS_AB-1:0][BITS_AB-1:0];
    logic signed MACWrEn[BITS_AB-1:0][BITS_AB-1:0];
    // logic [$clog2(DIM)-1:0] count;

    tpumac iDUT[BITS_AB-1:0][BITS_AB-1:0] (
    .clk(clk), .rst_n(rst_n), .WrEn(MACWrEn), .en(en),
    .Ain(MACAin), .Bin(MACBin), .Cin(MACCin),
    .Aout(MACAout), .Bout(MACBout), .Cout(MACCout)
    );

    assign Cout = MACCout[Crow];

    always_comb begin : CrowManager
        for (int i = 0 ; i < DIM ; i++) begin
            for (int j = 0 ; j < DIM ; j++) begin
                if (Crow == i) MACWrEn[i][j] = WrEn;
                else MACWrEn[i][j] = 0;
                MACCin[i][j] = Cin[j];
            end
        end
    end

    always_comb begin : ABCManager
        for (int i = 0 ; i < DIM ; i++) begin
            MACAin[i][0] = A[i];
            MACBin[0][i] = B[i];
        end
        for (int i = 0 ; i < DIM ; i++) begin
            for (int j = 1 ; j < DIM ; j++) begin
                MACAin[i][j] = MACAout[i][j-1];
            end
        end
        for (int i = 1 ; i < DIM ; i++) begin
            for (int j = 0 ; j < DIM ; j++) begin
                MACBin[i][j] = MACBout[i-1][j]; 
            end
        end
    end
    // always_ff @(posedge clk, negedge rst_n) begin
    //         if (!rst_n) begin
    //             for (int i = 0 ; i < DIM ; i++) begin
    //                 for (int j = 0 ; j < DIM ; j++) begin
    //                     MACAdata[i][j] <= 0;
    //                     MACBdata[i][j] <= 0;
    //                 end
    //             end
    //             count <= 0;
    //         end else if (en) begin  
    //             for (int i = 0 ; i < DIM ; i++) begin
    //                 for (int j = 0 ; j < DIM ; j++) begin
    //                     if (i == count) MACAdata[i][j] <= A[j];
    //                     else if (j == DIM-1) MACAdata[i][j] <= 0;
    //                     else MACAdata[i][j] <= MACAdata[i][j+1];
                        
    //                     if (i == count) MACBdata[i][j] <= B[j];
    //                     else if (j == DIM-1) MACBdata[i][j] <= 0;
    //                     else MACBdata[i][j] <= MACBdata[i][j+1];
    //                 end
    //             end
    //             count++;
    //         end
    //     end

    // genvar i , j;
    // generate
    //     for (i = 0 ; i < DIM ; i++) begin
    //         for (j = 0 ; j < DIM ; j++) begin
    //             tpumac (
    //             .clk(clk), .rst_n(rst_n), .WrEn(MACWrEn), .en(en),
    //             .Ain(MACAin), .Bin(MACBin), .Cin(Cin[j]),
    //             .Aout(MACAout), .Bout(MACBout), .Cout(MACCout)
    //             );
    //         end
    //     end
    // endgenerate

endmodule