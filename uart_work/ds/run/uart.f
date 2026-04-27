// UART RTL File List
// Usage: verilator -f uart.f --lint-only -Wall
//        iverilog -f uart.f -o uart_sim

// RTL source files (in compilation order)
../rtl/uart_fifo.v
../rtl/uart_baud_gen.v
../rtl/uart_tx.v
../rtl/uart_rx.v
../rtl/uart_reg_mod.v
../rtl/uart_ctrl.v
../rtl/uart_top.v

// SVA assertions (for formal/simulation only)
// ../rtl/uart_sva.sv
