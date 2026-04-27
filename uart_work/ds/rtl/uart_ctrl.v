// Module: uart_ctrl
// Function: Interrupt Aggregation + Mode Control + Flow Control
// Author: AI Agent
// Date: 2026-04-27
// Revision: v1.0

// Ref: Arch-Sec-5.6 uart_ctrl microarchitecture
// Ref: Arch-Sec-5.1 Data path - interrupt path
// Ref: Arch-Sec-5.2 Control logic

module uart_ctrl (
    input  wire       clk,
    input  wire       rst_n,
    // Configuration
    input  wire [3:0] ier,              // Interrupt Enable Register
    input  wire       loopback_en,      // MCR.LOOP
    input  wire       flow_ctrl_en,     // MCR.AFE
    input  wire [1:0] fcr_rx_trig,      // RX FIFO trigger level
    // TX status
    input  wire       tx_done,
    input  wire       tx_fifo_empty,
    input  wire       tx_busy,
    // RX status
    input  wire       rx_valid,
    input  wire       rx_fifo_full,
    input  wire       rx_fifo_empty,
    input  wire       rx_fifo_almost_full,
    input  wire       frame_err,
    input  wire       parity_err,
    input  wire       break_detect,
    input  wire       overrun_err,
    input  wire       rx_busy,
    // Flow control
    input  wire       cts_n,
    // Outputs
    output reg        irq,             // Interrupt output
    output reg  [3:0] iir,             // Interrupt Identification Register
    output reg  [7:0] lsr,             // Line Status Register
    output reg  [7:0] msr,             // Modem Status Register
    output reg        rts_n_out,       // RTS output
    output reg        tx_pause         // TX pause (CTS flow control)
);

// ----------------------------------------------------------
// Interrupt source pending signals
// Ref: Arch-Sec-5.2 Interrupt source definition
// Priority: OE > BI > FE > PE > RxAvailable > TxEmpty > RTOI
// ----------------------------------------------------------
wire int_oe  = overrun_err;                           // Priority 1
wire int_bi  = break_detect;                          // Priority 2
wire int_fe  = frame_err;                             // Priority 3
wire int_pe  = parity_err;                            // Priority 4
wire int_rx  = rx_valid;                              // Priority 5
wire int_tx  = tx_fifo_empty;                         // Priority 6
wire int_rto = 1'b0;                                  // Priority 7 (TODO: timeout)

// ----------------------------------------------------------
// Interrupt enable gating
// Ref: Arch-Sec-5.2 Interrupt enable control
// IER[0] = ERBFI (RX available)
// IER[1] = ETBEI (TX empty)
// IER[2] = ELSI  (Line status: OE/BI/FE/PE)
// IER[3] = EDSSI (Modem status)
// ----------------------------------------------------------
wire int_oe_en  = ier[2] && int_oe;
wire int_bi_en  = ier[2] && int_bi;
wire int_fe_en  = ier[2] && int_fe;
wire int_pe_en  = ier[2] && int_pe;
wire int_rx_en  = ier[0] && int_rx;
wire int_tx_en  = ier[1] && int_tx;
wire int_rto_en = ier[0] && int_rto;

// Any interrupt pending
wire any_int = int_oe_en || int_bi_en || int_fe_en || int_pe_en ||
               int_rx_en || int_tx_en || int_rto_en;

// ----------------------------------------------------------
// IIR priority encoding (combinational)
// Ref: Arch-Sec-5.1 Data path - interrupt priority encoding
// ----------------------------------------------------------
always @(*) begin
    iir = 4'b0001;  // Default: no interrupt (IIR[0]=1 means no int)
    // Ref: 16550 IIR encoding
    // IIR[3:0] = 4'b0001: No interrupt
    // IIR[3:0] = 4'b0010: TX Holding Register Empty (Priority 6)
    // IIR[3:0] = 4'b0100: RX Data Available (Priority 5)
    // IIR[3:0] = 4'b0110: Line Status Error - OE/BI/FE/PE (Priority 1~4)
    // IIR[3:0] = 4'b1100: Character Timeout (Priority 7)
    if (int_oe_en) begin
        iir = 4'b0110;  // Priority 1: OE - Line Status
    end else if (int_bi_en) begin
        iir = 4'b0110;  // Priority 2: BI - Line Status
    end else if (int_fe_en) begin
        iir = 4'b0110;  // Priority 3: FE - Line Status
    end else if (int_pe_en) begin
        iir = 4'b0110;  // Priority 4: PE - Line Status
    end else if (int_rx_en) begin
        iir = 4'b0100;  // Priority 5: RX Data Available
    end else if (int_tx_en) begin
        iir = 4'b0010;  // Priority 6: TX Holding Register Empty
    end else if (int_rto_en) begin
        iir = 4'b1100;  // Priority 7: Character Timeout
    end
end

// ----------------------------------------------------------
// IRQ output (registered)
// Ref: Arch-Sec-5.1 Data path - irq output
// ----------------------------------------------------------
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        irq <= 1'b0;
    end else begin
        irq <= any_int;
    end
end

// ----------------------------------------------------------
// LSR aggregation
// Ref: Arch-Sec-5.2 LSR bit definition
// Bit[0] = DR    (Data Ready)
// Bit[1] = OE    (Overrun Error)
// Bit[2] = PE    (Parity Error)
// Bit[3] = FE    (Frame Error)
// Bit[4] = BI    (Break Interrupt)
// Bit[5] = THRE  (TX Holding Register Empty)
// Bit[6] = TEMT  (Transmitter Empty)
// Bit[7] = RX_FIFO_ERR
// ----------------------------------------------------------
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        lsr <= 8'h60;  // THRE=1, TEMT=1 at reset
    end else begin
        lsr[0] <= !rx_fifo_empty;                 // DR: FIFO not empty
        lsr[1] <= overrun_err;                    // OE
        lsr[2] <= parity_err;                     // PE
        lsr[3] <= frame_err;                      // FE
        lsr[4] <= break_detect;                   // BI
        lsr[5] <= tx_fifo_empty;                  // THRE
        lsr[6] <= tx_fifo_empty && !tx_busy;      // TEMT
        lsr[7] <= 1'b0;                           // RX_FIFO_ERR (reserved)
    end
end

// ----------------------------------------------------------
// MSR update - CTS change detection
// Ref: Arch-Sec-5.2 MSR bit definition
// Bit[0] = DCTS (Delta CTS)
// Bit[4] = CTS  (Current CTS status)
// ----------------------------------------------------------
reg cts_prev;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        msr      <= 8'd0;
        cts_prev <= 1'b1;
    end else begin
        cts_prev <= cts_n;
        msr[0]   <= (cts_n != cts_prev);  // DCTS: change detected
        msr[4]   <= !cts_n;               // CTS: active low, invert for status
    end
end

// ----------------------------------------------------------
// RTS flow control
// Ref: Arch-Sec-5.2 Flow control - RTS
// When flow_ctrl_en: rts_n_out = !rx_fifo_almost_full
// ----------------------------------------------------------
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        rts_n_out <= 1'b1;  // Default: not requesting
    end else if (flow_ctrl_en) begin
        rts_n_out <= !rx_fifo_almost_full;
    end else begin
        rts_n_out <= 1'b1;
    end
end

// ----------------------------------------------------------
// CTS flow control - TX pause
// Ref: Arch-Sec-5.2 Flow control - CTS
// When flow_ctrl_en: tx_pause = cts_n (high = pause)
// ----------------------------------------------------------
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        tx_pause <= 1'b0;
    end else if (flow_ctrl_en) begin
        tx_pause <= cts_n;  // cts_n high = CTS inactive = pause TX
    end else begin
        tx_pause <= 1'b0;
    end
end

endmodule
