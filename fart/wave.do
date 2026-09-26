onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /multicycle_tb/reset
add wave -noupdate /multicycle_tb/clock
add wave -noupdate -divider {Hex Display}
add wave -noupdate -radix hexadecimal /multicycle_tb/DUT/HEX_display/in0
add wave -noupdate -radix hexadecimal /multicycle_tb/DUT/HEX_display/in1
add wave -noupdate -radix hexadecimal /multicycle_tb/DUT/HEX_display/in2
add wave -noupdate -radix hexadecimal /multicycle_tb/DUT/HEX_display/in3
add wave -noupdate -divider {multicycle.v inputs}
add wave -noupdate /multicycle_tb/KEY
add wave -noupdate /multicycle_tb/SW
add wave -noupdate -divider {multicycle.v outputs}
add wave -noupdate /multicycle_tb/LEDG
add wave -noupdate /multicycle_tb/LEDR
add wave -noupdate /multicycle_tb/HEX0
add wave -noupdate /multicycle_tb/HEX1
add wave -noupdate /multicycle_tb/HEX2
add wave -noupdate /multicycle_tb/HEX3
add wave -noupdate /multicycle_tb/HEX4
add wave -noupdate /multicycle_tb/HEX5
add wave -noupdate /multicycle_tb/HEX6
add wave -noupdate /multicycle_tb/HEX7
add wave -position 2  sim:/multicycle_tb/DUT/DataMem/data
add wave -position 3  sim:/multicycle_tb/DUT/Control/state
add wave -position 4  sim:/multicycle_tb/DUT/Control/instr
add wave -position 5  sim:/multicycle_tb/DUT/counter/counterOut
add wave -position 6  sim:/multicycle_tb/DUT/IR
add wave -position 7  sim:/multicycle_tb/DUT/VRF_block/vr0_0
add wave -position 8  sim:/multicycle_tb/DUT/VRF_block/vr0_1
add wave -position 9  sim:/multicycle_tb/DUT/VRF_block/vr0_2
add wave -position 10  sim:/multicycle_tb/DUT/VRF_block/vr0_3
add wave -position 11  sim:/multicycle_tb/DUT/VRF_block/vr1_0
add wave -position 12  sim:/multicycle_tb/DUT/VRF_block/vr1_1
add wave -position 13  sim:/multicycle_tb/DUT/VRF_block/vr1_2
add wave -position 14  sim:/multicycle_tb/DUT/VRF_block/vr1_3
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {2500 ns} 0}
configure wave -namecolwidth 227
configure wave -valuecolwidth 57
configure wave -justifyvalue left
configure wave -signalnamewidth 0
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1000
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns
update
WaveRestoreZoom {0 ps} {2500 ns}
