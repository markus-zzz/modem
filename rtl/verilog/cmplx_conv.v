/*
 * Copyright (C) 2018 Markus Lavin (https://www.zzzconsulting.se/)
 *
 * All rights reserved.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 *
 */

module cmplx_conv # (
  parameter aw = 10,     //number of address-bits
  parameter ntaps = 32,  //number of filter taps
  parameter coeffs = ""  //init file for filter coeffs
)
(

  input wire clk,
  input wire rst,

  input wire [15:0] x_a_i,
  input wire [15:0] x_b_i,
  input wire x_valid_i,
  output wire x_ready_o,

  output wire [15:0] y_a_o,
  output wire [15:0] y_b_o,
  output wire y_valid_o,
  input wire y_ready_i
);

	parameter S_READY    = 1 << 0,
	          S_LOAD     = 1 << 1,
	          S_COMP_0   = 1 << 2,
	          S_COMP_1   = 1 << 3,
	          S_COMP_2   = 1 << 4,
	          S_DONE     = 1 << 5;

	reg [7:0] curr_state, next_state;

	always @(posedge clk) begin
		if (rst) begin
			curr_state <= S_READY;
		end
		else begin
			curr_state <= next_state;
		end
	end

	reg [aw-1:0] x_wp;
	reg [aw-1:0] idx;

	wire [aw-1:0] x_addr;
	wire x_we;

	wire [31:0] x_di, x_do;
	wire [15:0] h_do;

	assign x_addr = (curr_state == S_LOAD) ? x_wp : x_wp - idx;
	assign x_we = (curr_state == S_LOAD);
	assign x_di = {x_a_i, x_b_i};

	assign x_ready_o = (curr_state == S_LOAD);
	assign y_valid_o = (curr_state == S_DONE);

	spram # (
	  .aw(aw),
	  .dw(32))
	u_x_mem (
	  .clk(clk),
	  .rst(rst),
	  .ce(1'b1),
	  .we(x_we),
	  .oe(1'b1),
	  .addr(x_addr),
	  .di(x_di),
	  .do(x_do)
	);

	sprom # (
	  .aw(aw),
	  .dw(16),
	  .MEM_INIT_FILE(coeffs))
	u_h_mem (
	  .clk(clk),
	  .rst(rst),
	  .ce(1'b1),
	  .oe(1'b1),
	  .addr(idx),
	  .do(h_do)
	);

	always @(posedge clk) begin
		if (rst || curr_state == S_READY) begin
			idx <= 0;
		end
		else if (curr_state == S_COMP_0 || curr_state == S_COMP_1) begin
			idx <= idx + 1;
		end
	end

	always @(posedge clk) begin
		if (rst) begin
			x_wp <= 0;
		end
		else if (curr_state == S_COMP_2) begin
			x_wp <= x_wp + 1;
		end
	end

	always @(*) begin
		next_state = curr_state;
		case (curr_state)
			S_READY: begin
				if (x_valid_i) begin
					next_state = S_LOAD;
				end
			end
			S_LOAD: begin
				next_state = S_COMP_0;
			end
			S_COMP_0: begin
				next_state = S_COMP_1;
			end
			S_COMP_1: begin
				if (idx == ntaps - 1) begin
					next_state = S_COMP_2;
				end
			end
			S_COMP_2: begin
				next_state = S_DONE;
			end
			S_DONE: begin
				if (y_ready_i) begin
					next_state = S_READY;
				end
			end
		endcase
	end

	reg [23:0] accum_a, accum_b;

	always @(posedge clk) begin
		if (rst || curr_state == S_COMP_0) begin
			accum_a <= 0;
			accum_b <= 0;
		end
		else if (curr_state == S_COMP_1 || curr_state == S_COMP_2) begin
			accum_a <= accum_a + x_do[15:0] * h_do;
			accum_b <= accum_b + x_do[31:16] * h_do;
		end
	end

	assign y_a_o = accum_a[15:0];
	assign y_b_o = accum_b[15:0];

endmodule
