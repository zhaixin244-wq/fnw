// Module: uart_top
// Function: UART Top-Level Integration (submodule instantiation + signal connection only)
// Author: AI Agent
// Date: 2026-04-27
// Revision: v1.0

// Ref: Arch-Sec-5.6 uart_top microarchitecture
// IRON RULE: Top-level module ONLY does submodule instantiation and signal connection.
//            NO logic (no always blocks), NO combinational logic.

module uart_top #(
    parameter ADDR_WIDTH = 5,
    parameter DATA_WIDTH = 32
)(
    input  wire                  clk,
    input  wire                  rst_n,
    // APB interface
    input  wire [ADDR_WIDTH-1:0] paddr,
    input  wire                  psel,
    input  wire                  penable,
    input  wire                  pwrite,
    input  wire [DATA_WIDTH-1:0] pwdata,
    output wire [DATA_WIDTH-1:0] prdata,
    output wire                  pready,
    output wire                  pslverr,
    // UART interface
    output wire                  txd,
    input  wire                  rxd,
    output wire                  rts_n,
    input  wire                  cts_n,
    // Interrupt
    output wire                  irq
);

// ----------------------------------------------------------
// Internal signal declarations
// ----------------------------------------------------------

// Register module outputs
wire        dlab;
wire [3:0]  ier;
wire [7:0]  lcr;
wire [5:0]  mcr;
wire [7:0]  fcr;
wire [7:0]  dll;
wire [7:0]  dlh;
wire [7:0]  fcr_ext;
wire [7:0]  scr;

// Register read/write interface
wire        reg_wr_en;
wire        reg_rd_en;
wire [ADDR_WIDTH-1:0] reg_addr;
wire [DATA_WIDTH-1:0] reg_wr_data;
wire [DATA_WIDTH-1:0] reg_rd_data;

// Baud rate ticks
wire        baud_tick_16x;
wire        baud_tick_8x;
wire        baud_tick;

// TX FIFO interface
wire [9:0]  tx_fifo_rd_data;
wire        tx_fifo_empty;
wire        tx_fifo_rd_en;

// TX status
wire        tx_done;
wire        tx_busy;
wire        tx_pause;

// RX FIFO interface
wire [10:0] rx_fifo_wr_data;
wire        rx_fifo_wr_en;
wire        rx_fifo_full;
wire        rx_fifo_empty;
wire        rx_fifo_almost_full;

// RX status
wire        rx_valid;
wire        frame_err;
wire        parity_err;
wire        break_detect;
wire        rx_busy;

// RX FIFO read data
wire [10:0] rx_fifo_rd_data;

// Control module outputs
wire [3:0]  iir;
wire [7:0]  lsr;
wire [7:0]  msr;
wire        rts_n_out;

// Overrun error from RX FIFO overflow
wire        overrun_err_internal;

// Loopback and flow control
wire        loopback_en  = mcr[4];
wire        flow_ctrl_en = mcr[5];

// Loopback mux: rxd_actual = loopback_en ? txd : rxd
// Ref: Arch-Sec-5.6 Loopback connection
wire        rxd_actual   = loopback_en ? txd : rxd;

// TX FIFO write: from reg_mod when writing THR (addr=0x00, DLAB=0)
wire        tx_fifo_wr_en   = reg_wr_en && (reg_addr == 5'h00) && !dlab;
wire [9:0]  tx_fifo_wr_data = {2'b00, reg_wr_data[7:0]};

// RX FIFO read: from reg_mod when reading RBR (addr=0x00, DLAB=0)
wire        rx_fifo_rd_en   = reg_rd_en && (reg_addr == 5'h00) && !dlab;

// ----------------------------------------------------------
// RTS output: from uart_ctrl (not uart_rx)
// Ref: Arch-Sec-5.6 Submodule connection - uart_ctrl
// ----------------------------------------------------------
assign rts_n = rts_n_out;

// ----------------------------------------------------------
// Register read data mux (pure combinational assign)
// Ref: Arch-Sec-5.6 Register read data mux
// NOTE: Using assign instead of always to comply with
//       top-level no-logic rule
// ----------------------------------------------------------
wire [DATA_WIDTH-1:0] reg_rd_data_mux =
    (reg_addr == 5'h00) ? (dlab ? {24'd0, dll} : {24'd0, rx_fifo_rd_data[7:0]}) :
    (reg_addr == 5'h04) ? {28'd0, ier} :
    (reg_addr == 5'h08) ? {24'd0, 2'b11, 2'b11, iir[3:1], iir[0]} :
    (reg_addr == 5'h0C) ? {24'd0, lcr} :
    (reg_addr == 5'h10) ? {26'd0, mcr} :
    (reg_addr == 5'h14) ? {24'd0, lsr} :
    (reg_addr == 5'h18) ? {24'd0, msr} :
    (reg_addr == 5'h1C) ? {24'd0, scr} :
    (reg_addr == 5'h20) ? (dlab ? {24'd0, dll} : {DATA_WIDTH{1'b0}}) :
    (reg_addr == 5'h24) ? (dlab ? {24'd0, dlh} : {DATA_WIDTH{1'b0}}) :
    (reg_addr == 5'h28) ? {24'd0, fcr_ext} :
    {DATA_WIDTH{1'b0}};

assign reg_rd_data = reg_rd_data_mux;

// ----------------------------------------------------------
// Submodule instantiations (name-based connection)
// Ref: Arch-Sec-5.6 Submodule instantiation list
// ----------------------------------------------------------

// ----------------------------------------------------------
// uart_reg_mod: APB slave + register module
// ----------------------------------------------------------
uart_reg_mod #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH)
) u_reg_mod (
    .clk          (clk),
    .rst_n        (rst_n),
    .paddr        (paddr),
    .psel         (psel),
    .penable      (penable),
    .pwrite       (pwrite),
    .pwdata       (pwdata),
    .prdata       (prdata),
    .pready       (pready),
    .pslverr      (pslverr),
    .reg_wr_en    (reg_wr_en),
    .reg_rd_en    (reg_rd_en),
    .reg_addr     (reg_addr),
    .reg_wr_data  (reg_wr_data),
    .reg_rd_data  (reg_rd_data),
    .dlab         (dlab),
    .ier          (ier),
    .lcr          (lcr),
    .mcr          (mcr),
    .fcr          (fcr),
    .dll          (dll),
    .dlh          (dlh),
    .fcr_ext      (fcr_ext),
    .scr          (scr)
);

// ----------------------------------------------------------
// uart_baud_gen: Fractional baud rate generator
// ----------------------------------------------------------
uart_baud_gen u_baud_gen (
    .clk            (clk),
    .rst_n          (rst_n),
    .baud_div_int   ({dlh, dll}),
    .baud_div_frac  (fcr_ext[3:0]),
    .oversample_sel (fcr_ext[4]),
    .baud_tick_16x  (baud_tick_16x),
    .baud_tick_8x   (baud_tick_8x),
    .baud_tick      (baud_tick)
);

// ----------------------------------------------------------
// uart_tx: Transmitter
// ----------------------------------------------------------
uart_tx u_tx (
    .clk            (clk),
    .rst_n          (rst_n),
    .baud_tick_16x  (baud_tick_16x),
    .tx_data        (tx_fifo_rd_data[7:0]),
    .tx_fifo_empty  (tx_fifo_empty),
    .tx_fifo_rd_en  (tx_fifo_rd_en),
    .data_bits      (lcr[1:0]),
    .stop_bits      (lcr[2]),
    .parity_en      (lcr[3]),
    .parity_even    (lcr[4]),
    .cts_n          (cts_n),
    .loopback_en    (loopback_en),
    .tx_pause       (tx_pause),
    .txd            (txd),
    .tx_done        (tx_done),
    .tx_busy        (tx_busy)
);

// ----------------------------------------------------------
// uart_rx: Receiver
// ----------------------------------------------------------
uart_rx u_rx (
    .clk            (clk),
    .rst_n          (rst_n),
    .baud_tick_16x  (baud_tick_16x),
    .baud_tick_8x   (baud_tick_8x),
    .rxd            (rxd_actual),
    .rx_fifo_full   (rx_fifo_full),
    .rx_fifo_wr_en  (rx_fifo_wr_en),
    .rx_data        (rx_fifo_wr_data),
    .rx_valid       (rx_valid),
    .data_bits      (lcr[1:0]),
    .stop_bits      (lcr[2]),
    .parity_en      (lcr[3]),
    .parity_even    (lcr[4]),
    .oversample_sel (fcr_ext[4]),
    .loopback_en    (loopback_en),
    .frame_err      (frame_err),
    .parity_err     (parity_err),
    .break_detect   (break_detect),
    .rx_busy        (rx_busy),
    .rts_n          ()  // RTS from uart_ctrl, not uart_rx
);

// ----------------------------------------------------------
// uart_fifo TX: TX FIFO (DATA_WIDTH=10, DEPTH=16)
// Ref: Arch-Sec-5.6 Submodule instantiation - TX FIFO
// CBB Ref: uart_fifo
// ----------------------------------------------------------
uart_fifo #(
    .DATA_WIDTH(10),
    .DEPTH     (16)
) u_tx_fifo (
    .clk               (clk),
    .rst_n             (rst_n),
    .wr_en             (tx_fifo_wr_en),
    .wr_data           (tx_fifo_wr_data),
    .rd_en             (tx_fifo_rd_en),
    .rd_data           (tx_fifo_rd_data),
    .fifo_full         (),
    .fifo_empty        (tx_fifo_empty),
    .fifo_almost_full  (),
    .fifo_count        (),
    .fifo_overflow     (),
    .fifo_underflow    (),
    .almost_full_thresh(5'd15)
);

// ----------------------------------------------------------
// uart_fifo RX: RX FIFO (DATA_WIDTH=11, DEPTH=16)
// Ref: Arch-Sec-5.6 Submodule instantiation - RX FIFO
// CBB Ref: uart_fifo
// ----------------------------------------------------------
uart_fifo #(
    .DATA_WIDTH(11),
    .DEPTH     (16)
) u_rx_fifo (
    .clk               (clk),
    .rst_n             (rst_n),
    .wr_en             (rx_fifo_wr_en),
    .wr_data           (rx_fifo_wr_data),
    .rd_en             (rx_fifo_rd_en),
    .rd_data           (rx_fifo_rd_data),
    .fifo_full         (rx_fifo_full),
    .fifo_empty        (rx_fifo_empty),
    .fifo_almost_full  (rx_fifo_almost_full),
    .fifo_count        (),
    .fifo_overflow     (overrun_err_internal),
    .fifo_underflow    (),
    .almost_full_thresh({1'b0, fcr[5:4], 1'b1})
);

// ----------------------------------------------------------
// uart_ctrl: Interrupt + Flow control
// ----------------------------------------------------------
uart_ctrl u_ctrl (
    .clk                (clk),
    .rst_n              (rst_n),
    .ier                (ier),
    .tx_done            (tx_done),
    .tx_fifo_empty      (tx_fifo_empty),
    .rx_valid           (rx_valid),
    .rx_fifo_full       (rx_fifo_full),
    .rx_fifo_empty      (rx_fifo_empty),
    .rx_fifo_almost_full(rx_fifo_almost_full),
    .frame_err          (frame_err),
    .parity_err         (parity_err),
    .break_detect       (break_detect),
    .overrun_err        (overrun_err_internal),
    .cts_n              (cts_n),
    .loopback_en        (loopback_en),
    .flow_ctrl_en       (flow_ctrl_en),
    .fcr_rx_trig        (fcr[5:4]),
    .tx_busy            (tx_busy),
    .rx_busy            (rx_busy),
    .irq                (irq),
    .iir                (iir),
    .lsr                (lsr),
    .msr                (msr),
    .rts_n_out          (rts_n_out),
    .tx_pause           (tx_pause)
);

endmodule
