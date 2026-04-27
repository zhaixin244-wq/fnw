// Module: uart_fifo
// Function: Parameterized Synchronous FIFO (CBB)
// Author: AI Agent
// Date: 2026-04-27
// Revision: v1.0

// Ref: Arch-Sec-5.5 FIFO / 缓冲设计
// CBB Ref: uart_fifo_microarch_v1.0.md

module uart_fifo #(
    parameter  DATA_WIDTH = 8,
    parameter  DEPTH      = 16,
    localparam CNT_WIDTH  = $clog2(DEPTH) + 1
)(
    input  wire                  clk,
    input  wire                  rst_n,
    // Write interface
    input  wire                  wr_en,
    input  wire [DATA_WIDTH-1:0] wr_data,
    // Read interface
    input  wire                  rd_en,
    output reg  [DATA_WIDTH-1:0] rd_data,
    // Status flags
    output reg                   fifo_full,
    output reg                   fifo_empty,
    output reg                   fifo_almost_full,
    output reg  [CNT_WIDTH-1:0]  fifo_count,
    output reg                   fifo_overflow,
    output reg                   fifo_underflow,
    // Configuration
    input  wire [CNT_WIDTH-1:0]  almost_full_thresh
);

// ----------------------------------------------------------
// Internal signals
// ----------------------------------------------------------
// Ref: Arch-Sec-5.1 Register array
reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

// Ref: Arch-Sec-5.2 Multi-1-bit pointers
reg [CNT_WIDTH-1:0] wr_ptr;
reg [CNT_WIDTH-1:0] rd_ptr;

// Effective write/read enables (gated by full/empty)
wire wr_valid = wr_en && !fifo_full;
wire rd_valid = rd_en && !fifo_empty;

// ----------------------------------------------------------
// Write pointer and memory write
// Ref: Arch-Sec-5.1 Data path - Write operation
// ----------------------------------------------------------
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        wr_ptr <= {CNT_WIDTH{1'b0}};
    end else if (wr_valid) begin
        mem[wr_ptr[CNT_WIDTH-2:0]] <= wr_data;
        wr_ptr <= wr_ptr + 1'b1;
    end
end

// ----------------------------------------------------------
// Read pointer and data output
// Ref: Arch-Sec-5.1 Data path - Read operation
// ----------------------------------------------------------
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        rd_ptr  <= {CNT_WIDTH{1'b0}};
        rd_data <= {DATA_WIDTH{1'b0}};
    end else if (rd_valid) begin
        rd_data <= mem[rd_ptr[CNT_WIDTH-2:0]];
        rd_ptr  <= rd_ptr + 1'b1;
    end
end

// ----------------------------------------------------------
// Full / Empty / Almost-full flags (combinational)
// Ref: Arch-Sec-5.2 Full/empty detection using multi-1-bit pointer
// Full:  wr_ptr[MSB] != rd_ptr[MSB] && wr_ptr[LSB:0] == rd_ptr[LSB:0]
// Empty: wr_ptr == rd_ptr
// ----------------------------------------------------------
always @(*) begin
    fifo_full  = (wr_ptr[CNT_WIDTH-1] != rd_ptr[CNT_WIDTH-1]) &&
                 (wr_ptr[CNT_WIDTH-2:0] == rd_ptr[CNT_WIDTH-2:0]);
    fifo_empty = (wr_ptr == rd_ptr);
    fifo_almost_full = (fifo_count >= almost_full_thresh);
end

// ----------------------------------------------------------
// Data count register
// Ref: Arch-Sec-5.2 Control logic - count
// Simultaneous read/write: count unchanged
// ----------------------------------------------------------
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        fifo_count <= {CNT_WIDTH{1'b0}};
    end else begin
        case ({wr_valid, rd_valid})
            2'b10:   fifo_count <= fifo_count + 1'b1;  // Write only
            2'b01:   fifo_count <= fifo_count - 1'b1;  // Read only
            default: fifo_count <= fifo_count;          // Both or neither
        endcase
    end
end

// ----------------------------------------------------------
// Overflow / Underflow flags (single-cycle pulse)
// Ref: Arch-Sec-5.2 Flow control - overflow/underflow
// ----------------------------------------------------------
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        fifo_overflow  <= 1'b0;
        fifo_underflow <= 1'b0;
    end else begin
        fifo_overflow  <= wr_en && fifo_full;
        fifo_underflow <= rd_en && fifo_empty;
    end
end

endmodule
