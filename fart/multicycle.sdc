# External 50 MHz oscillator
create_clock -name CLOCK_50 -period 20.000 [get_ports {CLOCK_50}]

# 50 MHz / 500,000 = 100 Hz
create_generated_clock -name cpu_clock \
    -source [get_ports {CLOCK_50}] \
    -divide_by 500000 \
    [get_registers {*|cpu_clock}]

derive_clock_uncertainty