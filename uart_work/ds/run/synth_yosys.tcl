# UART Yosys Synthesis Script
# Usage: yosys synth_yosys.tcl
# Author: AI Agent
# Date: 2026-04-27

# ============================================================
# Configuration
# ============================================================
set rtl_dir "../rtl"
set work_dir "./synth_work"
set top_module "uart_top"

# Create work directory
file mkdir $work_dir

# ============================================================
# Read RTL files
# ============================================================
puts "=========================================="
puts "UART RTL Synthesis (Yosys)"
puts "=========================================="

# Read all RTL files
read_verilog ${rtl_dir}/uart_fifo.v
read_verilog ${rtl_dir}/uart_baud_gen.v
read_verilog ${rtl_dir}/uart_tx.v
read_verilog ${rtl_dir}/uart_rx.v
read_verilog ${rtl_dir}/uart_reg_mod.v
read_verilog ${rtl_dir}/uart_ctrl.v
read_verilog ${rtl_dir}/uart_top.v

# ============================================================
# Elaborate top module
# ============================================================
puts "\n[INFO] Elaborating top module: ${top_module}"
hierarchy -top ${top_module}

# ============================================================
# Synthesis
# ============================================================
puts "\n[INFO] Running synthesis..."
synth -top ${top_module}

# ============================================================
# Optimization
# ============================================================
puts "\n[INFO] Running optimization..."
opt
flatten

# ============================================================
# Statistics
# ============================================================
puts "\n[INFO] Synthesis statistics:"
stat

# ============================================================
# Output
# ============================================================
# Write synthesized netlist
write_verilog ${work_dir}/${top_module}_synth.v

# Write BLIF (for further analysis)
write_blif ${work_dir}/${top_module}_synth.blif

# Write JSON (for visualization)
write_json ${work_dir}/${top_module}_synth.json

puts "\n=========================================="
puts "Synthesis Complete"
puts "  Output directory: ${work_dir}"
puts "  Netlist: ${top_module}_synth.v"
puts "  BLIF:    ${top_module}_synth.blif"
puts "  JSON:    ${top_module}_synth.json"
puts "=========================================="
