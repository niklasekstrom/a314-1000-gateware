create_clock -period 7.5000 PLL_CLKOUT0
create_clock -period 282.00 DRAM_RAS_n
set_clock_groups -exclusive -group {PLL_CLKOUT0} -group {DRAM_RAS_n}
