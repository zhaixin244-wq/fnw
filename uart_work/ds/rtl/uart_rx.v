// Module: uart_rx
// Function: UART Receiver - FSM + Oversampling + 2-stage synchronizer
// Author: AI Agent
// Date: 2026-04-27
// Revision: v1.0

// Ref: Arch-Sec-5.4 uart_rx microarchitecture
// Ref: Arch-Sec-5.1 Data path
// Ref: Arch-Sec-5.3 State machine design
// Ref: Arch-Sec-7 CDC handling

module uart_rx (
    input  wire        clk,
    input  wire        rst_n,
    // Baud rate clocks
    input  wire        baud_tick_16x,
    input  wire        baud_tick_8x,
    // Serial input
    input  wire        rxd,
    // RX FIFO interface
    input  wire        rx_fifo_full,
    output reg         rx_fifo_wr_en,
    output reg  [10:0] rx_data,        // {break, frame_err, parity, data[7:0]}
    output reg         rx_valid,
    // Frame configuration
    input  wire [1:0]  data_bits,      // 00=5, 01=6, 10=7, 11=8
    input  wire        stop_bits,      // 0=1 bit, 1=2 bits
    input  wire        parity_en,
    input  wire        parity_even,    // 0=odd, 1=even
    input  wire        oversample_sel, // 0=16x, 1=8x
    input  wire        loopback_en,
    // Error flags
    output reg         frame_err,
    output reg         parity_err,
    output reg         break_detect,
    output reg         rx_busy,
    // Flow control
    output reg         rts_n
);

// ----------------------------------------------------------
// State definition - One-hot encoding
// Ref: Arch-Sec-5.3 State definition
// ----------------------------------------------------------
localparam [4:0] S_IDLE   = 5'b00001,
                 S_START  = 5'b00010,
                 S_DATA   = 5'b00100,
                 S_PARITY = 5'b01000,
                 S_STOP   = 5'b10000;

// ----------------------------------------------------------
// CDC: 2-stage synchronizer for rxd
// Ref: Arch-Sec-7 CDC handling - rxd async input
// ----------------------------------------------------------
reg rxd_sync1;
reg rxd_sync2;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        rxd_sync1 <= 1'b1;
        rxd_sync2 <= 1'b1;
    end else begin
        rxd_sync1 <= rxd;
        rxd_sync2 <= rxd_sync1;
    end
end

// ----------------------------------------------------------
// Internal registers
// ----------------------------------------------------------
reg [4:0]  state_cur;
reg [4:0]  state_nxt;
reg [3:0]  sample_cnt;     // Oversampling counter
reg [2:0]  sample_bits;    // 3-point sample storage
reg [3:0]  bit_cnt;        // Data bit counter
reg [7:0]  shift_reg;      // Data shift register
reg        parity_rx;      // Received parity bit
reg        parity_calc;    // Calculated parity

// ----------------------------------------------------------
// Oversampling clock selection
// Ref: Arch-Sec-5.1 Data path - oversampling
// ----------------------------------------------------------
wire baud_tick_os = oversample_sel ? baud_tick_8x : baud_tick_16x;

// Sample limit: 16x -> 15, 8x -> 7
wire [3:0] sample_limit = oversample_sel ? 4'd7 : 4'd15;

// Middle 3 sample points for majority voting
// 16x: tick 7, 8, 9; 8x: tick 3, 4, 5
wire [3:0] sample_mid0 = oversample_sel ? 4'd3 : 4'd7;
wire [3:0] sample_mid1 = oversample_sel ? 4'd4 : 4'd8;
wire [3:0] sample_mid2 = oversample_sel ? 4'd5 : 4'd9;

// ----------------------------------------------------------
// Majority voting: ≥2 out of 3 samples are 1 ->判决为1
// Ref: Arch-Sec-5.1 Data path - majority voting
// ----------------------------------------------------------
wire sample_majority = (sample_bits[0] & sample_bits[1]) |
                       (sample_bits[0] & sample_bits[2]) |
                       (sample_bits[1] & sample_bits[2]);

// Actual data bit count
wire [3:0] data_bits_actual = {2'b00, data_bits} + 4'd5;

// ----------------------------------------------------------
// FSM - Sequential logic (state register)
// Ref: Arch-Sec-5.3 State machine - segment 1
// ----------------------------------------------------------
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state_cur <= S_IDLE;
    end else begin
        state_cur <= state_nxt;
    end
end

// ----------------------------------------------------------
// FSM - Combinational logic (next state)
// Ref: Arch-Sec-5.3 State machine - segment 2
// ----------------------------------------------------------
always @(*) begin
    state_nxt = S_IDLE;  // Default: illegal state recovery
    case (state_cur)
        S_IDLE: begin
            if (rxd_sync2 == 1'b0) begin
                state_nxt = S_START;  // Falling edge detected
            end else begin
                state_nxt = S_IDLE;
            end
        end

        S_START: begin
            if (baud_tick_os && sample_cnt == sample_limit) begin
                state_nxt = sample_majority ? S_DATA : S_IDLE;
            end else begin
                state_nxt = S_START;
            end
        end

        S_DATA: begin
            if (baud_tick_os && sample_cnt == sample_limit) begin
                if (bit_cnt == data_bits_actual - 4'd1) begin
                    state_nxt = parity_en ? S_PARITY : S_STOP;
                end else begin
                    state_nxt = S_DATA;
                end
            end else begin
                state_nxt = S_DATA;
            end
        end

        S_PARITY: begin
            if (baud_tick_os && sample_cnt == sample_limit) begin
                state_nxt = S_STOP;
            end else begin
                state_nxt = S_PARITY;
            end
        end

        S_STOP: begin
            if (baud_tick_os && sample_cnt == sample_limit) begin
                state_nxt = S_IDLE;
            end else begin
                state_nxt = S_STOP;
            end
        end

        default: state_nxt = S_IDLE;  // Ref: Arch-Sec-5.3 Illegal state recovery
    endcase
end

// ----------------------------------------------------------
// Data path
// Ref: Arch-Sec-5.1 Data path
// ----------------------------------------------------------
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        sample_cnt    <= 4'd0;
        sample_bits   <= 3'b000;
        bit_cnt       <= 4'd0;
        shift_reg     <= 8'd0;
        parity_rx     <= 1'b0;
        parity_calc   <= 1'b0;
        rx_data       <= 11'd0;
        rx_fifo_wr_en <= 1'b0;
        rx_valid      <= 1'b0;
        frame_err     <= 1'b0;
        parity_err    <= 1'b0;
        break_detect  <= 1'b0;
        rx_busy       <= 1'b0;
        rts_n         <= 1'b1;  // Default: not requesting
    end else begin
        // Default: clear single-cycle pulses
        rx_fifo_wr_en <= 1'b0;
        rx_valid      <= 1'b0;

        // ------------------------------------------------
        // Sample counter
        // Ref: Arch-Sec-5.1 Oversampling counter
        // ------------------------------------------------
        if (baud_tick_os) begin
            if (sample_cnt == sample_limit) begin
                sample_cnt <= 4'd0;
            end else begin
                sample_cnt <= sample_cnt + 4'd1;
            end
        end

        // ------------------------------------------------
        // 3-point majority sampling
        // Ref: Arch-Sec-5.1 Majority voting
        // ------------------------------------------------
        if (baud_tick_os) begin
            if (sample_cnt == sample_mid0) begin
                sample_bits[0] <= rxd_sync2;
            end
            if (sample_cnt == sample_mid1) begin
                sample_bits[1] <= rxd_sync2;
            end
            if (sample_cnt == sample_mid2) begin
                sample_bits[2] <= rxd_sync2;
            end
        end

        // ------------------------------------------------
        // State-dependent datapath
        // ------------------------------------------------
        case (state_cur)
            S_IDLE: begin
                rx_busy <= 1'b0;
                if (rxd_sync2 == 1'b0) begin
                    rx_busy    <= 1'b1;
                    sample_cnt <= 4'd0;
                end
            end

            S_START: begin
                if (baud_tick_os && sample_cnt == sample_limit) begin
                    if (sample_majority) begin
                        // Valid start bit: initialize for data reception
                        bit_cnt     <= 4'd0;
                        parity_calc <= parity_even ? 1'b0 : 1'b1;
                    end
                end
            end

            S_DATA: begin
                if (baud_tick_os && sample_cnt == sample_limit) begin
                    shift_reg[bit_cnt] <= sample_majority;
                    parity_calc        <= parity_calc ^ sample_majority;
                    bit_cnt            <= bit_cnt + 4'd1;
                end
            end

            S_PARITY: begin
                if (baud_tick_os && sample_cnt == sample_limit) begin
                    parity_rx <= sample_majority;
                end
            end

            S_STOP: begin
                if (baud_tick_os && sample_cnt == sample_limit) begin
                    // Error detection (registered for status output)
                    frame_err    <= !sample_majority;
                    parity_err   <= parity_en && (parity_rx != parity_calc);
                    break_detect <= (shift_reg == 8'd0) && !sample_majority;
                    // Write to RX FIFO
                    // Format: {break_detect, frame_err, parity_rx, data[7:0]}
                    // Use combinational break_detect for same-cycle consistency
                    // Ref: Major#4 fix - break_detect in rx_data must match FIFO write timing
                    rx_data       <= {(shift_reg == 8'd0) && !sample_majority,
                                     !sample_majority,
                                     parity_rx,
                                     shift_reg};
                    rx_fifo_wr_en <= !rx_fifo_full;
                    rx_valid      <= 1'b1;
                end
            end

            default: ;  // Ref: Arch-Sec-5.3 Illegal state recovery
        endcase

        // ------------------------------------------------
        // RTS flow control
        // Ref: Arch-Sec-5.2 Flow control - RTS
        // ------------------------------------------------
        rts_n <= !rx_fifo_full;
    end
end

endmodule
