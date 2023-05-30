module ibex_register_file_ff (
	clk_i,
	rst_ni,
	test_en_i,
	dummy_instr_id_i,
	raddr_a_i,
	rdata_a_o,
	raddr_b_i,
	rdata_b_o,
	waddr_a_i,
	wdata_a_i,
	we_a_i,
	err_o
);
	parameter [0:0] RV32E = 0;
	parameter [31:0] DataWidth = 32;
	parameter [0:0] DummyInstructions = 0;
	parameter [0:0] WrenCheck = 0;
	parameter [DataWidth - 1:0] WordZeroVal = 1'sb0;
	input wire clk_i;
	input wire rst_ni;
	input wire test_en_i;
	input wire dummy_instr_id_i;
	input wire [4:0] raddr_a_i;
	output wire [DataWidth - 1:0] rdata_a_o;
	input wire [4:0] raddr_b_i;
	output wire [DataWidth - 1:0] rdata_b_o;
	input wire [4:0] waddr_a_i;
	input wire [DataWidth - 1:0] wdata_a_i;
	input wire we_a_i;
	output wire err_o;
	localparam [31:0] ADDR_WIDTH = (RV32E ? 4 : 5);
	localparam [31:0] NUM_WORDS = 2 ** ADDR_WIDTH;

    // Define the struct for register entries
    typedef struct packed {
        logic [DataWidth-1:0] reg_val;
        logic resultvalid;
        logic memvalid;
    } reg_entry_t;

    // Change the declaration of rf_reg to use the struct
    reg_entry_t [0:NUM_WORDS-1] rf_reg;

	reg [NUM_WORDS - 1:0] we_a_dec;

    function automatic [4:0] sv2v_cast_5;
		input reg [4:0] inp;
		sv2v_cast_5 = inp;
	endfunction

    always @(*) begin : we_a_decoder
		begin : sv2v_autoblock_1
			reg [31:0] i;
			for (i = 0; i < NUM_WORDS; i = i + 1)
				we_a_dec[i] = (waddr_a_i == sv2v_cast_5(i) ? we_a_i : 1'b0);
		end
	end

    generate
		if (WrenCheck) begin : gen_wren_check
			wire [NUM_WORDS - 1:0] we_a_dec_buf;
			prim_generic_buf #(.Width(NUM_WORDS)) u_prim_generic_buf(
				.in_i(we_a_dec),
				.out_o(we_a_dec_buf)
			);
			prim_onehot_check #(
				.AddrWidth(ADDR_WIDTH),
				.AddrCheck(1),
				.EnableCheck(1)
			) u_prim_onehot_check(
				.clk_i(clk_i),
				.rst_ni(rst_ni),
				.oh_i(we_a_dec_buf),
				.addr_i(waddr_a_i),
				.en_i(we_a_i),
				.err_o(err_o)
			);
		end
		else begin : gen_no_wren_check
			wire unused_strobe;
			assign unused_strobe = we_a_dec[0];
			assign err_o = 1'b0;
		end
	endgenerate

    genvar i;
    generate
		for (i = 1; i < NUM_WORDS; i = i + 1) begin : g_rf_flops
			reg_entry_t rf_reg_q;
			always @(posedge clk_i or negedge rst_ni) begin
				if (!rst_ni) begin
					rf_reg_q.reg_val <= WordZeroVal;
					rf_reg_q.resultvalid <= 0;
					rf_reg_q.memvalid <= 0;
				end else if (we_a_dec[i]) begin
					rf_reg_q.reg_val <= wdata_a_i;
					rf_reg_q.resultvalid <= 1; // set resultvalid when register is written to
					rf_reg_q.memvalid <= 1; // set memvalid when register is written to
				end
			end
			assign rf_reg[i] = rf_reg_q;
		end

        if (DummyInstructions) begin : g_dummy_r0
			wire we_r0_dummy;
			reg_entry_t rf_r0_q;
			assign we_r0_dummy = we_a_i & dummy_instr_id_i;
			always @(posedge clk_i or negedge rst_ni) begin
				if (!rst_ni) begin
					rf_r0_q.reg_val <= WordZeroVal;
					rf_r0_q.resultvalid <= 0;
					rf_r0_q.memvalid <= 0;
				end else if (we_r0_dummy) begin
					rf_r0_q.reg_val <= wdata_a_i;
					rf_r0_q.resultvalid <= 1; // set resultvalid when register is written to
					rf_r0_q.memvalid <= 1; // set memvalid when register is written to
				end
			end
			assign rf_reg[0] = (dummy_instr_id_i ? rf_r0_q : rf_r0_q);
		end
		else begin : g_normal_r0
			wire unused_dummy_instr_id;
			assign unused_dummy_instr_id = dummy_instr_id_i;
			assign rf_reg[0].reg_val = WordZeroVal;
			assign rf_reg[0].resultvalid = 0;
			assign rf_reg[0].memvalid = 0;
		end
	endgenerate

    assign rdata_a_o = rf_reg[raddr_a_i].reg_val;
    assign rdata_b_o = rf_reg[raddr_b_i].reg_val;
    wire unused_test_en;
	assign unused_test_en = test_en_i;
endmodule