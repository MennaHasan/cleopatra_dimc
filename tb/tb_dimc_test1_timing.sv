// Passive Test 1 timing observer for the single-macro DIMC top.
`timescale 1ns/1ps
module tb_dimc_test1_timing
  import dimc_package::*;
(
  input wire logic clk_i, rst_ni, enable_i, start_request_i, verified_i,
  input wire dimc_config_t config_i,
  input wire logic weight_load_i, input_push_i, feature_load_i,
  input wire logic compute_issue_i, result_push_i, output_grant_i,
  input wire logic [7:0] weight_section_i,
  input wire logic [31:0] compute_tile_i,
  input wire logic [2:0] compute_vector_i,
  input wire logic [1:0] feature_section_i,
  input wire logic [6:0] compute_row_i,
  output bit done_o
);
  bit running=0, report_written=0;
  longint unsigned cycle=0;
  longint unsigned weight_start, vector_start, fifo_vector_start;
  longint unsigned compute_start[8], tile_start, output_start;
  int fifo_input_beats, results, output_beats, weights_done;
  int vectors_loaded, vectors_done, tiles_done;
  int tile_id, vector_id, expected_products, expected_output_beats;
  string events, timeline="", cycle_report;
  integer report_file, report_first_char, report_run;
  string report_path;
  string report_dir="timing_analysis";
  longint unsigned total_macs, inner_elements, matrix_weight_bits;
  int precision_bits;
  int minimum_macs=0;
  bit quiet_timing=0, summary_timing=0;

  initial begin
    void'($value$plusargs("TIMING_REPORT_DIR=%s",report_dir));
    void'($value$plusargs("MIN_MACS_PER_CYCLE=%d",minimum_macs));
    summary_timing=$test$plusargs("SUMMARY_TIMING");
    quiet_timing=$test$plusargs("QUIET_TIMING") || summary_timing;
  end

  task automatic event_line(input string line_);
    events={events,"  ",line_,"\n"};
  endtask

  always @(posedge clk_i) begin
    if (!rst_ni || !enable_i) begin
      running=0; cycle=0; done_o=0; report_written=0; timeline="";
      fifo_input_beats=0; results=0; output_beats=0; weights_done=0;
      vectors_loaded=0; vectors_done=0; tiles_done=0;
    end else begin
      events="";
      if (start_request_i && !running && !done_o) begin
        running=1; cycle=0;
        event_line("Start request accepted; elapsed-cycle origin = 0.");
      end else if (running) cycle++;

      if (running) begin
        // Four accepted memory responses fill one 1024-bit input vector.
        if (input_push_i) begin
          tile_id=compute_tile_i;
          vector_id=(fifo_input_beats%32)/4+1;
          if (fifo_input_beats%4==0) begin
            fifo_vector_start=cycle;
            event_line($sformatf("Module 1 macro 1 tile-product %0d vector %0d: VECTOR LOAD TO FIFO START",
                                 tile_id,vector_id));
          end
          fifo_input_beats++;
          if (fifo_input_beats%4==0)
            event_line($sformatf("Module 1 macro 1 tile-product %0d vector %0d: VECTOR LOAD TO FIFO END [%0d..%0d], elapsed=%0d cycles (4 input FIFO writes)",
                                 tile_id,vector_id,fifo_vector_start,cycle,cycle-fifo_vector_start));
        end

        if (weight_load_i) begin
          tile_id=compute_tile_i;
          if (weight_section_i==0) begin
            weight_start=cycle;
            event_line($sformatf("Module 1 macro 1 tile-product %0d: WEIGHT LOAD START",tile_id));
          end
          if (weight_section_i==127) begin
            weights_done++;
            event_line($sformatf("Module 1 macro 1 tile-product %0d: WEIGHT LOAD END [%0d..%0d], elapsed=%0d cycles (128 macro writes)",
                                 tile_id,weight_start,cycle,cycle-weight_start));
          end
        end

        if (feature_load_i) begin
          tile_id=compute_tile_i;
          vector_id=int'(compute_vector_i)+1;
          if (feature_section_i==0) begin
            vector_start=cycle;
            event_line($sformatf("Module 1 macro 1 tile-product %0d vector %0d: VECTOR LOAD TO MACRO START",
                                 tile_id,vector_id));
          end
          if (feature_section_i==3) begin
            vectors_loaded++;
            event_line($sformatf("Module 1 macro 1 tile-product %0d vector %0d: VECTOR LOAD TO MACRO END [%0d..%0d], elapsed=%0d cycles (4 feature writes)",
                                 tile_id,vector_id,vector_start,cycle,cycle-vector_start));
          end
        end

        if (compute_issue_i && compute_row_i==0) begin
          vector_id=int'(compute_vector_i);
          compute_start[vector_id]=cycle;
          tile_id=compute_tile_i;
          event_line($sformatf("Module 1 macro 1 tile-product %0d vector %0d: COMPUTE START",
                               tile_id,vector_id+1));
          if (vector_id==0) begin
            tile_start=cycle;
            event_line($sformatf("Module 1 macro 1 tile-product %0d: TILE COMPUTE START",tile_id));
          end
        end

        // The accumulator captures 32 rows per vector. Eight vectors complete
        // one K/L/Q tile-product on this design's single macro.
        if (result_push_i) begin
          vector_id=results/32;
          tile_id=compute_tile_i;
          results++;
          if (results%32==0) begin
            vectors_done++;
            event_line($sformatf("Module 1 macro 1 tile-product %0d vector %0d: COMPUTE END [%0d..%0d], elapsed=%0d cycles (32 results captured)",
                                 tile_id,vector_id+1,compute_start[vector_id],cycle,
                                 cycle-compute_start[vector_id]));
          end
          if (results==256) begin
            results=0; tiles_done++;
            event_line($sformatf("Module 1 macro 1 tile-product %0d: TILE COMPUTE END [%0d..%0d], elapsed=%0d cycles (256 results captured)",
                                 tile_id,tile_start,cycle,cycle-tile_start));
          end
        end

        if (output_grant_i) begin
          tile_id=output_beats/32+1;
          if (output_beats%32==0) begin
            output_start=cycle;
            event_line($sformatf("Module 1 output-tile %0d: OUTPUT WRITE START",tile_id));
          end
          output_beats++;
          if (output_beats%32==0)
            event_line($sformatf("Module 1 output-tile %0d: OUTPUT WRITE END [%0d..%0d], elapsed=%0d cycles (32 memory grants)",
                                 tile_id,output_start,cycle,cycle-output_start));
        end

        expected_products=(config_i.weight_rows/32)*(config_i.weight_cols/128)*
                          (config_i.input_cols/8);
        expected_output_beats=(config_i.weight_rows/32)*(config_i.input_cols/8)*32;
        if (expected_output_beats>0 && output_beats==expected_output_beats) begin
          assert (fifo_input_beats==expected_products*32 &&
                  weights_done==expected_products && tiles_done==expected_products &&
                  vectors_loaded==expected_products*8 && vectors_done==expected_products*8)
            else $fatal(1,"[TEST1 TIMING] Incomplete single-macro timing events");
          event_line($sformatf("Module 1 totals: %0d weight loads, %0d vectors loaded/computed, %0d tile-products, %0d output tiles written",
                               weights_done,vectors_done,tiles_done,output_beats/32));
          event_line($sformatf("MODULE 1: ALL OUTPUTS WRITTEN; start-request acceptance -> final write grant = %0d elapsed cycles",cycle));
          running=0; done_o=1;
        end
      end

      if (events!="") begin
        cycle_report=$sformatf("[TEST1 TIMING] CYCLE %0d\n%s",cycle,events);
        if (!quiet_timing) $display("%s",cycle_report);
        if (!summary_timing) timeline={timeline,cycle_report,"\n"};
      end

      // Publish only after the testbench has checked the result memory and
      // completion status, matching the timing flow used on main.
      if (done_o && verified_i && !report_written) begin
        precision_bits=1 << config_i.mode;
        inner_elements=64'(config_i.weight_cols)*(8/precision_bits);
        total_macs=64'(config_i.weight_rows)*inner_elements*64'(config_i.input_cols);
        assert (minimum_macs==0 || total_macs>=64'(minimum_macs)*cycle)
          else $fatal(1,"Throughput regression: %0f MACs/cycle, required %0d",
                      real'(total_macs)/cycle,minimum_macs);

        // Preserve earlier reports by selecting the first unused report number.
        report_run=0;
        do begin
          report_run++;
          report_path=$sformatf("%s/timing_report_%0d.txt",report_dir,report_run);
          report_file=$fopen(report_path,"a+");
          if (!report_file) $fatal(1,"Cannot open %s",report_path);
          void'($fseek(report_file,0,0));
          report_first_char=$fgetc(report_file);
          if (report_first_char!=-1) $fclose(report_file);
        end while (report_first_char!=-1);
        void'($fseek(report_file,0,0));

        $fdisplay(report_file,"TEST 1 TIMING REPORT");
        $fdisplay(report_file,"Numerical verification: PASS (single macro)");
        if (summary_timing) $fdisplay(report_file,"Summary only; cycle timeline disabled for this run.");
        $fdisplay(report_file,"Total elapsed cycles: %0d (start-request acceptance to final output write)",cycle);
        $fdisplay(report_file,"Precision used: %0d bits",precision_bits);
        $fdisplay(report_file,"Signing used: weights=%s; inputs=%s",
                  (config_i.mode==2'b11 && config_i.sign_8b[0]) ? "signed" : "unsigned",
                  (config_i.mode==2'b11 && config_i.sign_8b[1]) ? "signed" : "unsigned");
        $fdisplay(report_file,"Packed inner dimension: %0d bytes per row/vector",config_i.weight_cols);
        $fdisplay(report_file,"Macro weights region: 32 rows x 1024 bits");
        $fdisplay(report_file,"Macro input vector region: 1024 bits");
        $fdisplay(report_file,"Matrix sizes for module 1 (rows x columns):");
        $fdisplay(report_file,"  Module 1:");
        $fdisplay(report_file,"    Input:  %0d x %0d = %0d elements; %0d bits/element",
                  inner_elements,config_i.input_cols,inner_elements*config_i.input_cols,precision_bits);
        $fdisplay(report_file,"    Kernel: %0d x %0d = %0d elements; %0d bits/element",
                  config_i.weight_rows,inner_elements,64'(config_i.weight_rows)*inner_elements,precision_bits);
        $fdisplay(report_file,"    Output: %0d x %0d = %0d elements; 32 bits/element",
                  config_i.weight_rows,config_i.input_cols,config_i.weight_rows*config_i.input_cols);
        matrix_weight_bits=64'(config_i.weight_rows)*64'(config_i.weight_cols)*8;
        $fdisplay(report_file,"    Weight matrix tiles (capacity): %0d bits / 32768 bits = %0.4f tiles",
                  matrix_weight_bits,real'(matrix_weight_bits)/32768.0);
        $fdisplay(report_file,"\nThroughput for the single macro (including loading and output writes):");
        $fdisplay(report_file,"  Total MACs = %0d output rows x %0d inner elements x %0d output columns = %0d MACs",
                  config_i.weight_rows,inner_elements,config_i.input_cols,total_macs);
        $fdisplay(report_file,"  Total MACs/cycle = %0d MACs / %0d elapsed cycles = %0.4f MACs/cycle",
                  total_macs,cycle,real'(total_macs)/real'(cycle));
        $fdisplay(report_file,"\n%s",timeline);
        $fclose(report_file);
        report_written=1;
        $display("[TEST1 TIMING] Report: %s",report_path);
      end
    end
  end
endmodule
