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

module up_conv # (
  parameter ntaps = 32  //number of filter taps
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

	reg [7:0] cntr;

	always @(posedge clk) begin
		if (rst) begin
			cntr <= 0;
		end
		else if (y_ready_i) begin
			cntr <= cntr + 1;
		end
	end

	assign y_a_o = (cntr[2:0] == 0) ? x_a_i : 0;
	assign y_b_o = (cntr[2:0] == 0) ? x_b_i : 0;
	assign x_ready_o = (cntr[2:0] == 0) ? 1 : 0;
	assign y_valid_o = 1;

endmodule
