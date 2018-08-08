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

module tx_ctrl(
  input wire clk,
  input wire rst,
  input wire [7:0] wp_i,
  output wire [7:0] rp_o,

  input wire [31:0] rdata_i,
  output wire [7:0] raddr_o,
  output wire rce_o,
  output wire [7:0] byte_o,
  output wire begin_o,
  input wire ready_i,
  output wire valid_o,
  output wire end_o,
  output wire clk_req_o,
  output wire irq_o
);

	reg [7:0] rp;
	reg [31:0] rdata;

	assign rp_o = rp;

	assign clk_req_o = (curr_state != S_IDLE);
	assign irq_o = (curr_state == S_MSG_FINISH);

	assign rce_o = (curr_state == S_MSG_HEADER_0) || (curr_state == S_MSG_PAYLOAD_0);
	assign raddr_o = (curr_state == S_MSG_HEADER_0) ? rp : rp + 1 + msg_byte_idx[9:2];

	//
	// FSM for TX ring buffer management
	//

	parameter S_IDLE           = 1 << 0,
	          S_MSG_HEADER_0   = 1 << 1,
	          S_MSG_HEADER_1   = 1 << 2,
	          S_MSG_PAYLOAD_0  = 1 << 3,
	          S_MSG_PAYLOAD_1  = 1 << 4,
	          S_MSG_PAYLOAD_2  = 1 << 5,
	          S_MSG_FINISH     = 1 << 6;

	reg [7:0] curr_state, next_state;

	always @(posedge clk) begin
		if (rst) begin
			curr_state <= S_IDLE;
		end
		else begin
			curr_state <= next_state;
		end
	end

	reg [9:0] msg_byte_len;
	reg [9:0] msg_byte_idx;

	always @(posedge clk) begin
		if (rst) begin
			msg_byte_len <= 0;
		end
		else if (curr_state == S_MSG_HEADER_1) begin
			msg_byte_len <= rdata_i[9:0];
		end
	end

	always @(posedge clk) begin
		if (rst || curr_state == S_MSG_HEADER_0) begin
			msg_byte_idx <= 0;
		end
		else if (curr_state == S_MSG_PAYLOAD_2 && ready_i) begin
			msg_byte_idx <= msg_byte_idx + 1;
		end
	end


	always @(*) begin

		next_state = curr_state;

		case (curr_state)
			S_IDLE: begin
				if (wp_i != rp) begin
					next_state = S_MSG_HEADER_0;
				end
			end
			S_MSG_HEADER_0: begin
				next_state = S_MSG_HEADER_1;
			end
			S_MSG_HEADER_1: begin
				next_state = S_MSG_PAYLOAD_0;
			end
			S_MSG_PAYLOAD_0: begin
				next_state = S_MSG_PAYLOAD_1;
			end
			S_MSG_PAYLOAD_1: begin
				next_state = S_MSG_PAYLOAD_2;
			end
			S_MSG_PAYLOAD_2: begin
				if (ready_i) begin
					if (msg_byte_idx == msg_byte_len - 1) begin
						next_state = S_MSG_FINISH;
					end
					else if (msg_byte_idx[1:0] == 2'b11) begin
						next_state = S_MSG_PAYLOAD_0;
					end
				end
			end
			S_MSG_FINISH: begin
				next_state = S_IDLE;
			end
		endcase
	end

	always @(posedge clk) begin
		if (rst) begin
			rp <= 0;
		end
		else if (curr_state == S_MSG_FINISH) begin
			rp <= rp + 1 + msg_byte_len[9:2] + (msg_byte_len[1:0] ? 1 : 0);
		end
	end

	reg [7:0] byte;

	assign byte_o = byte;
	assign valid_o = (curr_state == S_MSG_PAYLOAD_2);
	assign begin_o = (curr_state == S_MSG_HEADER_0);
	assign end_o = (curr_state == S_MSG_FINISH);

	always @(posedge clk) begin
		if (rst) begin
			rdata <= 0;
		end
		else if (curr_state == S_MSG_PAYLOAD_1) begin
			rdata <= rdata_i;
		end
	end

	always @(*) begin
		case (msg_byte_idx[1:0])
			2'b00: byte = rdata[7:0];
			2'b01: byte = rdata[15:8];
			2'b10: byte = rdata[23:16];
			2'b11: byte = rdata[31:24];
		endcase
	end

endmodule
