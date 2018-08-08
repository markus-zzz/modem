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

module tb #(
  parameter integer C_AXI_DATA_WIDTH = 32,
  parameter integer C_AXI_ADDR_WIDTH = 13
);

	reg clk, rst;

	wire axi_aclk;
	wire axi_aresetn;
	reg [C_AXI_ADDR_WIDTH-1 : 0] axi_awaddr;
	reg [2 : 0] axi_awprot;
	reg axi_awvalid;
	wire axi_awready;
	reg [C_AXI_DATA_WIDTH-1 : 0] axi_wdata;
	reg [(C_AXI_DATA_WIDTH/8)-1 : 0] axi_wstrb;
	reg axi_wvalid;
	wire axi_wready;
	wire [1 : 0] axi_bresp;
	wire axi_bvalid;
	reg axi_bready;
	reg [C_AXI_ADDR_WIDTH-1 : 0] axi_araddr;
	reg [2 : 0] axi_arprot;
	reg axi_arvalid;
	wire axi_arready;
	wire [C_AXI_DATA_WIDTH-1 : 0] axi_rdata;
	wire [1 : 0] axi_rresp;
	wire axi_rvalid;
	reg axi_rready;

	wire clk_req;
	wire irq;

	assign axi_aclk = clk;
	assign axi_aresetn = ~rst;

	modem_axi_top dut(
	  .S00_AXI_aclk(axi_aclk),
	  .S00_AXI_aresetn(axi_aresetn),
	  .S00_AXI_awaddr(axi_awaddr),
	  .S00_AXI_awprot(axi_awprot),
	  .S00_AXI_awvalid(axi_awvalid),
	  .S00_AXI_awready(axi_awready),
	  .S00_AXI_wdata(axi_wdata),
	  .S00_AXI_wstrb(axi_wstrb),
	  .S00_AXI_wvalid(axi_wvalid),
	  .S00_AXI_wready(axi_wready),
	  .S00_AXI_bresp(axi_bresp),
	  .S00_AXI_bvalid(axi_bvalid),
	  .S00_AXI_bready(axi_bready),
	  .S00_AXI_araddr(axi_araddr),
	  .S00_AXI_arprot(axi_arprot),
	  .S00_AXI_arvalid(axi_arvalid),
	  .S00_AXI_arready(axi_arready),
	  .S00_AXI_rdata(axi_rdata),
	  .S00_AXI_rresp(axi_rresp),
	  .S00_AXI_rvalid(axi_rvalid),
	  .S00_AXI_rready(axi_rready),

	  .clk_req_o(clk_req),
	  .irq_o(irq)
	);

	initial begin
		$dumpvars;
		clk = 0;
		rst = 1;

		#5
		rst = 0;
	end

	always clk = #1 ~clk;

endmodule

