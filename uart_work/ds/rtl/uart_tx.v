// Module: uart_tx
// Function: UART Transmitter - FSM + Shift Register
// Author: AI Agent
// Date: 2026-04-27
// Revision: v1.0

// Ref: Arch-Sec-5.3 uart_tx microarchitecture
// Ref: Arch-Sec-5.1 Data path
// Ref: Arch-Sec-5.3 State machine design

module uart_tx (
    input  wire       clk,
    input  wire       rst_n,
    // Baud rate clock
    input  wire       baud_tick_16x,
    // TX FIFO interface
    input  wire [7:0] tx_data,
    input  wire       tx_fifo_empty,
    output reg        tx_fifo_rd_en,
    // Frame configuration
    input  wire [1:0] data_bits,     // 00=5, 01=6, 10=7, 11=8
    input  wire       stop_bits,     // 0=1 bit, 1=2 bits
    input  wire       parity_en,
    input  wire       parity_even,   // 0=odd, 1=even
    // Flow control
    input  wire       cts_n,
    input  wire       loopback_en,
    input  wire       tx_pause,
    // Output
    output reg        txd,
    output reg        tx_done,
    output reg        tx_busy
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
// Internal registers
// ----------------------------------------------------------
reg [4:0]  state_cur;
reg [4:0]  state_nxt;
reg [11:0] shift_reg;      // Frame shift register (max 12 bits)
reg [3:0]  bit_cnt;         // Data bit counter
reg [3:0]  tick_cnt;        // baud_tick_16x counter (0~15)
reg [1:0]  stop_bit_cnt;    // Stop bit counter
reg        parity_val;      // Calculated parity value

// ----------------------------------------------------------
// Parity calculation
// Ref: Arch-Sec-5.1 Frame assembly - parity
// Even parity: XOR of all data bits
// Odd parity:  Inversion of even parity
// ----------------------------------------------------------
wire parity_calc  = ^tx_data;
wire parity_value = parity_even ? parity_calc : ~parity_calc;

// Actual data bit count: data_bits + 5
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
            if (!tx_fifo_empty && !tx_pause) begin
                state_nxt = S_START;
            end else begin
                state_nxt = S_IDLE;
            end
        end

        S_START: begin
            if (tick_cnt == 4'd15 && baud_tick_16x) begin
                state_nxt = S_DATA;
            end else begin
                state_nxt = S_START;
            end
        end

        S_DATA: begin
            if (tick_cnt == 4'd15 && baud_tick_16x) begin
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
            if (tick_cnt == 4'd15 && baud_tick_16x) begin
                state_nxt = S_STOP;
            end else begin
                state_nxt = S_PARITY;
            end
        end

        S_STOP: begin
            if (tick_cnt == 4'd15 && baud_tick_16x) begin
                if (stop_bit_cnt == (stop_bits ? 2'd1 : 2'd0)) begin
                    state_nxt = S_IDLE;
                end else begin
                    state_nxt = S_STOP;
                end
            end else begin
                state_nxt = S_STOP;
            end
        end

        default: state_nxt = S_IDLE;  // Ref: Arch-Sec-5.3 Illegal state recovery
    endcase
end

// ----------------------------------------------------------
// Data path - Datapath and control outputs
// Ref: Arch-Sec-5.1 Data path
// ----------------------------------------------------------
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        shift_reg     <= 12'd0;
        bit_cnt       <= 4'd0;
        tick_cnt      <= 4'd0;
        stop_bit_cnt  <= 2'd0;
        txd           <= 1'b1;       // Idle high
        tx_fifo_rd_en <= 1'b0;
        tx_done       <= 1'b0;
        tx_busy       <= 1'b0;
        parity_val    <= 1'b0;
    end else begin
        // Default: clear single-cycle pulses
        tx_fifo_rd_en <= 1'b0;
        tx_done       <= 1'b0;

        case (state_cur)
            // ------------------------------------------------
            S_IDLE: begin
                txd     <= 1'b1;  // Idle: txd high
                tx_busy <= 1'b0;
                if (!tx_fifo_empty && !tx_pause) begin
                    tx_fifo_rd_en <= 1'b1;  // Read from FIFO
                    tx_busy       <= 1'b1;
                end
            end

            // ------------------------------------------------
            S_START: begin
                txd <= 1'b0;  // Start bit: txd low
                if (baud_tick_16x) begin
                    if (tick_cnt == 4'd15) begin
                        tick_cnt   <= 4'd0;
                        bit_cnt    <= 4'd0;
                        parity_val <= parity_value;
                        // Assemble frame: {stop, parity?, data, start}
                        if (parity_en) begin
                            shift_reg <= {3'b000, parity_value, tx_data, 1'b0};
                        end else begin
                            shift_reg <= {4'b0000, tx_data, 1'b0};
                        end
                    end else begin
                        tick_cnt <= tick_cnt + 4'd1;
                    end
                end
            end

            // ------------------------------------------------
            S_DATA: begin
                txd <= shift_reg[0];  // LSB first
                if (baud_tick_16x) begin
                    if (tick_cnt == 4'd15) begin
                        tick_cnt  <= 4'd0;
                        shift_reg <= {1'b0, shift_reg[11:1]};  // Right shift
                        bit_cnt   <= bit_cnt + 4'd1;
                    end else begin
                        tick_cnt <= tick_cnt + 4'd1;
                    end
                end
            end

            // ------------------------------------------------
            S_PARITY: begin
                txd <= shift_reg[0];  // Parity bit
                if (baud_tick_16x) begin
                    if (tick_cnt == 4'd15) begin
                        tick_cnt      <= 4'd0;
                        stop_bit_cnt  <= 2'd0;
                    end else begin
                        tick_cnt <= tick_cnt + 4'd1;
                    end
                end
            end

            // ------------------------------------------------
            S_STOP: begin
                txd <= 1'b1;  // Stop bit: txd high
                if (baud_tick_16x) begin
                    if (tick_cnt == 4'd15) begin
                        tick_cnt <= 4'd0;
                        if (stop_bit_cnt == (stop_bits ? 2'd1 : 2'd0)) begin
                            tx_done <= 1'b1;  // Transmission complete
                        end else begin
                            stop_bit_cnt <= stop_bit_cnt + 2'd1;
                        end
                    end else begin
                        tick_cnt <= tick_cnt + 4'd1;
                    end
                end
            end

            // ------------------------------------------------
            default: begin
                txd <= 1'b1;  // Ref: Arch-Sec-5.3 Illegal state recovery
            end
        endcase
    end
end

endmodule
