////////////////////////////////////////////////////////////////////////////////
//
// Filename:	pipemem.v
//
// Project:	Zip CPU -- a small, lightweight, RISC CPU soft core
//
// Purpose:	A memory unit to support a CPU, this time one supporting
//		pipelined wishbone memory accesses.  The goal is to be able
//	to issue one pipelined wishbone access per clock, and (given the memory
//	is fast enough) to be able to read the results back at one access per
//	clock.  This renders on-chip memory fast enough to handle single cycle
//	(pipelined) access.
//
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
//
// Copyright (C) 2015-2018, Gisselquist Technology, LLC
//
// This program is free software (firmware): you can redistribute it and/or
// modify it under the terms of  the GNU General Public License as published
// by the Free Software Foundation, either version 3 of the License, or (at
// your option) any later version.
//
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTIBILITY or
// FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
// for more details.
//
// You should have received a copy of the GNU General Public License along
// with this program.  (It's in the $(ROOT)/doc directory, run make with no
// target there if the PDF file isn't present.)  If not, see
// <http://www.gnu.org/licenses/> for a copy.
//
// License:	GPL, v3, as defined and found on www.gnu.org,
//		http://www.gnu.org/licenses/gpl.html
//
//
////////////////////////////////////////////////////////////////////////////////
//
//
`default_nettype	none
//
module	pipemem(i_clk, i_reset, i_pipe_stb, i_lock,
		i_op, i_addr, i_data, i_oreg,
			o_busy, o_pipe_stalled, o_valid, o_err, o_wreg, o_result,
		o_wb_cyc_gbl, o_wb_cyc_lcl,
			o_wb_stb_gbl, o_wb_stb_lcl,
			o_wb_we, o_wb_addr, o_wb_data, o_wb_sel,
		i_wb_ack, i_wb_stall, i_wb_err, i_wb_data
`ifdef	FORMAL
		, f_nreqs, f_nacks, f_outstanding, f_pc
`endif
		);
	parameter	ADDRESS_WIDTH=30;
	parameter [0:0]	IMPLEMENT_LOCK=1'b1,
			WITH_LOCAL_BUS=1'b1,
			OPT_ZERO_ON_IDLE=1'b0,
			// OPT_ALIGNMENT_ERR
			OPT_ALIGNMENT_ERR=1'b0;
	parameter [0:0]	F_OPT_CLK2FFLOGIC=1'b0;
	localparam	AW=ADDRESS_WIDTH,
			FLN=4;
	parameter [(FLN-1):0]	OPT_MAXDEPTH=4'hd;
	input	wire		i_clk, i_reset;
	input	wire		i_pipe_stb, i_lock;
	// CPU interface
	input	wire	[2:0]	i_op;
	input	wire	[31:0]	i_addr;
	input	wire	[31:0]	i_data;
	input	wire	[4:0]	i_oreg;
	// CPU outputs
	output	wire		o_busy;
	output	wire		o_pipe_stalled;
	output	reg		o_valid;
	output	reg		o_err;
	output	reg	[4:0]	o_wreg;
	output	reg	[31:0]	o_result;
	// Wishbone outputs
	output	wire		o_wb_cyc_gbl;
	output	reg		o_wb_stb_gbl;
	output	wire		o_wb_cyc_lcl;
	output	reg		o_wb_stb_lcl, o_wb_we;
	output	reg	[(AW-1):0]	o_wb_addr;
	output	reg	[31:0]	o_wb_data;
	output	reg	[3:0]	o_wb_sel;
	// Wishbone inputs
	input	wire		i_wb_ack, i_wb_stall, i_wb_err;
	input	wire	[31:0]	i_wb_data;
// Formal
	parameter	F_LGDEPTH=5;
`ifdef	FORMAL
	output	wire	[(F_LGDEPTH-1):0]	f_nreqs, f_nacks, f_outstanding;
	output	reg	f_pc;
`endif


	reg			cyc;
	reg			r_wb_cyc_gbl, r_wb_cyc_lcl, fifo_full;
	reg	[(FLN-1):0]		rdaddr, wraddr;
	wire	[(FLN-1):0]		nxt_rdaddr, fifo_fill;
	reg	[(4+5-1):0]	fifo_oreg [0:15];
	initial	rdaddr = 0;
	initial	wraddr = 0;

	reg	misaligned;

	always	@(*)
	if (OPT_ALIGNMENT_ERR)
	begin
		casez({ i_op[2:1], i_addr[1:0] })
		4'b01?1: misaligned = 1'b1;
		4'b0110: misaligned = 1'b1;
		4'b10?1: misaligned = 1'b1;
		default: misaligned = 1'b0;
		endcase
	end else
		misaligned = 1'b0;

	always @(posedge i_clk)
		fifo_oreg[wraddr] <= { i_oreg, i_op[2:1], i_addr[1:0] };

	initial	wraddr = 0;
	always @(posedge i_clk)
	if (i_reset)
		wraddr <= 0;
	else if (((i_wb_err)&&(cyc))||((i_pipe_stb)&&(misaligned)))
			wraddr <= 0;
	else if (i_pipe_stb)
		wraddr <= wraddr + 1'b1;

	initial	rdaddr = 0;
	always @(posedge i_clk)
	if (i_reset)
		rdaddr <= 0;
	else if (((i_wb_err)&&(cyc))||((i_pipe_stb)&&(misaligned)))
		rdaddr <= 0;
	else if ((i_wb_ack)&&(cyc))
		rdaddr <= rdaddr + 1'b1;

	assign	fifo_fill = wraddr - rdaddr;

	initial	fifo_full = 0;
	always @(posedge i_clk)
	if (i_reset)
		fifo_full <= 0;
	else if (((i_wb_err)&&(cyc))||((i_pipe_stb)&&(misaligned)))
		fifo_full <= 0;
	else if (i_pipe_stb)
		fifo_full <= (fifo_fill >= OPT_MAXDEPTH-1);
	else
		fifo_full <= (fifo_fill >= OPT_MAXDEPTH);

	assign	nxt_rdaddr = rdaddr + 1'b1;

	wire	gbl_stb, lcl_stb, lcl_bus;
	assign	lcl_bus = (i_addr[31:24]==8'hff)&&(WITH_LOCAL_BUS);
	assign	lcl_stb = (lcl_bus)&&(!misaligned);
	assign	gbl_stb = ((!lcl_bus)||(!WITH_LOCAL_BUS))&&(!misaligned);
			//= ((i_addr[31:8]!=24'hc00000)||(i_addr[7:5]!=3'h0));

	initial	cyc = 0;
	initial	r_wb_cyc_lcl = 0;
	initial	r_wb_cyc_gbl = 0;
	initial	o_wb_stb_lcl = 0;
	initial	o_wb_stb_gbl = 0;
	always @(posedge i_clk)
		if (i_reset)
		begin
			r_wb_cyc_gbl <= 1'b0;
			r_wb_cyc_lcl <= 1'b0;
			o_wb_stb_gbl <= 1'b0;
			o_wb_stb_lcl <= 1'b0;
			cyc <= 1'b0;
		end else if (cyc)
		begin
			if (((!i_wb_stall)&&(!i_pipe_stb)&&(!misaligned))
				||(i_wb_err))
			begin
				o_wb_stb_gbl <= 1'b0;
				o_wb_stb_lcl <= 1'b0;
			end

			if (((i_wb_ack)&&(nxt_rdaddr == wraddr)
					&&((!i_pipe_stb)||(misaligned)))
				||(i_wb_err))
			begin
				r_wb_cyc_gbl <= 1'b0;
				r_wb_cyc_lcl <= 1'b0;
				o_wb_stb_gbl <= 1'b0;
				o_wb_stb_lcl <= 1'b0;
				cyc <= 1'b0;
			end
		end else if (i_pipe_stb) // New memory operation
		begin // Grab the wishbone
			r_wb_cyc_lcl <= lcl_stb;
			r_wb_cyc_gbl <= gbl_stb;
			o_wb_stb_lcl <= lcl_stb;
			o_wb_stb_gbl <= gbl_stb;
			cyc <= (!misaligned);
		end

	always @(posedge i_clk)
		if ((!cyc)||(!i_wb_stall))
		begin
			if ((OPT_ZERO_ON_IDLE)&&(!i_pipe_stb))
				o_wb_addr <= 0;
			else
				o_wb_addr <= i_addr[(AW+1):2];

			if ((OPT_ZERO_ON_IDLE)&&(!i_pipe_stb))
				o_wb_sel <= 4'b0000;
			else casez({ i_op[2:1], i_addr[1:0] })
				4'b100?: o_wb_sel <= 4'b1100;	// Op = 5
				4'b101?: o_wb_sel <= 4'b0011;	// Op = 5
				4'b1100: o_wb_sel <= 4'b1000;	// Op = 5
				4'b1101: o_wb_sel <= 4'b0100;	// Op = 7
				4'b1110: o_wb_sel <= 4'b0010;	// Op = 7
				4'b1111: o_wb_sel <= 4'b0001;	// Op = 7
				default: o_wb_sel <= 4'b1111;	// Op = 7
			endcase

			if ((OPT_ZERO_ON_IDLE)&&(!i_pipe_stb))
				o_wb_data <= 0;
			else casez({ i_op[2:1], i_addr[1:0] })
			4'b100?: o_wb_data <= { i_data[15:0], 16'h00 };
			4'b101?: o_wb_data <= { 16'h00, i_data[15:0] };
			4'b1100: o_wb_data <= {         i_data[7:0], 24'h00 };
			4'b1101: o_wb_data <= {  8'h00, i_data[7:0], 16'h00 };
			4'b1110: o_wb_data <= { 16'h00, i_data[7:0],  8'h00 };
			4'b1111: o_wb_data <= { 24'h00, i_data[7:0] };
			default: o_wb_data <= i_data;
			endcase
		end

	always @(posedge i_clk)
		if ((i_pipe_stb)&&(!cyc))
			o_wb_we   <= i_op[0];
		else if ((OPT_ZERO_ON_IDLE)&&(!cyc))
			o_wb_we   <= 1'b0;

	initial	o_valid = 1'b0;
	always @(posedge i_clk)
	if (i_reset)
		o_valid <= 1'b0;
	else
		o_valid <= (cyc)&&(i_wb_ack)&&(!o_wb_we);

	initial	o_err = 1'b0;
	always @(posedge i_clk)
	if (i_reset)
		o_err <= 1'b0;
	else
		o_err <= ((cyc)&&(i_wb_err))||((i_pipe_stb)&&(misaligned));
	assign	o_busy = cyc;

	wire	[8:0]	w_wreg;
	assign	w_wreg = fifo_oreg[rdaddr];
	always @(posedge i_clk)
		o_wreg <= w_wreg[8:4];
	always @(posedge i_clk)
		if ((OPT_ZERO_ON_IDLE)&&((!cyc)||((!i_wb_ack)&&(!i_wb_err))))
			o_result <= 0;
		else begin
			casez(w_wreg[3:0])
			4'b1100: o_result <= { 24'h00, i_wb_data[31:24] };
			4'b1101: o_result <= { 24'h00, i_wb_data[23:16] };
			4'b1110: o_result <= { 24'h00, i_wb_data[15: 8] };
			4'b1111: o_result <= { 24'h00, i_wb_data[ 7: 0] };
			4'b100?: o_result <= { 16'h00, i_wb_data[31:16] };
			4'b101?: o_result <= { 16'h00, i_wb_data[15: 0] };
			default: o_result <= i_wb_data[31:0];
			endcase
		end

	assign	o_pipe_stalled = ((cyc)&&(fifo_full))||((cyc)
			&&((i_wb_stall)||((!o_wb_stb_lcl)&&(!o_wb_stb_gbl))));

	generate
	if (IMPLEMENT_LOCK != 0)
	begin
		reg	lock_gbl, lock_lcl;

		initial	lock_gbl = 1'b0;
		initial	lock_lcl = 1'b0;
		always @(posedge i_clk)
		if ((i_reset)||((i_wb_err)&&(cyc))
			||((i_pipe_stb)&&(misaligned)))
		begin
			lock_gbl <= 1'b0;
			lock_lcl <= 1'b0;
		end else begin
			lock_gbl <= (i_lock)&&((r_wb_cyc_gbl)||(lock_gbl));
			lock_lcl <= (i_lock)&&((r_wb_cyc_lcl)||(lock_lcl));
		end

		assign	o_wb_cyc_gbl = (r_wb_cyc_gbl)||(lock_gbl);
		assign	o_wb_cyc_lcl = (r_wb_cyc_lcl)||(lock_lcl);
	end else begin
		assign	o_wb_cyc_gbl = (r_wb_cyc_gbl);
		assign	o_wb_cyc_lcl = (r_wb_cyc_lcl);
	end endgenerate

	// Make verilator happy
	// verilator lint_off UNUSED
	wire	unused;
	assign	unused = i_lock;
	// verilator lint_on  UNUSED

`ifdef	FORMAL
`ifdef	PIPEMEM
`define	ASSUME	assume
`define	ASSERT	assert
	generate if (F_OPT_CLK2FFLOGIC)
	begin
		reg	f_last_clk;

		initial	f_last_clk = 0;
		always @($global_clock)
		begin
			assume(i_clk != f_last_clk);
			f_last_clk <= i_clk;
		end
	end endgenerate
`else
`define	ASSUME	assert
`define	ASSERT	assume
`endif

	reg	f_past_valid;
	initial	f_past_valid = 0;
	always @(posedge i_clk)
		f_past_valid = 1'b1;
	always @(*)
		if (!f_past_valid)
			`ASSUME(i_reset);

	initial	`ASSUME( i_reset);
	initial	`ASSUME(!i_pipe_stb);

	generate if (F_OPT_CLK2FFLOGIC)
	begin
		always @($global_clock)
		if (!$rose(i_clk))
		begin
			`ASSUME($stable(i_reset));
			`ASSUME($stable(i_pipe_stb));
			`ASSUME($stable(i_addr));
			`ASSUME($stable(i_lock));
			`ASSUME($stable(i_op));
		end
	end endgenerate

	wire	f_cyc, f_stb;
	assign	f_cyc = cyc;
	assign	f_stb = (o_wb_stb_gbl)||(o_wb_stb_lcl);

`ifdef	PIPEMEM
`define	MASTER	fwb_master
`else
`define	MASTER	fwb_counter
`endif
	`MASTER #(.AW(AW), .F_LGDEPTH(F_LGDEPTH),
			.F_OPT_CLK2FFLOGIC(F_OPT_CLK2FFLOGIC),
			// .F_MAX_REQUESTS(14), // Not quite true, can do more
			.F_OPT_RMW_BUS_OPTION(IMPLEMENT_LOCK),
			.F_OPT_DISCONTINUOUS(IMPLEMENT_LOCK))
		fwb(i_clk, i_reset,
			cyc, f_stb, o_wb_we, o_wb_addr, o_wb_data, o_wb_sel,
				i_wb_ack, i_wb_stall, i_wb_data, i_wb_err,
			f_nreqs, f_nacks, f_outstanding);


	//
	// Assumptions about inputs
	//
	always @(posedge i_clk)
	if ((!f_past_valid)||($past(i_reset)))
	begin
		`ASSERT(!o_err);
		`ASSERT(!o_busy);
		`ASSERT(!o_pipe_stalled);
		`ASSERT(!o_valid);
	end

	always @(posedge i_clk)
		if (o_pipe_stalled)
			`ASSUME(!i_pipe_stb);

	// On any pipe request, the new address is the same or plus one
	always @(posedge i_clk)
		if ((f_past_valid)&&(f_cyc)&&(!i_wb_stall)&&(i_pipe_stb))
		begin
			`ASSUME( (i_addr[(AW+1):2] == o_wb_addr)
				||(i_addr[(AW+1):2] == o_wb_addr+1));
			`ASSUME(i_op[0] == o_wb_we);
		end

	always @(posedge i_clk)
		if ((r_wb_cyc_gbl)&&(i_pipe_stb))
			`ASSUME(gbl_stb);

	always @(posedge i_clk)
		if ((r_wb_cyc_lcl)&&(i_pipe_stb))
			`ASSUME(lcl_stb);

	// If stb is false, then either lock is on or there are no more STB's
	always @(posedge i_clk)
		if ((f_cyc)&&(!f_stb))
			`ASSUME((i_lock)||(!i_pipe_stb));

//always @(posedge i_clk)
//	if ((f_past_valid)&&($past(f_cyc))&&(!$past(i_lock)))
//		`ASSUME(!i_lock);

	wire	[3:0]	f_pipe_used;
	assign	f_pipe_used = wraddr - rdaddr;
	always @(*)
		`ASSERT(f_pipe_used == fifo_fill);
	always @(posedge i_clk)
	if (f_pipe_used == OPT_MAXDEPTH)

	begin
		`ASSUME(!i_pipe_stb);
		`ASSERT((o_busy)&&(o_pipe_stalled));
	end

	always @(*)
		`ASSERT(fifo_fill <= OPT_MAXDEPTH);

	always @(*)
		if (!IMPLEMENT_LOCK)
			`ASSUME(!i_lock);

	always @(*)
		if ((WITH_LOCAL_BUS)&&(o_wb_cyc_gbl|o_wb_cyc_lcl)
			&&(i_pipe_stb))
		begin
			if (o_wb_cyc_lcl)
				// `ASSUME(i_addr[31:24] == 8'hff);
				restrict(i_addr[31:24] == 8'hff);
			else
				restrict(i_addr[31:24] != 8'hff);
		end

	always @(*)
		if (!WITH_LOCAL_BUS)
		begin
			assert(!r_wb_cyc_lcl);
			assert(!o_wb_cyc_lcl);
			assert(!o_wb_stb_lcl);
		end

	always @(posedge i_clk)
		if ((f_past_valid)&&(!$past(f_cyc))&&(!$past(i_pipe_stb)))
			`ASSERT(f_pipe_used == 0);

	always @(*)
	if (!f_cyc)
		`ASSERT(f_pipe_used == 0);

	always @(posedge i_clk)
	if (f_pipe_used >= 13)
		`ASSUME(!i_pipe_stb);

	always @(posedge i_clk)
	if ((f_cyc)&&(f_pipe_used >= 13))
		`ASSERT((o_busy)&&(o_pipe_stalled));


	always @(posedge i_clk)
		`ASSERT((!r_wb_cyc_gbl)||(!r_wb_cyc_lcl));

	always @(posedge i_clk)
		`ASSERT((!o_wb_cyc_gbl)||(!o_wb_cyc_lcl));

	always @(posedge i_clk)
		`ASSERT((!o_wb_stb_gbl)||(!o_wb_stb_lcl));

	always @(*)
		if (!WITH_LOCAL_BUS)
		begin
			assert(!o_wb_cyc_lcl);
			assert(!o_wb_stb_lcl);
			if (o_wb_stb_lcl)
				assert(o_wb_addr[(AW-1):22] == {(8-(30-AW)){1'b1}});
		end

	always @(posedge i_clk)
		if (o_wb_stb_gbl)
			`ASSERT(o_wb_cyc_gbl);

	always @(posedge i_clk)
		if (o_wb_stb_lcl)
			`ASSERT(o_wb_cyc_lcl);

	always @(posedge i_clk)
		`ASSERT(cyc == (r_wb_cyc_gbl|r_wb_cyc_lcl));

	always @(posedge i_clk)
		`ASSERT(cyc == (r_wb_cyc_lcl)|(r_wb_cyc_gbl));
	always @(posedge i_clk)
	if ((f_past_valid)&&(!i_reset)&&(!$past(misaligned)))
	begin
		if (f_stb)
			`ASSERT(f_pipe_used == f_outstanding + 4'h1);
		else
			`ASSERT(f_pipe_used == f_outstanding);
	end

	always @(posedge i_clk)
		if ((f_past_valid)&&($past(r_wb_cyc_gbl||r_wb_cyc_lcl))
				&&(!$past(f_stb)))
			`ASSERT(!f_stb);

	always @(*)
		`ASSERT((!lcl_stb)||(!gbl_stb));

	wire	[(1<<FLN)-1:0]	f_gie_mem, f_mem_used, f_gie_or_zero, f_zero,
				f_gie_xor_test;
	//
	// insist that we only ever accept memory requests for the same GIE
	// (i.e. 4th bit of register)
	//
	wire	f_next_gie;
	assign	f_next_gie    = fifo_oreg[rdaddr][8];
	always @(*)
	if ((i_pipe_stb)&&(wraddr != rdaddr))
		`ASSUME(i_oreg[4] == f_next_gie);

	initial	f_pc = 1'b0;
	always @(posedge i_clk)
	if(i_reset)
		f_pc <= 1'b0;
	else if (i_pipe_stb)
		f_pc <= (((f_pc)&&(f_cyc))
				||((!i_op[0])&&(i_oreg[3:1] == 3'h7)));
	else if (!f_cyc)
		f_pc <= 1'b0;

	always @(posedge i_clk)
	if ((f_cyc)&&(o_wb_we))
		`ASSERT(!f_pc);

	always @(*)
	if ((f_pc)&&(f_cyc))
		`ASSUME(!i_pipe_stb);

	always @(*)
	if (wraddr == rdaddr)
	begin
		`ASSERT(!r_wb_cyc_gbl);
		`ASSERT(!r_wb_cyc_lcl);
	end else if (f_cyc)
	begin
		`ASSERT(fifo_fill == f_outstanding + ((f_stb)?1:0));
	end


`ifdef	PIPEMEM
	wire	[3:0]	lastaddr = wraddr - 1'b1;

	assign	f_gie_or_zero = (f_gie_mem & f_mem_used);
	assign	f_gie_xor_test= (f_gie_or_zero)^((f_next_gie)?f_mem_used : 0);

	integer	k;
	always @(*)
	begin
		for(k=0; k<(1<<FLN); k=k+1)
			f_gie_mem[k] = fifo_oreg[k][8];
		f_mem_used = 0;
		for(k = 0 ; k < (1<<FLN); k=k+1)
		begin
			if (wraddr == rdaddr)
				f_mem_used[k] = 1'b0;
			else if (wraddr > rdaddr)
			begin
				if ((k < wraddr)&&(k >= rdaddr))
					f_mem_used[k] = 1'b1;
			end else if (k < wraddr)
				f_mem_used[k] = 1'b1;
			else if (k >= rdaddr)
				f_mem_used[k] = 1'b1;
		end
	end


	always @(*)
	if (wraddr != rdaddr)
		`ASSERT(f_gie_xor_test == 0);

	always @(*)
	begin
		for(k=0; k<(1<<FLN); k=k+1)
		if ((f_mem_used[k])&&(!o_wb_we)&&((!f_pc)||(k!=lastaddr)))
			`ASSERT(fifo_oreg[k][7:5] != 3'h7);
	end

	initial	assert(!fifo_full);

	always @(posedge i_clk)
		cover(cyc && !fifo_full);

	always @(posedge i_clk)
		cover((f_cyc)&&(f_stb)&&(!i_wb_stall)&&(!i_wb_ack)
			&&(!o_pipe_stalled));

	always @(posedge i_clk)
	if ((f_past_valid)&&(!$past(f_stb))&&($past(f_cyc)))
		cover((f_cyc)&&(i_wb_ack));

	always @(posedge i_clk)
	if ((f_past_valid)&&(!$past(f_stb))&&($past(f_cyc)))
		cover($past(i_wb_ack)&&(i_wb_ack));

	always @(posedge i_clk)
	if ((f_past_valid)&&($past(o_valid)))
		cover(o_valid);

`endif // PIPEMEM

	always @(posedge i_clk)
	if ((f_past_valid)&&($past(f_past_valid))&&($past(f_cyc))&&($past(f_cyc,2)))
		`ASSERT($stable(o_wreg[4]));

	always @(*)
		`ASSERT((!f_cyc)||(!o_valid)||(o_wreg[3:1]!=3'h7));

`endif // FORMAL
endmodule
//
//
// Usage (from yosys): (Before)	(A,!OPTZ)	(A,OPTZ)
//	Cells:		302	314		391
//	  FDRE		138	140		140
//	  LUT1		  2	  2		  2
//	  LUT2		 38	 41		 61
//	  LUT3		 13	 16		 33
//	  LUT4		  3	  8		 12
//	  LUT5		 22	 10		  8
//	  LUT6		 52	 59		 81
//	  MUXCY		  6	  6		  6
//	  MUXF7		 10	 13		 21
//	  MUXF8		  1	  2		 10
//	  RAM64X1D	  9	  9		  9
//	  XORCY		  8	  8		  8
//
//
