vlog -sv RTL/*.sv

vsim -voptargs=+acc work.restoringDividerFinal_tb

add wave sim:/restoringDividerFinal_tb/dut/*

run -all