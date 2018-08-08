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

module modem_axi_top #(
  parameter integer C_S00_AXI_DATA_WIDTH = 32,
  parameter integer C_S00_AXI_ADDR_WIDTH = 13
)
(
  /* AXI interface */
  input wire  S00_AXI_aclk,
  input wire  S00_AXI_aresetn,
  input wire [C_S00_AXI_ADDR_WIDTH-1 : 0] S00_AXI_awaddr,
  input wire [2 : 0] S00_AXI_awprot,
  input wire  S00_AXI_awvalid,
  output wire  S00_AXI_awready,
  input wire [C_S00_AXI_DATA_WIDTH-1 : 0] S00_AXI_wdata,
  input wire [(C_S00_AXI_DATA_WIDTH/8)-1 : 0] S00_AXI_wstrb,
  input wire  S00_AXI_wvalid,
  output wire  S00_AXI_wready,
  output wire [1 : 0] S00_AXI_bresp,
  output wire  S00_AXI_bvalid,
  input wire  S00_AXI_bready,
  input wire [C_S00_AXI_ADDR_WIDTH-1 : 0] S00_AXI_araddr,
  input wire [2 : 0] S00_AXI_arprot,
  input wire  S00_AXI_arvalid,
  output wire  S00_AXI_arready,
  output wire [C_S00_AXI_DATA_WIDTH-1 : 0] S00_AXI_rdata,
  output wire [1 : 0] S00_AXI_rresp,
  output wire  S00_AXI_rvalid,
  input wire  S00_AXI_rready,

  output wire clk_req_o,
  output wire irq_o
);
	wire clk;
	wire rst;

	assign clk = S00_AXI_aclk;
	assign rst = ~S00_AXI_aresetn;

	wire [7:0] rx_rp;
	wire [7:0] rx_wp;
	wire [7:0] tx_rp;
	wire [7:0] tx_wp;


	wire [31:0] rx_rdata;
	wire [7:0] rx_raddr;
	wire [31:0] rx_wdata;
	wire [7:0] rx_waddr;

	wire [31:0] tx_rdata;
	wire [7:0] tx_raddr;
	wire [31:0] tx_wdata;
	wire [7:0] tx_waddr;
	wire tx_wen;
	wire tx_rce;
	wire rx_wen;

	wire [7:0] tx_byte;
	reg [7:0] rx_byte;

	wire msg_begin;
	wire msg_end;
	wire byte_valid;

	wire tx_clk_req;
	wire rx_clk_req;
	wire tx_irq;
	wire rx_irq;

	assign clk_req_o = tx_clk_req | rx_clk_req;
	assign irq_o = tx_irq | rx_irq;

	reg [7:0] ready_cntr;
	wire ready;
	assign ready = (ready_cntr[1:0] == 2'b01);
	always @(posedge clk) begin
		if (rst) begin
			ready_cntr <= 0;
		end
		else begin
			ready_cntr <= ready_cntr + 1;
		end
	end

	wire rx_ready;
	assign rx_ready = ready & byte_valid;

	modem_axi_slave # (
	  .C_S_AXI_DATA_WIDTH(C_S00_AXI_DATA_WIDTH),
	  .C_S_AXI_ADDR_WIDTH(C_S00_AXI_ADDR_WIDTH))
	u_modem_axi_slave (
	  .S_AXI_ACLK(S00_AXI_aclk),
	  .S_AXI_ARESETN(S00_AXI_aresetn),
	  .S_AXI_AWADDR(S00_AXI_awaddr),
	  .S_AXI_AWPROT(S00_AXI_awprot),
	  .S_AXI_AWVALID(S00_AXI_awvalid),
	  .S_AXI_AWREADY(S00_AXI_awready),
	  .S_AXI_WDATA(S00_AXI_wdata),
	  .S_AXI_WSTRB(S00_AXI_wstrb),
	  .S_AXI_WVALID(S00_AXI_wvalid),
	  .S_AXI_WREADY(S00_AXI_wready),
	  .S_AXI_BRESP(S00_AXI_bresp),
	  .S_AXI_BVALID(S00_AXI_bvalid),
	  .S_AXI_BREADY(S00_AXI_bready),
	  .S_AXI_ARADDR(S00_AXI_araddr),
	  .S_AXI_ARPROT(S00_AXI_arprot),
	  .S_AXI_ARVALID(S00_AXI_arvalid),
	  .S_AXI_ARREADY(S00_AXI_arready),
	  .S_AXI_RDATA(S00_AXI_rdata),
	  .S_AXI_RRESP(S00_AXI_rresp),
	  .S_AXI_RVALID(S00_AXI_rvalid),
	  .S_AXI_RREADY(S00_AXI_rready),

	  .rx_wp_i(rx_wp),
	  .tx_rp_i(tx_rp),
	  .rx_rp_o(rx_rp),
	  .tx_wp_o(tx_wp),

	  .tx_wdata_o(tx_wdata),
	  .tx_waddr_o(tx_waddr),
	  .tx_wen_o(tx_wen),

	  .rx_rdata_i(rx_rdata),
	  .rx_raddr_o(rx_raddr)
	);

	// TX Ring Buffer 1 KiB
	dpram # (
	  .aw(8),
	  .dw(32))
	u_tx_dpram (
	  .rclk(clk),
	  .rrst(rst),
	  .rce(tx_rce),
	  .oe(1'b1),
	  .raddr(tx_raddr),
	  .do(tx_rdata),
	  .wclk(clk),
	  .wrst(rst),
	  .wce(tx_wen),
	  .we(1'b1),
	  .waddr(tx_waddr),
	  .di(tx_wdata)
	);

	tx_ctrl u_tx_ctrl(
	  .clk(clk),
	  .rst(rst),
	  .wp_i(tx_wp),
	  .rp_o(tx_rp),
	  .rdata_i(tx_rdata),
	  .raddr_o(tx_raddr),
	  .rce_o(tx_rce),
	  .byte_o(tx_byte),
	  .begin_o(msg_begin),
	  .ready_i(ready),
	  .valid_o(byte_valid),
	  .end_o(msg_end),
	  .clk_req_o(tx_clk_req),
	  .irq_o(tx_irq)
	);

	// RX Ring Buffer 1 KiB
	dpram # (
	  .aw(8),
	  .dw(32))
	u_rx_dpram (
	  .rclk(clk),
	  .rrst(rst),
	  .rce(1'b1),
	  .oe(1'b1),
	  .raddr(rx_raddr),
	  .do(rx_rdata),
	  .wclk(clk),
	  .wrst(rst),
	  .wce(rx_wen),
	  .we(1'b1),
	  .waddr(rx_waddr),
	  .di(rx_wdata)
	);

	rx_ctrl u_rx_ctrl(
	  .clk(clk),
	  .rst(rst),
	  .rp_i(rx_rp),
	  .wp_o(rx_wp),
	  .wdata_o(rx_wdata),
	  .waddr_o(rx_waddr),
	  .wen_o(rx_wen),
	  .byte_i(rx_byte),
	  .begin_i(msg_begin),
	  .valid_i(rx_ready),
	  .end_i(msg_end),
	  .clk_req_o(rx_clk_req),
	  .irq_o(rx_irq)
	);

	//
	// Default address and data buses width
	//
	parameter aw = 5;  // number of bits in address-bus
	parameter dw = 16; // number of bits in data-bus

	//
	// Do the silly action of changing upper case to lower case and vice versa
	//

	task switch_case;
		input [7:0] in;
		output [7:0] out;
		begin
			out = in;
			if ("A" <= in && in <= "Z") begin
				//Is upper case
				out = in + ("a" - "A");
			end
			else if ("a" <= in && in <= "z") begin
				//Is lower case
				out = in - ("a" - "A");
			end
		end
	endtask

	always @(tx_byte) begin
		switch_case(tx_byte, rx_byte);
	end
/*
	always @(posedge clk) begin
		if (rx_ready) $display("tx_byte: %x '%c'", tx_byte, tx_byte);
	end
*/

endmodule
