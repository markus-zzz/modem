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

module fifo #(
  parameter aw = 5,
  parameter dw = 32
)
(
  input wire clk,
  input wire rst,
  input wire [dw-1:0] wr_data_i,
  input wire wr_en_i,
  output wire [dw-1:0] rd_data_o,
  input wire rd_en_i,
  output wire empty_o,
  output wire full_o,
  output wire almost_full_o
);

	reg[aw:0] rp; // MSB is for full/empty detection
	reg[aw:0] wp; // MSB is for full/empty detection
	reg[aw-1:0] n_elem;

	wire ren;
	wire wen;

	assign ren = rd_en_i & ~empty_o;
	assign wen = wr_en_i & ~full_o;

	dpram #(
	  .aw(aw),
	  .dw(dw)
	)u_ram(
	  .rclk(clk),
	  .rrst(rst),
	  .rce(ren),
	  .oe(1'b1),
	  .raddr(rp[aw-1:0]),
	  .do(rd_data_o),
	  .wclk(clk),
	  .wrst(rst),
	  .wce(wen),
	  .we(1'b1),
	  .waddr(wp[aw-1:0]),
	  .di(wr_data_i)
	);

	assign empty_o = rp[aw-1:0] == wp[aw-1:0] && rp[aw] == wp[aw];
	assign full_o  = rp[aw-1:0] == wp[aw-1:0] && rp[aw] != wp[aw];
	assign almost_full_o = n_elem[aw-1] & n_elem[aw-2]; // Almost full at 75%

	always @(posedge clk) begin
		if (rst) begin
			rp <= 0;
		end
		else if (ren) begin
			rp <= rp + 1;
		end
	end

	always @(posedge clk) begin
		if (rst) begin
			wp <= 0;
		end
		else if (wen) begin
			wp <= wp + 1;
		end
	end

	always @(posedge clk) begin
		if (rst) begin
			n_elem <= 0;
		end
		else begin
			case ({ren,wen})
			2'b00: n_elem <= n_elem;
			2'b01: n_elem <= n_elem + 1;
			2'b10: n_elem <= n_elem - 1;
			2'b11: n_elem <= n_elem;
			endcase
		end
	end

endmodule

