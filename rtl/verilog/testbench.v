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
	  .aw(4),
	  .ntaps(4),
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

	assign x = (idx == 32 || idx == 40) ? 1 : 0;

	always @(posedge clk) begin
		if (rst) begin
			idx <= 0;
		end
		else if (x_ready) begin
			idx <= idx + 1;
		end
	end

	initial begin
		$dumpvars;
		clk = 0;
		rst = 1;

		#5
		rst = 0;

		# 1000 $finish;
	end

	always clk = #1 ~clk;

	always @(posedge clk) begin
		if (y_valid) begin
			$display("y: %h", y);
		end
	end


endmodule

