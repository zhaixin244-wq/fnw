// Module: uart_sva
// Function: SVA Assertions for UART modules (bind to each submodule)
// Author: AI Agent
// Date: 2026-04-27
// Revision: v1.0

// Ref: Arch-Sec-10 Verification - SVA assertion points
// Ref: coding-style.md §11 SVA assertions

`ifdef ASSERT_ON

// ============================================================
// uart_fifo assertions
// ============================================================
module uart_fifo_sva #(
    parameter DATA_WIDTH = 8,
    parameter DEPTH      = 16,
    localparam CNT_WIDTH = $clog2(DEPTH) + 1
)(
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire                  wr_en,
    input  wire [DATA_WIDTH-1:0] wr_data,
    input  wire                  rd_en,
    input  wire [DATA_WIDTH-1:0] rd_data,
    input  wire                  fifo_full,
    input  wire                  fifo_empty,
    input  wire                  fifo_almost_full,
    input  wire [CNT_WIDTH-1:0]  fifo_count,
    input  wire                  fifo_overflow,
    input  wire                  fifo_underflow,
    input  wire [CNT_WIDTH-1:0]  almost_full_thresh
);

    // Full and empty are mutually exclusive
    property p_full_empty_mutex;
        @(posedge clk) disable iff (!rst_n)
        fifo_full |-> !fifo_empty;
    endproperty
    assert_full_empty_mutex: assert property (p_full_empty_mutex);

    // Empty implies not full
    property p_empty_not_full;
        @(posedge clk) disable iff (!rst_n)
        fifo_empty |-> !fifo_full;
    endproperty
    assert_empty_not_full: assert property (p_empty_not_full);

    // Count never exceeds DEPTH
    property p_count_range;
        @(posedge clk) disable iff (!rst_n)
        fifo_count <= DEPTH;
    endproperty
    assert_count_range: assert property (p_count_range);

    // Overflow: write when full
    property p_overflow;
        @(posedge clk) disable iff (!rst_n)
        (fifo_full && wr_en) |=> fifo_overflow;
    endproperty
    assert_overflow: assert property (p_overflow);

    // Underflow: read when empty
    property p_underflow;
        @(posedge clk) disable iff (!rst_n)
        (fifo_empty && rd_en) |=> fifo_underflow;
    endproperty
    assert_underflow: assert property (p_underflow);

endmodule

// ============================================================
// uart_baud_gen assertions
// ============================================================
module uart_baud_gen_sva (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [15:0] baud_div_int,
    input  wire [3:0]  baud_div_frac,
    input  wire        oversample_sel,
    input  wire        baud_tick_16x,
    input  wire        baud_tick_8x,
    input  wire        baud_tick
);

    // baud_tick_16x is single-cycle pulse
    property p_tick_16x_pulse;
        @(posedge clk) disable iff (!rst_n)
        baud_tick_16x |=> !baud_tick_16x;
    endproperty
    assert_tick_16x_pulse: assert property (p_tick_16x_pulse);

    // baud_tick_8x is single-cycle pulse
    property p_tick_8x_pulse;
        @(posedge clk) disable iff (!rst_n)
        baud_tick_8x |=> !baud_tick_8x;
    endproperty
    assert_tick_8x_pulse: assert property (p_tick_8x_pulse);

    // baud_tick is single-cycle pulse
    property p_tick_pulse;
        @(posedge clk) disable iff (!rst_n)
        baud_tick |=> !baud_tick;
    endproperty
    assert_tick_pulse: assert property (p_tick_pulse);

endmodule

// ============================================================
// uart_tx assertions
// ============================================================
module uart_tx_sva (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       baud_tick_16x,
    input  wire [7:0] tx_data,
    input  wire       tx_fifo_empty,
    input  wire       tx_fifo_rd_en,
    input  wire [1:0] data_bits,
    input  wire       stop_bits,
    input  wire       parity_en,
    input  wire       parity_even,
    input  wire       cts_n,
    input  wire       loopback_en,
    input  wire       tx_pause,
    input  wire       txd,
    input  wire       tx_done,
    input  wire       tx_busy
);

    // Idle state: txd is high
    // (state_cur is internal, use tx_busy as proxy)
    property p_idle_txd_high;
        @(posedge clk) disable iff (!rst_n)
        !tx_busy |-> txd;
    endproperty
    assert_idle_txd_high: assert property (p_idle_txd_high);

    // tx_done is single-cycle pulse
    property p_tx_done_pulse;
        @(posedge clk) disable iff (!rst_n)
        tx_done |=> !tx_done;
    endproperty
    assert_tx_done_pulse: assert property (p_tx_done_pulse);

    // tx_fifo_rd_en is single-cycle pulse
    property p_rd_en_pulse;
        @(posedge clk) disable iff (!rst_n)
        tx_fifo_rd_en |=> !tx_fifo_rd_en;
    endproperty
    assert_rd_en_pulse: assert property (p_rd_en_pulse);

endmodule

// ============================================================
// uart_rx assertions
// ============================================================
module uart_rx_sva (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        baud_tick_16x,
    input  wire        baud_tick_8x,
    input  wire        rxd,
    input  wire        rx_fifo_full,
    input  wire        rx_fifo_wr_en,
    input  wire [10:0] rx_data,
    input  wire        rx_valid,
    input  wire [1:0]  data_bits,
    input  wire        stop_bits,
    input  wire        parity_en,
    input  wire        parity_even,
    input  wire        oversample_sel,
    input  wire        loopback_en,
    input  wire        frame_err,
    input  wire        parity_err,
    input  wire        break_detect,
    input  wire        rx_busy,
    input  wire        rts_n
);

    // rx_valid is single-cycle pulse
    property p_rx_valid_pulse;
        @(posedge clk) disable iff (!rst_n)
        rx_valid |=> !rx_valid;
    endproperty
    assert_rx_valid_pulse: assert property (p_rx_valid_pulse);

    // rx_fifo_wr_en is single-cycle pulse
    property p_wr_en_pulse;
        @(posedge clk) disable iff (!rst_n)
        rx_fifo_wr_en |=> !rx_fifo_wr_en;
    endproperty
    assert_wr_en_pulse: assert property (p_wr_en_pulse);

endmodule

// ============================================================
// uart_reg_mod assertions
// ============================================================
module uart_reg_mod_sva #(
    parameter ADDR_WIDTH = 5,
    parameter DATA_WIDTH = 32
)(
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire [ADDR_WIDTH-1:0] paddr,
    input  wire                  psel,
    input  wire                  penable,
    input  wire                  pwrite,
    input  wire [DATA_WIDTH-1:0] pwdata,
    input  wire [DATA_WIDTH-1:0] prdata,
    input  wire                  pready,
    input  wire                  pslverr,
    input  wire                  dlab,
    input  wire [3:0]            ier,
    input  wire [7:0]            lcr
);

    // APB handshake: PREADY is always 1
    property p_pready_always_one;
        @(posedge clk) disable iff (!rst_n)
        psel && penable |-> pready;
    endproperty
    assert_pready_always_one: assert property (p_pready_always_one);

    // DLAB follows LCR[7]
    property p_dlab_follows_lcr7;
        @(posedge clk) disable iff (!rst_n)
        dlab == lcr[7];
    endproperty
    assert_dlab_follows_lcr7: assert property (p_dlab_follows_lcr7);

endmodule

// ============================================================
// uart_ctrl assertions
// ============================================================
module uart_ctrl_sva (
    input  wire       clk,
    input  wire       rst_n,
    input  wire [3:0] ier,
    input  wire       tx_done,
    input  wire       tx_fifo_empty,
    input  wire       rx_valid,
    input  wire       rx_fifo_full,
    input  wire       rx_fifo_almost_full,
    input  wire       frame_err,
    input  wire       parity_err,
    input  wire       break_detect,
    input  wire       overrun_err,
    input  wire       cts_n,
    input  wire       loopback_en,
    input  wire       flow_ctrl_en,
    input  wire [1:0] fcr_rx_trig,
    input  wire       tx_busy,
    input  wire       rx_busy,
    input  wire       irq,
    input  wire [3:0] iir,
    input  wire [7:0] lsr,
    input  wire [7:0] msr,
    input  wire       rts_n_out,
    input  wire       tx_pause
);

    // IRQ follows any_int
    property p_irq_any_int;
        @(posedge clk) disable iff (!rst_n)
        (overrun_err && ier[2]) || (break_detect && ier[2]) ||
        (frame_err && ier[2]) || (parity_err && ier[2]) ||
        (rx_valid && ier[0]) || (tx_fifo_empty && ier[1])
        |-> irq;
    endproperty
    assert_irq_any_int: assert property (p_irq_any_int);

    // RTS flow control: when enabled, rts_n reflects FIFO almost full
    property p_rts_flow_ctrl;
        @(posedge clk) disable iff (!rst_n)
        flow_ctrl_en |=> (rts_n_out == !rx_fifo_almost_full);
    endproperty
    assert_rts_flow_ctrl: assert property (p_rts_flow_ctrl);

endmodule

`endif // ASSERT_ON
