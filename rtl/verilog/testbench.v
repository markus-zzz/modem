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

module tb;

	reg clk, rst;

	wire x_ready;
	wire y_valid;

	cmplx_conv # (
	  .aw(6),
	  .ntaps(60),
	  .coeffs("coeffs.dat"))
	dut (
	  .clk(clk),
	  .rst(rst),
	  .x_a_i(x),
	  .x_b_i(x),
	  .x_valid_i(1'b1),
	  .x_ready_o(x_ready),
	  .y_a_o(y),
	  .y_b_o(),
	  .y_valid_o(y_valid),
	  .y_ready_i(1'b1)
	);

	reg [15:0] idx;
	wire [15:0] x;
	wire [15:0] y;

	// Insert alternating (-1,1) symbol every 8th sample (rest is zeros)
//	assign x = (idx[2:0] == 0) ? (idx[3] ? 1 : -1) : 0;
	assign x = (idx[2:0] == 0) ? xx[idx[15:3]] : 0;

	reg [15:0] xx[0:15];


	always @(posedge clk) begin
		if (rst) begin
			idx <= 0;
		end
		else if (x_ready) begin
			idx <= idx + 1;
		end
	end

	initial begin
		xx[0] = 1;
		xx[1] = 1;
		xx[2] = 1;
		xx[3] = 1;
		xx[4] = -1;
		xx[5] = -1;
		xx[6] = -1;
		xx[7] = 1;
		xx[8] = 1;
		xx[9] = -1;
		xx[10] = 1;
		xx[11] = 1;
		xx[12] = -1;
		xx[13] = 1;
		xx[14] = -1;
		xx[15] = 1;

		$dumpvars;
		clk = 0;
		rst = 1;

		#5
		rst = 0;

		# 80000 $finish;
	end

	always clk = #1 ~clk;

	always @(posedge clk) begin
		if (y_valid) begin
			$display("y: %h", y);
		end
	end


endmodule

