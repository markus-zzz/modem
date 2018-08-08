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

module rx_ctrl(
  input wire clk,
  input wire rst,
  input wire [7:0] rp_i,
  output wire [7:0] wp_o,
  output wire [31:0] wdata_o,
  output wire [7:0] waddr_o,
  output wire wen_o,
  input wire [7:0] byte_i,
  output wire valid_i,
  output wire begin_i,
  output wire end_i,
  output wire clk_req_o,
  output wire irq_o
);

	reg [7:0] wp;
	assign wp_o = wp;

	reg [7:0] wp_tmp;

	assign clk_req_o = (curr_state != S_IDLE);
	assign irq_o = (curr_state == S_MSG_HEADER);

	/*
		rp == wp => buffer is empty

		rp <= wp : free space is buffer_size - (wp - rp) - 1
		rp >  wp : free space is rp - wp - 1
	*/
	wire [7:0] free_space;
	assign free_space = (rp_i <= wp_tmp) ?  9'h100 - (wp_tmp - rp_i) - 1 : (rp_i - wp_tmp) - 1;

	//
	// FSM for RX ring buffer management
	//

	parameter S_IDLE         = 1 << 0,
	          S_MSG_HEADER   = 1 << 1,
	          S_MSG_PAYLOAD  = 1 << 2,
	          S_MSG_OVERFLOW = 1 << 3,
	          S_MSG_FLUSH    = 1 << 4;

	reg [5:0] curr_state, next_state;

	always @(posedge clk) begin
		if (rst) begin
			curr_state <= S_IDLE;
		end
		else begin
			curr_state <= next_state;
		end
	end

	always @(*) begin

		next_state = curr_state;

		case (curr_state)
			S_IDLE: begin
				if (valid_i) begin
					next_state = S_MSG_PAYLOAD;
				end
			end
			S_MSG_PAYLOAD: begin
				if (free_space < 3) begin
					next_state = S_MSG_OVERFLOW;
				end
				else if (end_i) begin
					next_state = S_MSG_FLUSH;
				end
			end
			S_MSG_FLUSH: begin
				next_state = S_MSG_HEADER;
			end
			S_MSG_HEADER: begin
				next_state = S_IDLE;
			end
			S_MSG_OVERFLOW: begin
				if (end_i) begin
					next_state = S_IDLE;
				end
			end
		endcase

	end

	always @(posedge clk) begin
		if (rst) begin
			wp_tmp <= 0;
		end
		else if (curr_state == S_IDLE && valid_i) begin
			wp_tmp <= wp + 1;
		end
		else if (curr_state == S_MSG_PAYLOAD && valid_i && msg_byte_idx[1:0] == 2'b00) begin
			wp_tmp <= wp_tmp + 1;
		end
	end

	always @(posedge clk) begin
		if (rst) begin
			wp <= 0;
		end
		else if (curr_state == S_MSG_HEADER) begin
			wp <= wp_tmp + 1;
		end
	end


	reg [31:0] wdata_staging;
	reg [9:0] msg_byte_idx;

	assign wdata_o = (curr_state == S_MSG_HEADER) ? msg_byte_idx : wdata_staging;
	assign waddr_o = (curr_state == S_MSG_HEADER) ? wp : wp_tmp;

	assign wen_o = (curr_state == S_MSG_PAYLOAD && msg_byte_idx[1:0] == 2'b00 && valid_i) ||
	                curr_state == S_MSG_HEADER ||
	                curr_state == S_MSG_FLUSH;

	always @(posedge clk) begin
		if (rst) begin
			wdata_staging <= 0;
		end
		else if (valid_i) begin
			case (msg_byte_idx[1:0])
				2'b00: wdata_staging[7:0]   <= byte_i;
				2'b01: wdata_staging[15:8]  <= byte_i;
				2'b10: wdata_staging[23:16] <= byte_i;
				2'b11: wdata_staging[31:24] <= byte_i;
			endcase
		end
	end

	always @(posedge clk) begin
		if (rst || curr_state == S_MSG_HEADER) begin
			msg_byte_idx <= 0;
		end
		else if (valid_i) begin
			msg_byte_idx <= msg_byte_idx + 1;
		end
	end
endmodule
