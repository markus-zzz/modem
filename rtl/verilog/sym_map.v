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

module sym_map (
  input wire clk,
  input wire rst,

  input wire [7:0] x_i,
  input wire x_valid_i,
  output wire x_ready_o,

  output wire [15:0] y_a_o,
  output wire [15:0] y_b_o,
  output wire y_valid_o,
  input wire y_ready_i
);
	parameter S_READY    = 1 << 0,
	          S_SYM_0    = 1 << 1,
	          S_SYM_1    = 1 << 1,
	          S_SYM_2    = 1 << 1,
	          S_SYM_3    = 1 << 1;

	reg [7:0] curr_state, next_state;

	always @(posedge clk) begin
		if (rst) begin
			curr_state <= S_READY;
		end
		else begin
			curr_state <= next_state;
		end
	end

	always @(*) begin
		next_state = curr_state;
		case (curr_state)
			S_READY: begin
				if (x_valid_i) begin
					next_state = S_SYM_0;
				end
			end
			S_SYM_0: begin
				if (y_ready_i) begin
					next_state = S_SYM_1;
				end
			end
			S_SYM_1: begin
				if (y_ready_i) begin
					next_state = S_SYM_2;
				end
			end
			S_SYM_2: begin
				if (y_ready_i) begin
					next_state = S_SYM_3;
				end
			end
			S_SYM_3: begin
				if (y_ready_i) begin
					next_state = S_READY;
				end
			end
		endcase
	end

	reg [1:0] sym_bits;
	always @(*) begin
		case (curr_state)
			default: sym_bits = octet[1:0];
			S_SYM_1: sym_bits = octet[3:2];
			S_SYM_2: sym_bits = octet[5:4];
			S_SYM_3: sym_bits = octet[7:6];
		endcase
	end

	wire [15:0] sym_I;
	wire [15:0] sym_Q;

	// A(2,13) constants for +/- one
	wire [15:0] pos_one;
	wire [15:0] neg_one;
	assign pos_one = 16'b0_01_0000_0000_0000_0;
	assign neg_one = 16'b1_11_0000_0000_0000_0;

	assign sym_I = sym_bits[0] ? pos_one : neg_one;
	assign sym_Q = sym_bits[1] ? pos_one : neg_one;

	assign x_ready_o = (curr_state == S_READY);
	reg [7:0] octet;
	always @(posedge clk) begin
		if (rst) begin
			octet <= 0;
		end
		else if (curr_state == S_READY && x_valid_i) begin
			octet <= x_i;
		end
	end

endmodule
