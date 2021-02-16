module tpuv1
    #(
    parameter BITS_AB=8,
    parameter BITS_C=16,
    parameter DIM=8,
    parameter ADDRW=16,
    parameter DATAW=64
    )
    (
    input clk, rst_n, r_w, // r_w=0 read, =1 write
    input [DATAW-1:0] dataIn,
    output logic [DATAW-1:0] dataOut,
    input [ADDRW-1:0] addr
    );
    logic WrEn, WrEnA, enA, enB, en, cntrst; // en for sysarray
    logic [$clog2(DIM)+1:0] cnt;
    logic signed [BITS_AB-1:0] Ain [DIM-1:0], Aout [DIM-1:0],
    Bin [DIM-1:0], Bout [DIM-1:0],
    A [DIM-1:0], B [DIM-1:0];
    logic [$clog2(DIM)-1:0] Arow, Crow;
    logic signed [BITS_C-1:0] Cin [DIM-1:0], Cout [DIM-1:0];
    
    systolic_array #(.BITS_AB(BITS_AB), .BITS_C(BITS_C), .DIM(DIM))
    SysArrayDUT (.*);
    
    memA #(.BITS_AB(BITS_AB), .DIM(DIM))
    memADUT
    (
    .clk(clk), .rst_n(rst_n), .WrEn(WrEnA), .en(enA),
    .Ain(Ain), .Arow(Arow), .Aout(Aout)
    );

    memB #(.BITS_AB(BITS_AB), .DIM(DIM))
    memBDUT
    (
    .clk(clk), .rst_n(rst_n), .en(enB),
    .Bin(Bin), .Bout(Bout)
    );
    genvar i;

    generate
    for (i = 0 ; i < DIM ; i++) begin
        assign Ain[i] = dataIn[8*(i+1)-1:8*i];
        assign Bin[i] = dataIn[8*(i+1)-1:8*i];
        assign A[i] = Aout[i];
        assign B[i] = Bout[i];
    end
    endgenerate
    
    always_ff @(posedge clk, negedge rst_n) begin : counter
        if (!rst_n || cntrst) begin
            cnt <= 0;
        end else begin
            cnt <= cnt + 1;
        end
    end

    always_comb begin
        WrEn = 0;
        WrEnA = 0;
        enA = 0;
        enB = 0;
        dataOut = 0;
        Arow = 0;
        Crow = 0;
        if (cnt == 0 || cnt > DIM*3+1) cntrst = 1;
        else cntrst = 0;
        if (cnt > 0 && cnt < DIM*3+1) begin 
            en = 1;
            if (cnt <= 16) begin
                enA = 1;
                enB = 1;
            end
        end else en = 0;
        // for (int i = 0 ; i < 8 ; i++) begin
        //     Ain[i] = 0;
        //     Bin[i] = 0;
        // end
        for (int i = 0 ; i < DIM ; i++) begin
            for (int j = 0 ; j < BITS_C ; j++) begin
                Cin[i][j] = 0;
            end
        end

        casex ({r_w,addr})
            17'hx01xx : begin : writeA
                WrEnA = 1;
                Arow = addr[7:0]/8;
            end
            17'hx02xx : begin : writeB
                enB = 1;
            end
            17'h003xx : begin : readC
                Crow = addr[7:0]/16;
                if ((addr[7:0]/8) % 2 == 0) begin // upper half
                    for (int i = 0 ; i < DATAW ; i++) begin
                        automatic int temp = i/16;
                        dataOut[i] = Cout[temp][i%16];
                    end
                end else begin
                    for (int i = 0 ; i < DATAW ; i++) begin
                        automatic int temp = i/16;
                        dataOut[i] = Cout[temp+4][i%16];
                    end
                end
            end
            17'h103xx : begin : writeC
                WrEn = 1;
                Crow = addr[7:0]/16;
                for (int i = 0 ; i < DATAW ; i++) begin
                    if ((addr[7:0]/8) % 2 == 0) begin
                        automatic int temp = i/16;
                        Cin[temp][i%16] = dataIn[i];
                        Cin[temp+4][i%16] = 0;
                    end else if ((addr[7:0]/8) % 2 == 1) begin
                        automatic int temp = i/16;
                        Cin[temp+4][i%16] = dataIn[i];
                        Cin[temp][i%16] = 0;
                    end
                end
            end
            17'hx0400 : begin : MatMul
                cntrst = 0;
            end
            default: begin
                // dataOut[0] = 1;
            end
        endcase
    end


endmodule
