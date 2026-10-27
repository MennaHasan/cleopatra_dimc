// Passive Test 1 timing observer for one DIMC module with two ping-pong macros.
`timescale 1ns/1ps
module tb_dimc_test1_timing
  import dimc_package::*;
(
  input wire logic clk_i, rst_ni, enable_i, start_request_i, verified_i,
  input wire dimc_config_t config_i,
  input wire logic weight_load_i, load_macro_i, active_macro_i,
  input wire logic input_push_i,
  input wire logic [7:0] weight_section_i,
  input wire logic [31:0] compute_tile_i,
  input wire logic [2:0] compute_vector_i,
  input wire logic [1:0] feature_load_i, compute_issue_i,
  input wire logic [1:0][1:0] feature_section_i,
  input wire logic [1:0][6:0] compute_row_i,
  input wire logic result_push_i, output_grant_i,
  output bit done_o
);
  bit running=0, report_written=0;
  longint unsigned cycle=0;
  longint unsigned weight_start[2], vector_start[2][2], fifo_vector_start[2];
  longint unsigned compute_start[2][8], tile_start[2], output_start;
  int fifo_input_beats, results, output_beats;
  int vector_number[2], vector_tile[2];
  int weights_done[2], vectors_loaded[2], vectors_done[2], tiles_done[2];
  int macro_id, tile_id, vector_id, expected_products, expected_output_beats;
  int expected_macro_products[2];
  string events, timeline="", cycle_report;
  integer report_file, report_first_char, report_run;
  string report_path, report_dir="timing_analysis";
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
      fifo_input_beats=0; results=0; output_beats=0;
      for (int a=0;a<2;a++) begin
        weights_done[a]=0; vectors_loaded[a]=0; vectors_done[a]=0; tiles_done[a]=0;
        vector_number[a]=0; vector_tile[a]=0;
      end
    end else begin
      events="";
      if (start_request_i && !running && !done_o) begin
        running=1; cycle=0;
        event_line("Module 1 start request accepted; elapsed-cycle origin = 0.");
      end else if (running) cycle++;

      if (running) begin
        // The input FIFO is shared. Each 32 accepted 256-bit beats are the
        // eight vectors for one K/L/Q product, directed to alternating macros.
        if (input_push_i) begin
          tile_id=fifo_input_beats/32+1;
          macro_id=((tile_id-1)%2)+1;
          vector_id=(fifo_input_beats%32)/4+1;
          if (fifo_input_beats%4==0) begin
            fifo_vector_start[macro_id-1]=cycle;
            event_line($sformatf("Module 1 macro %0d tile-product %0d vector %0d: VECTOR LOAD TO FIFO START",
                                 macro_id,tile_id,vector_id));
          end
          fifo_input_beats++;
          if (fifo_input_beats%4==0)
            event_line($sformatf("Module 1 macro %0d tile-product %0d vector %0d: VECTOR LOAD TO FIFO END [%0d..%0d], elapsed=%0d cycles (4 input FIFO writes)",
                                 macro_id,tile_id,vector_id,fifo_vector_start[macro_id-1],cycle,
                                 cycle-fifo_vector_start[macro_id-1]));
        end

        if (weight_load_i) begin
          macro_id=int'(load_macro_i)+1;
          tile_id=compute_tile_i+int'(load_macro_i!=active_macro_i);
          if (weight_section_i==0) begin
            weight_start[macro_id-1]=cycle;
            event_line($sformatf("Module 1 macro %0d tile-product %0d: WEIGHT LOAD START",
                                 macro_id,tile_id));
            if (load_macro_i!=active_macro_i)
              event_line($sformatf("OVERLAP: macro %0d loads weights for tile-product %0d while macro %0d computes tile-product %0d",
                                   macro_id,tile_id,int'(active_macro_i)+1,compute_tile_i));
          end
          if (weight_section_i==127) begin
            weights_done[macro_id-1]++;
            event_line($sformatf("Module 1 macro %0d tile-product %0d: WEIGHT LOAD END [%0d..%0d], elapsed=%0d cycles (128 macro writes)",
                                 macro_id,tile_id,weight_start[macro_id-1],cycle,
                                 cycle-weight_start[macro_id-1]));
          end
        end

        for (int a=0;a<2;a++) begin
          macro_id=a+1;
          if (feature_load_i[a]) begin
            if (feature_section_i[a]==0) begin
              vector_start[a][0]=cycle;
              vector_tile[a]=compute_tile_i+int'(a!=int'(active_macro_i));
              event_line($sformatf("Module 1 macro %0d tile-product %0d vector %0d: VECTOR LOAD TO MACRO START",
                                   macro_id,vector_tile[a],vector_number[a]+1));
            end
            if (feature_section_i[a]==3) begin
              vectors_loaded[a]++;
              event_line($sformatf("Module 1 macro %0d tile-product %0d vector %0d: VECTOR LOAD TO MACRO END [%0d..%0d], elapsed=%0d cycles (4 feature writes)",
                                   macro_id,vector_tile[a],vector_number[a]+1,
                                   vector_start[a][0],cycle,cycle-vector_start[a][0]));
              vector_number[a]=(vector_number[a]+1)%8;
            end
          end
          if (compute_issue_i[a] && compute_row_i[a]==0) begin
            vector_id=int'(compute_vector_i);
            compute_start[a][vector_id]=cycle;
            event_line($sformatf("Module 1 macro %0d tile-product %0d vector %0d: COMPUTE START",
                                 macro_id,compute_tile_i,vector_id+1));
            if (vector_id==0) begin
              tile_start[a]=cycle;
              event_line($sformatf("Module 1 macro %0d tile-product %0d: TILE COMPUTE START",
                                   macro_id,compute_tile_i));
            end
          end
        end

        // Count macro output-FIFO writes, as in main's timing observer.
        // Every 32 results complete a vector; 256 complete a tile-product.
        if (result_push_i) begin
          macro_id=int'(active_macro_i)+1;
          vector_id=results/32;
          results++;
          if (results%32==0) begin
            vectors_done[macro_id-1]++;
            event_line($sformatf("Module 1 macro %0d tile-product %0d vector %0d: COMPUTE END [%0d..%0d], elapsed=%0d cycles (32 results written to output FIFO)",
                                 macro_id,compute_tile_i,vector_id+1,
                                 compute_start[macro_id-1][vector_id],cycle,
                                 cycle-compute_start[macro_id-1][vector_id]));
          end
          if (results==256) begin
            results=0; tiles_done[macro_id-1]++;
            event_line($sformatf("Module 1 macro %0d tile-product %0d: TILE COMPUTE END [%0d..%0d], elapsed=%0d cycles (256 results written to output FIFO)",
                                 macro_id,compute_tile_i,tile_start[macro_id-1],cycle,
                                 cycle-tile_start[macro_id-1]));
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
        expected_macro_products[0]=(expected_products+1)/2;
        expected_macro_products[1]=expected_products/2;
        if (expected_output_beats>0 && output_beats==expected_output_beats) begin
          assert (fifo_input_beats==expected_products*32)
            else $fatal(1,"[TEST1 TIMING] Incomplete shared input FIFO events");
          for (int a=0;a<2;a++) begin
            assert (weights_done[a]==expected_macro_products[a] &&
                    tiles_done[a]==expected_macro_products[a] &&
                    vectors_loaded[a]==expected_macro_products[a]*8 &&
                    vectors_done[a]==expected_macro_products[a]*8)
              else $fatal(1,"[TEST1 TIMING] Incomplete events for macro %0d",a+1);
            event_line($sformatf("Module 1 macro %0d totals: %0d weight loads, %0d vectors loaded/computed, %0d tile-products",
                                 a+1,weights_done[a],vectors_done[a],tiles_done[a]));
          end
          event_line($sformatf("Module 1 totals: %0d input vectors streamed and %0d output tiles written",
                               fifo_input_beats/4,output_beats/32));
          event_line($sformatf("MODULE 1: ALL OUTPUTS WRITTEN; start-request acceptance -> final write grant = %0d elapsed cycles",cycle));
          running=0; done_o=1;
        end
      end

      if (events!="") begin
        cycle_report=$sformatf("[TEST1 TIMING] CYCLE %0d\n%s",cycle,events);
        if (!quiet_timing) $display("%s",cycle_report);
        if (!summary_timing) timeline={timeline,cycle_report,"\n"};
      end

      if (done_o && verified_i && !report_written) begin
        precision_bits=1 << config_i.mode;
        inner_elements=64'(config_i.weight_cols)*(8/precision_bits);
        total_macs=64'(config_i.weight_rows)*inner_elements*64'(config_i.input_cols);
        assert (minimum_macs==0 || total_macs>=64'(minimum_macs)*cycle)
          else $fatal(1,"Throughput regression: %0f MACs/cycle, required %0d",
                      real'(total_macs)/cycle,minimum_macs);

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
        $fdisplay(report_file,"Numerical verification: PASS (one module, two macros)");
        if (summary_timing) $fdisplay(report_file,"Summary only; cycle timeline disabled for this run.");
        $fdisplay(report_file,"Total elapsed cycles: %0d (start-request acceptance to final output write)",cycle);
        $fdisplay(report_file,"Precision used: %0d bits",precision_bits);
        $fdisplay(report_file,"Signing used: weights=%s; inputs=%s",
                  (config_i.mode==2'b11 && config_i.sign_8b[0]) ? "signed" : "unsigned",
                  (config_i.mode==2'b11 && config_i.sign_8b[1]) ? "signed" : "unsigned");
        $fdisplay(report_file,"Packed inner dimension: %0d bytes per row/vector",config_i.weight_cols);
        $fdisplay(report_file,"Macro weights region: 32 rows x 1024 bits (each macro)");
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
        $fdisplay(report_file,"    Weight matrix tiles (combined capacity): %0d bits / 65536 bits = %0.4f tiles",
                  matrix_weight_bits,real'(matrix_weight_bits)/65536.0);
        $fdisplay(report_file,"\nThroughput for module 1 (both macros, including loading and output writes):");
        $fdisplay(report_file,"  Total MACs = %0d output rows x %0d inner elements x %0d output columns = %0d MACs",
                  config_i.weight_rows,inner_elements,config_i.input_cols,total_macs);
        $fdisplay(report_file,"  Total MACs/cycle = %0d MACs / %0d elapsed cycles = %0.4f MACs/cycle",
                  total_macs,cycle,real'(total_macs)/real'(cycle));
        $fdisplay(report_file,"  Macro 1 completed %0d tile-products; macro 2 completed %0d tile-products",
                  tiles_done[0],tiles_done[1]);
        $fdisplay(report_file,"\n%s",timeline);
        $fclose(report_file);
        report_written=1;
        $display("[TEST1 TIMING] Report: %s",report_path);
      end
    end
  end
endmodule
