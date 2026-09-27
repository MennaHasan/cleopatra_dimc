# Batch regressions must propagate assertion failures to make/the caller.
onerror {quit -code 1}
onbreak {quit -code 1}
set BreakOnAssertion 2
run -all
quit -code 0
