# $finish and $fatal both stop Questa; return the explicit suite result.
onerror {quit -code 1}
onfinish stop
onbreak {
  if {[catch {examine -radix binary sim:/tb_dimc_top/tests_passed} result]} {
    quit -code 1
  }
  if {$result eq "1"} {
    quit -code 0
  } else {
    quit -code 1
  }
}
quietly set ::BreakOnAssertion 2
run -all
quit -code 1
