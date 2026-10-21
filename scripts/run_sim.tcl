# Only explicit completion of all selected checks is a successful run.
onerror {quit -code 1}
onfinish stop
onbreak {
  foreach top {tb_dimc tb_dimc_dual tb_cleopatra tb_dimc_datapath tb_double_buffering} {
    if {![catch {examine -radix binary sim:/$top/tests_passed} result]} {
      if {$result eq "1"} {quit -code 0}
      quit -code 1
    }
  }
  quit -code 1
}
set BreakOnAssertion 2
run -all
quit -code 1
