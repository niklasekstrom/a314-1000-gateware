module a314(
    input PLL_CLKOUT0,

    // Amiga signals
    output INT2,
    input DRAM_WE_n,
    input DRAM_RAS_n,
    input [1:0] DRAM_CASL_n,
    input [1:0] DRAM_CASU_n,
    input [7:0] DRAM_A,
    input [15:0] DRAM_D_IN,
    output [15:0] DRAM_D_OUT,
    output [15:0] DRAM_D_OE,

    // Pi signals
    input PI_REQ,
    output PI_ACK,
    output PI_IRQ,
    input PI_WR,
    input [3:0] PI_A,
    input [15:0] PI_D_IN,
    output [15:0] PI_D_OUT,
    output [15:0] PI_D_OE,

    // SRAM signals
    output SRAM_LB_n,
    output SRAM_UB_n,
    output SRAM_OE_n,
    output SRAM_WE_n,
    output [16:0] SRAM_A,
    input [15:0] SRAM_D_IN,
    output [15:0] SRAM_D_OUT,
    output [15:0] SRAM_D_OE
);

wire clk = PLL_CLKOUT0;

// {BASE_ADDRESS, R2A_HEAD, A2R_TAIL, A2R_HEAD, R2A_TAIL}
reg [4:0] int_req;

// ######### DRAM interface logic

reg [7:0] ras_address;

always @(negedge DRAM_RAS_n)
    ras_address <= DRAM_A;

wire cas0_n = DRAM_CASL_n[0] && DRAM_CASU_n[0];
wire cas1_n = DRAM_CASL_n[1] && DRAM_CASU_n[1];
wire cas_n = cas0_n && cas1_n;

(* async_reg = "true" *) reg [2:0] cas_sync;

always @(posedge clk)
    cas_sync <= {cas_sync[1:0], !cas_n};

// Signals to the SRAM interface.
reg dram_access_request;
reg dram_access_complete;
reg [15:0] dram_data_read;
reg [16:0] dram_address;
reg dram_read;
wire [1:0] dram_dqm_n = {&DRAM_CASU_n, &DRAM_CASL_n};

reg dram_read_req;
reg dram_write_req_started;

always @(posedge clk) begin
    dram_write_req_started <= 1'b0;

    if (!cas_sync[1]) begin
        dram_read_req <= 1'b0;
        dram_access_request <= 1'b0;
    end else if (cas_sync[2:1] == 2'b01 && !DRAM_RAS_n) begin
        dram_address <= {cas0_n, DRAM_A, ras_address};
        dram_read <= DRAM_WE_n;
        if (DRAM_WE_n)
            dram_read_req <= 1'b1;
        else
            dram_write_req_started <= 1'b1;
        // Always issue an sram access, even when reading com area words.
        dram_access_request <= 1'b1;
    end
end

// Com area base address state machine.
reg [15:0] tentative_com_area_base_address;
reg [15:0] com_area_base_address = 16'hffff;

localparam [1:0] CABA_DET_IDLE = 2'd0;
localparam [1:0] CABA_DET_MATCHED_WORD1 = 2'd1;
localparam [1:0] CABA_DET_MATCHED_WORD2 = 2'd2;
localparam [1:0] CABA_DET_MATCHED_WORD3 = 2'd3;

reg [1:0] caba_det_state = CABA_DET_IDLE;

wire matches_tentative_caba = dram_address[16:1] == tentative_com_area_base_address;

always @(posedge clk) begin
    if (dram_write_req_started) begin
        case (caba_det_state)
            CABA_DET_IDLE: begin
                if (DRAM_D_IN == 16'h413a && !dram_address[0]) begin
                    tentative_com_area_base_address <= dram_address[16:1];
                    caba_det_state <= CABA_DET_MATCHED_WORD1;
                end else
                    caba_det_state <= CABA_DET_IDLE;
            end
            CABA_DET_MATCHED_WORD1: begin
                if (DRAM_D_IN == 16'hfeed && matches_tentative_caba)
                    caba_det_state <= CABA_DET_MATCHED_WORD2;
                else
                    caba_det_state <= CABA_DET_IDLE;
            end
            CABA_DET_MATCHED_WORD2: begin
                if (DRAM_D_IN == 16'hc0de && matches_tentative_caba)
                    caba_det_state <= CABA_DET_MATCHED_WORD3;
                else
                    caba_det_state <= CABA_DET_IDLE;
            end
            CABA_DET_MATCHED_WORD3: begin
                if (DRAM_D_IN == 16'ha314 && matches_tentative_caba)
                    com_area_base_address <= tentative_com_area_base_address;
                caba_det_state <= CABA_DET_IDLE;
            end
        endcase
    end
end

reg com_area_unlocked;

always @(posedge clk) begin
    if (dram_write_req_started && dram_address == {com_area_base_address, 1'b0})
        com_area_unlocked <= DRAM_D_IN == 16'ha314;
end

wire am_write_irq = dram_write_req_started && com_area_unlocked && dram_address == {com_area_base_address, 1'b1};
wire [4:0] am_set_bits = am_write_irq && DRAM_D_IN[15] ? DRAM_D_IN[4:0] : 5'd0;
wire [4:0] am_clr_bits = am_write_irq && !DRAM_D_IN[15] ? DRAM_D_IN[4:0] : 5'd0;

reg [4:0] am_int_ena;
assign INT2 = |(int_req & am_int_ena);

always @(posedge clk) begin
    if (am_write_irq) begin
        if (DRAM_D_IN[15])
            am_int_ena <= am_int_ena | DRAM_D_IN[12:8];
        else
            am_int_ena <= am_int_ena & ~DRAM_D_IN[12:8];
    end
end

reg [15:0] dram_data_out;
assign DRAM_D_OUT = dram_data_out;

always @(*) begin
    if (com_area_unlocked && dram_address == {com_area_base_address, 1'b0})
        dram_data_out <= 16'h413a;
    else if (com_area_unlocked && dram_address == {com_area_base_address, 1'b1})
        dram_data_out <= {3'd0, am_int_ena, 3'd0, int_req};
    else
        dram_data_out <= dram_data_read;
end

wire dram_drive_data = dram_read_req && !cas_n;
assign DRAM_D_OE = {16{dram_drive_data}};

// ######### Pi interface logic

localparam [3:0] PI_REG_SRAM_BYTE = 4'd0;
localparam [3:0] PI_REG_SRAM_WORD = 4'd1;
localparam [3:0] PI_REG_ADDR_LO = 4'd2;
localparam [3:0] PI_REG_ADDR_HI = 4'd3;
localparam [3:0] PI_REG_INT_REQ = 4'd4;
localparam [3:0] PI_REG_INT_ENA = 4'd5;
localparam [3:0] PI_REG_CA_BASE_ADDR = 4'd6;
localparam [3:0] PI_REG_RESERVED7 = 4'd7;

(* async_reg = "true" *) reg [2:0] pi_req_sync;

always @(posedge clk)
    pi_req_sync <= {pi_req_sync[1:0], PI_REQ};

wire pi_access_request = pi_req_sync[1] && (PI_A == PI_REG_SRAM_BYTE || PI_A == PI_REG_SRAM_WORD);
reg pi_access_complete;
reg [15:0] pi_data_read;

wire pi_write_req = pi_req_sync[2:1] == 2'b01 && PI_WR;
wire pi_read = !PI_WR;

reg pi_acknowledge;
assign PI_ACK = pi_acknowledge;

always @(posedge clk) begin
    if (!pi_access_request)
        pi_acknowledge <= 1'b0;
    else if (pi_access_complete)
        pi_acknowledge <= 1'b1;
end

// The pi address is 18 bits, i.e., can address 256k bytes individually.
reg [17:0] pi_address;

always @(posedge clk) begin
    if (pi_access_complete && !pi_acknowledge) begin
        if (PI_A[0]) // PI_REG_SRAM_WORD
            pi_address <= pi_address + 18'd2;
        else // PI_REG_SRAM_BYTE
            pi_address <= pi_address + 18'd1;
    end else if (pi_write_req) begin
        case (PI_A)
            PI_REG_ADDR_LO: pi_address[15:0] <= PI_D_IN;
            PI_REG_ADDR_HI: pi_address[17:16] <= PI_D_IN[1:0];
        endcase
    end
end

reg [1:0] pi_dqm_n;

always @(*) begin
    if (PI_A[0]) // Word.
        pi_dqm_n <= 2'b00;
    else if (pi_address[0]) // Odd byte.
        pi_dqm_n <= 2'b10;
    else // Even byte.
        pi_dqm_n <= 2'b01;
end

wire pi_write_irq = pi_write_req && PI_A == PI_REG_INT_REQ;
wire [4:0] pi_set_bits = pi_write_irq && PI_D_IN[15] ? PI_D_IN[4:0] : 5'd0;
wire [4:0] pi_clr_bits = pi_write_irq && !PI_D_IN[15] ? PI_D_IN[4:0] : 5'd0;

reg [4:0] pi_int_ena;
assign PI_IRQ = |(int_req & pi_int_ena);

always @(posedge clk) begin
    if (pi_write_req && PI_A == PI_REG_INT_ENA)
        pi_int_ena <= PI_D_IN[4:0];
end

reg [15:0] pi_data_out;
assign PI_D_OUT = pi_data_out;

always @(*) begin
    if (PI_A == PI_REG_INT_REQ)
        pi_data_out <= {11'd0, int_req};
    else if (PI_A == PI_REG_CA_BASE_ADDR)
        pi_data_out <= com_area_base_address;
    else
        pi_data_out <= pi_data_read;
end

wire pi_drive_data = PI_REQ && !PI_WR;
assign PI_D_OE = {16{pi_drive_data}};

// ######### Interrupt logic

wire [4:0] set_bits = am_set_bits | pi_set_bits;
wire [4:0] clr_bits = am_clr_bits | pi_clr_bits;

always @(posedge clk)
    int_req <= (int_req | set_bits) & ~clr_bits;

// ######### SRAM interface logic

localparam SRC_DRAM = 1'b0;
localparam SRC_PI = 1'b1;

reg sram_access_source = SRC_DRAM;

reg [16:0] sram_address;
assign SRAM_A = sram_address;

reg [15:0] sram_data_write;
assign SRAM_D_OUT = sram_data_write;

reg sram_drive_data = 1'b0;
assign SRAM_D_OE = {16{sram_drive_data}};

reg [1:0] sram_dqm_n;
assign SRAM_UB_n = sram_dqm_n[1];
assign SRAM_LB_n = sram_dqm_n[0];

reg sram_we = 1'b0;
reg sram_oe = 1'b0;
assign SRAM_WE_n = !sram_we;
assign SRAM_OE_n = !sram_oe;

// SRAM state machine.

localparam [1:0] SRAM_IDLE = 2'd0;
localparam [1:0] SRAM_DELAY1 = 2'd1;
localparam [1:0] SRAM_DELAY2 = 2'd2;
localparam [1:0] SRAM_TERMINATE = 2'd3;

reg [1:0] sram_state = SRAM_IDLE;

always @(posedge clk) begin
    case (sram_state)
        SRAM_IDLE: begin
            sram_drive_data <= 1'b0;

            if (dram_access_request && !dram_access_complete) begin
                sram_access_source <= SRC_DRAM;
                sram_address <= dram_address;
                sram_data_write <= DRAM_D_IN;
                sram_dqm_n <= dram_dqm_n;

                if (dram_read) begin // Read.
                    sram_oe <= 1'b1;
                end else begin // Write.
                    sram_drive_data <= 1'b1;
                    sram_we <= 1'b1;
                end

                sram_state <= SRAM_DELAY1;
            end else if (pi_access_request && !pi_access_complete) begin
                sram_access_source <= SRC_PI;
                sram_address <= pi_address[17:1];
                sram_data_write <= PI_D_IN;
                sram_dqm_n <= pi_dqm_n;

                if (pi_read) // Read.
                    sram_oe <= 1'b1;
                else begin // Write.
                    sram_drive_data <= 1'b1;
                    sram_we <= 1'b1;
                end

                sram_state <= SRAM_DELAY1;
            end
        end
        SRAM_DELAY1: begin
            sram_state <= SRAM_DELAY2;
        end
        SRAM_DELAY2: begin
            sram_state <= SRAM_TERMINATE;
        end
        SRAM_TERMINATE: begin
            if (sram_access_source == SRC_DRAM) begin
                dram_data_read <= SRAM_D_IN;
                dram_access_complete <= 1'b1;
            end else begin // SRC_PI
                pi_data_read <= SRAM_D_IN;
                pi_access_complete <= 1'b1;
            end

            sram_oe <= 1'b0;
            sram_we <= 1'b0;
            // sram_drive_data is cleared in the idle state.

            sram_state <= SRAM_IDLE;
        end
    endcase

    if (!dram_access_request)
        dram_access_complete <= 1'b0;

    if (!pi_access_request)
        pi_access_complete <= 1'b0;
end

endmodule
