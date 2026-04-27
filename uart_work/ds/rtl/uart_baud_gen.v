// Module: uart_baud_gen
// Function: Fractional Baud Rate Generator (16-bit integer + 4-bit fraction)
// Author: AI Agent
// Date: 2026-04-27
// Revision: v1.0

// Ref: Arch-Sec-5.1 Data path - Baud rate generation
// Ref: Arch-Sec-5.2 Control logic - tick generation

module uart_baud_gen (
    input  wire        clk,
    input  wire        rst_n,
    // Configuration
    input  wire [15:0] baud_div_int,     // Integer divider (DLL+DLH)
    input  wire [3:0]  baud_div_frac,    // Fractional divider (FCR_EXT[3:0])
    input  wire        oversample_sel,   // 0=16x, 1=8x
    // Tick outputs
    output reg         baud_tick_16x,    // 16x baud rate tick (single-cycle pulse)
    output reg         baud_tick_8x,     // 8x baud rate tick (single-cycle pulse)
    output reg         baud_tick         // 1x baud rate tick (single-cycle pulse)
);

// ----------------------------------------------------------
// Internal signals
// ----------------------------------------------------------
// Ref: Arch-Sec-5.1 Integer divider counter + fractional accumulator
reg [15:0] div_cnt;
reg [3:0]  frac_acc;

// Ref: Arch-Sec-5.2 Tick counters for 1x generation
reg [3:0]  tick_16x_cnt;   // Counts 16x ticks to generate 1x
reg        tick_8x_toggle; // Toggle for 8x generation

// Tick 16x enable: counter reaches zero
wire tick_16x_en = (div_cnt == 16'd0);

// ----------------------------------------------------------
// Integer divider with fractional accumulation
// Ref: Arch-Sec-5.1 Data path - fractional divider
// When frac_acc overflows (>=16), div_cnt reloads with +1
// ----------------------------------------------------------
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        div_cnt  <= 16'd0;
        frac_acc <= 4'd0;
    end else if (tick_16x_en) begin
        // Fractional accumulation
        if ({1'b0, frac_acc} + {1'b0, baud_div_frac} >= 5'd16) begin
            frac_acc <= frac_acc + baud_div_frac - 4'd16;
            div_cnt  <= baud_div_int + 16'd1;  // Extra count on overflow
        end else begin
            frac_acc <= frac_acc + baud_div_frac;
            div_cnt  <= baud_div_int;
        end
    end else begin
        div_cnt <= div_cnt - 16'd1;
    end
end

// ----------------------------------------------------------
// baud_tick_16x generation (single-cycle pulse)
// Ref: Arch-Sec-5.2 Tick generation - 16x
// ----------------------------------------------------------
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        baud_tick_16x <= 1'b0;
    end else begin
        baud_tick_16x <= tick_16x_en;
    end
end

// ----------------------------------------------------------
// baud_tick_8x generation
// Ref: Arch-Sec-5.2 Tick generation - 8x
// Every 2nd tick_16x produces one tick_8x pulse
// ----------------------------------------------------------
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        tick_8x_toggle <= 1'b0;
        baud_tick_8x   <= 1'b0;
    end else if (tick_16x_en) begin
        tick_8x_toggle <= ~tick_8x_toggle;
        baud_tick_8x   <= ~tick_8x_toggle;  // Pulse when toggle goes from 0->1
    end else begin
        baud_tick_8x <= 1'b0;
    end
end

// ----------------------------------------------------------
// baud_tick generation (1x baud rate)
// Ref: Arch-Sec-5.2 Tick generation - 1x
// 16x mode: every 16 tick_16x -> 1 baud_tick
// 8x mode:  every 8  tick_8x  -> 1 baud_tick
// ----------------------------------------------------------
wire tick_8x_en = oversample_sel ?
                  (tick_16x_en && ~tick_8x_toggle) :  // 8x mode: every other 16x
                  tick_16x_en;                          // 16x mode: every 16x

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        tick_16x_cnt <= 4'd0;
        baud_tick    <= 1'b0;
    end else if (tick_8x_en) begin
        if (tick_16x_cnt == (oversample_sel ? 4'd7 : 4'd15)) begin
            tick_16x_cnt <= 4'd0;
            baud_tick    <= 1'b1;
        end else begin
            tick_16x_cnt <= tick_16x_cnt + 4'd1;
            baud_tick    <= 1'b0;
        end
    end else begin
        baud_tick <= 1'b0;
    end
end

endmodule
