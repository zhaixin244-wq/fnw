# UART SDC Constraints
# Target: 50 MHz (20ns period)
# Author: AI Agent
# Date: 2026-04-27

# ============================================================
# Clock definition
# ============================================================
create_clock -name clk -period 20 [get_ports clk]

# ============================================================
# Input delays (relative to clk)
# ============================================================
# APB interface
set_input_delay -clock clk -max 5 [get_ports {paddr[*]}]
set_input_delay -clock clk -max 5 [get_ports {psel}]
set_input_delay -clock clk -max 5 [get_ports {penable}]
set_input_delay -clock clk -max 5 [get_ports {pwrite}]
set_input_delay -clock clk -max 5 [get_ports {pwdata[*]}]

# UART external signals
set_input_delay -clock clk -max 5 [get_ports {rxd}]
set_input_delay -clock clk -max 5 [get_ports {cts_n}]

# ============================================================
# Output delays (relative to clk)
# ============================================================
# APB interface
set_output_delay -clock clk -max 5 [get_ports {prdata[*]}]
set_output_delay -clock clk -max 5 [get_ports {pready}]
set_output_delay -clock clk -max 5 [get_ports {pslverr}]

# UART external signals
set_output_delay -clock clk -max 5 [get_ports {txd}]
set_output_delay -clock clk -max 5 [get_ports {rts_n}]
set_output_delay -clock clk -max 5 [get_ports {irq}]

# ============================================================
# False paths
# ============================================================
# Asynchronous reset
set_false_path -from [get_ports {rst_n}]

# rxd is asynchronous input (handled by 2-stage synchronizer)
set_false_path -from [get_ports {rxd}]

# cts_n is asynchronous input (edge detected in uart_ctrl)
set_false_path -from [get_ports {cts_n}]
