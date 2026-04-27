// Module: uart_reg_mod
// Function: APB Slave Interface + 16550-compatible Register Module
// Author: AI Agent
// Date: 2026-04-27
// Revision: v1.0

// Ref: Arch-Sec-5.1 uart_reg_mod microarchitecture
// Ref: Arch-Sec-5.6 Register allocation table

module uart_reg_mod #(
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
    output reg  [DATA_WIDTH-1:0] prdata,
    output reg                   pready,
    output reg                   pslverr,
    // Register read/write interface (to functional modules)
    output reg                   reg_wr_en,
    output reg                   reg_rd_en,
    output reg  [ADDR_WIDTH-1:0] reg_addr,
    output reg  [DATA_WIDTH-1:0] reg_wr_data,
    input  wire [DATA_WIDTH-1:0] reg_rd_data,
    // Configuration outputs
    output reg                   dlab,       // LCR[7] - Divisor Latch Access Bit
    output reg  [3:0]            ier,        // Interrupt Enable Register
    output reg  [7:0]            lcr,        // Line Control Register
    output reg  [5:0]            mcr,        // Modem Control Register
    output reg  [7:0]            fcr,        // FIFO Control Register (WO, auto-clear)
    output reg  [7:0]            dll,        // Divisor Latch Low
    output reg  [7:0]            dlh,        // Divisor Latch High
    output reg  [7:0]            fcr_ext,    // Extended FIFO Control
    output reg  [7:0]            scr         // Scratch Register
);

// ----------------------------------------------------------
// APB transaction detection
// Ref: Arch-Sec-4.2 APB protocol
// ----------------------------------------------------------
wire apb_wr = psel && penable && pwrite && pready;
wire apb_rd = psel && penable && !pwrite && pready;

// Address validity check
wire addr_valid = (paddr <= 5'h28);

// ----------------------------------------------------------
// DLAB control
// Ref: Arch-Sec-5.2 Control logic - DLAB
// DLAB = LCR[7], controls access to DLL/DLH vs RBR/THR
// ----------------------------------------------------------
// DLAB is updated from LCR write (see write logic below)

// ----------------------------------------------------------
// APB write logic
// Ref: Arch-Sec-5.1 Data path - APB write
// ----------------------------------------------------------
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        reg_wr_en   <= 1'b0;
        reg_addr    <= {ADDR_WIDTH{1'b0}};
        reg_wr_data <= {DATA_WIDTH{1'b0}};
        dlab        <= 1'b0;
        ier         <= 4'd0;
        lcr         <= 8'd0;
        mcr         <= 6'd0;
        fcr         <= 8'd0;
        dll         <= 8'd0;
        dlh         <= 8'd0;
        fcr_ext     <= 8'd0;
        scr         <= 8'd0;
    end else begin
        // Default: clear single-cycle write enable
        reg_wr_en <= 1'b0;
        // FCR auto-clear after write (WO register)
        fcr <= 8'd0;

        if (apb_wr && addr_valid) begin
            reg_wr_en   <= 1'b1;
            reg_addr    <= paddr;
            reg_wr_data <= pwdata;

            case (paddr)
                5'h00: begin
                    // THR - handled by uart_tx (DLAB=0)
                end

                5'h04: begin
                    // IER - only accessible when DLAB=0
                    if (!dlab) begin
                        ier <= pwdata[3:0];
                    end
                end

                5'h08: begin
                    // FCR - write-only, auto-clear (DLAB=0)
                    if (!dlab) begin
                        fcr <= pwdata[7:0];
                    end
                end

                5'h0C: begin
                    // LCR - always accessible
                    lcr <= pwdata[7:0];
                end

                5'h10: begin
                    // MCR - always accessible
                    mcr <= pwdata[5:0];
                end

                5'h1C: begin
                    // SCR - always accessible
                    scr <= pwdata[7:0];
                end

                5'h20: begin
                    // DLL - only accessible when DLAB=1
                    if (dlab) begin
                        dll <= pwdata[7:0];
                    end
                end

                5'h24: begin
                    // DLH - only accessible when DLAB=1
                    if (dlab) begin
                        dlh <= pwdata[7:0];
                    end
                end

                5'h28: begin
                    // FCR_EXT - always accessible
                    fcr_ext <= pwdata[7:0];
                end

                default: ;
            endcase
        end

        // DLAB follows LCR[7]
        dlab <= lcr[7];
    end
end

// ----------------------------------------------------------
// APB read logic
// Ref: Arch-Sec-5.1 Data path - APB read
// ----------------------------------------------------------
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        reg_rd_en <= 1'b0;
        prdata    <= {DATA_WIDTH{1'b0}};
        pready    <= 1'b1;      // No wait states
        pslverr   <= 1'b0;
    end else begin
        // Default values
        reg_rd_en <= 1'b0;
        pready    <= 1'b1;      // No wait states (always ready)
        pslverr   <= 1'b0;

        if (apb_rd) begin
            if (addr_valid) begin
                reg_rd_en <= 1'b1;
                reg_addr  <= paddr;
                prdata    <= reg_rd_data;  // Data from functional modules
            end else begin
                // Address out of range - PSLVERR
                pslverr <= 1'b1;
                prdata  <= {DATA_WIDTH{1'b0}};
            end
        end
    end
end

// PREADY is always 1 (no wait states)
// Ref: Arch-Sec-4.2 Key timing parameters

endmodule
