// Passive test-1 timing. One observer and one clock give both modules the
// same timeline. No request queues or latency statistics are collected.
`timescale 1ns/1ps
module tb_dimc_test1_timing
  import dimc_package::*;
(
  input wire logic clk_i, rst_ni, enable_i, start_request_i,
  input wire dimc_config_t config_i,
  input wire logic [1:0] weight_load_i, load_macro_i, active_macro_i, result_pop_i,
  input wire logic [1:0][7:0] weight_section_i,
  input wire logic [1:0][31:0] compute_tile_i,
  input wire logic [1:0][2:0] compute_vector_i,
  input wire logic [1:0][1:0] feature_load_i, compute_issue_i,
  input wire logic [1:0][1:0][1:0] feature_section_i,
  input wire logic [1:0][1:0][6:0] compute_row_i,
  input wire logic [1:0] output_grant_i,
  output bit done_o
);
  bit running=0;
  longint unsigned cycle=0;
  longint unsigned weight_start[2], vector_start[2][2];
  longint unsigned compute_start[2][8], tile_start[2], output_start[2];
  int vector_number[2][2], vector_tile[2][2];
  int results[2], output_beats[2], weights_done[2], vectors_loaded[2], vectors_done[2], tiles_done[2];
  int macro_id, tile_id, vector_id, expected_products, expected_output_beats;
  string events, timeline="", cycle_report;
  integer report_file, report_first_char, report_run;
  string report_path;
  longint unsigned total_macs;

  // Append all events first, then print one shared heading for this edge.
  task automatic event_line(input string line_);
    events={events,"  ",line_,"\n"};
  endtask

  always @(posedge clk_i) begin
    if (!rst_ni || !enable_i) begin
      running=0; cycle=0; done_o=0; timeline="";
      for (int m=0;m<2;m++) begin
        results[m]=0; output_beats[m]=0; weights_done[m]=0;
        vectors_loaded[m]=0; vectors_done[m]=0; tiles_done[m]=0;
        for (int a=0;a<2;a++) vector_number[m][a]=0;
      end
    end else begin
      events="";
      if (start_request_i && !running && !done_o) begin
        running=1; cycle=0;
        event_line("Shared start request accepted; elapsed-cycle origin = 0.");
      end else if (running) cycle++;

      if (running) begin
        for (int m=0;m<2;m++) begin
          if (weight_load_i[m]) begin
            macro_id=2*m+int'(load_macro_i[m])+1;
            // The loader prepares the next product in the other macro.
            tile_id=compute_tile_i[m]+int'(load_macro_i[m]!=active_macro_i[m]);
            if (weight_section_i[m]==0) begin
              weight_start[m]=cycle;
              event_line($sformatf("Module %0d macro %0d tile-product %0d: WEIGHT LOAD START",
                                   m+1,macro_id,tile_id));
              if (load_macro_i[m]!=active_macro_i[m])
                event_line($sformatf("OVERLAP: module %0d macro %0d loads weights for tile-product %0d while macro %0d computes tile-product %0d",
                                     m+1,macro_id,tile_id,2*m+int'(active_macro_i[m])+1,compute_tile_i[m]));
            end
            if (weight_section_i[m]==127) begin
              weights_done[m]++;
              event_line($sformatf("Module %0d macro %0d tile-product %0d: WEIGHT LOAD END [%0d..%0d], elapsed=%0d cycles (128 macro writes)",
                                   m+1,macro_id,tile_id,weight_start[m],cycle,cycle-weight_start[m]));
            end
          end
          for (int a=0;a<2;a++) begin
            macro_id=2*m+a+1;
            if (feature_load_i[m][a]) begin
              if (feature_section_i[m][a]==0) begin
                vector_start[m][a]=cycle;
                vector_tile[m][a]=compute_tile_i[m]+int'(a!=int'(active_macro_i[m]));
                event_line($sformatf("Module %0d macro %0d tile-product %0d vector %0d: VECTOR LOAD START",
                                     m+1,macro_id,vector_tile[m][a],vector_number[m][a]+1));
              end
              if (feature_section_i[m][a]==3) begin
                vectors_loaded[m]++;
                event_line($sformatf("Module %0d macro %0d tile-product %0d vector %0d: VECTOR LOAD END [%0d..%0d], elapsed=%0d cycles (4 feature writes)",
                                     m+1,macro_id,vector_tile[m][a],vector_number[m][a]+1,
                                     vector_start[m][a],cycle,cycle-vector_start[m][a]));
                vector_number[m][a]=(vector_number[m][a]+1)%8;
              end
            end
            if (compute_issue_i[m][a] && compute_row_i[m][a]==0) begin
              vector_id=int'(compute_vector_i[m]);
              compute_start[m][vector_id]=cycle;
              event_line($sformatf("Module %0d macro %0d tile-product %0d vector %0d: COMPUTE START",
                                   m+1,macro_id,compute_tile_i[m],vector_id+1));
              if (vector_id==0) begin
                tile_start[m]=cycle;
                event_line($sformatf("Module %0d macro %0d tile-product %0d: TILE COMPUTE START",
                                     m+1,macro_id,compute_tile_i[m]));
              end
            end
          end
          if (result_pop_i[m]) begin
            macro_id=2*m+int'(active_macro_i[m])+1;
            vector_id=results[m]/32;
            results[m]++;
            if (results[m]%32==0) begin
              vectors_done[m]++;
              event_line($sformatf("Module %0d macro %0d tile-product %0d vector %0d: COMPUTE END [%0d..%0d], elapsed=%0d cycles",
                                   m+1,macro_id,compute_tile_i[m],vector_id+1,
                                   compute_start[m][vector_id],cycle,cycle-compute_start[m][vector_id]));
            end
            if (results[m]==256) begin
              results[m]=0; tiles_done[m]++;
              event_line($sformatf("Module %0d macro %0d tile-product %0d: TILE COMPUTE END [%0d..%0d], elapsed=%0d cycles (256 results accumulated)",
                                   m+1,macro_id,compute_tile_i[m],tile_start[m],cycle,cycle-tile_start[m]));
            end
          end
          if (output_grant_i[m]) begin
            tile_id=output_beats[m]/32+1;
            if (output_beats[m]%32==0) begin
              output_start[m]=cycle;
              event_line($sformatf("Module %0d output-tile %0d: OUTPUT WRITE START",m+1,tile_id));
            end
            output_beats[m]++;
            if (output_beats[m]%32==0)
              event_line($sformatf("Module %0d output-tile %0d: OUTPUT WRITE END [%0d..%0d], elapsed=%0d cycles (32 memory grants)",
                                   m+1,tile_id,output_start[m],cycle,cycle-output_start[m]));
          end
        end

        expected_products=(config_i.weight_rows/32)*(config_i.weight_cols/128)*(config_i.input_cols/8);
        expected_output_beats=(config_i.weight_rows/32)*(config_i.input_cols/8)*32;
        if (expected_output_beats>0 && output_beats[0]==expected_output_beats &&
            output_beats[1]==expected_output_beats) begin
          for (int m=0;m<2;m++) begin
            assert (weights_done[m]==expected_products && tiles_done[m]==expected_products &&
                    vectors_loaded[m]==expected_products*8 && vectors_done[m]==expected_products*8)
              else $fatal(1,"[TEST1 TIMING] Incomplete timing events in module %0d",m+1);
            event_line($sformatf("Module %0d totals: %0d weight loads, %0d vectors loaded/computed, %0d tile-products, %0d output tiles written",
                                 m+1,weights_done[m],vectors_done[m],tiles_done[m],output_beats[m]/32));
          end
          event_line($sformatf("BOTH MODULES: ALL OUTPUTS WRITTEN; start-request acceptance -> final write grant = %0d elapsed cycles",cycle));
          running=0; done_o=1;
        end
      end
      if (events!="") begin
        cycle_report=$sformatf("[TEST1 TIMING] CYCLE %0d -- events in this group happen on the SAME clock edge:\n%s",cycle,events);
        $display("%s",cycle_report);
        timeline={timeline,cycle_report,"\n"};
        // Write after completion so the measured total appears before the timeline.
        if (done_o) begin
          // Include dimensions and choose a free run number to preserve past reports.
          report_run=0;
          do begin
            report_run++;
            report_path=$sformatf("sim/test1_timing_kernel_%0dx%0d_input_%0dx%0d_run_%0d.txt",
                                  config_i.weight_rows,config_i.weight_cols,
                                  config_i.input_rows,config_i.input_cols,report_run);
            // Append/read creates a missing file without a simulator warning.
            report_file=$fopen(report_path,"a+");
            if (!report_file) $fatal(1,"Cannot open %s",report_path);
            void'($fseek(report_file,0,0));
            report_first_char=$fgetc(report_file);
            if (report_first_char!=-1) $fclose(report_file);
          end while (report_first_char!=-1);
          void'($fseek(report_file,0,0));
          $fdisplay(report_file,"TEST 1 TIMING REPORT");
          $fdisplay(report_file,"Total elapsed cycles: %0d (start-request acceptance to both modules' final output writes)",cycle);
          $fdisplay(report_file,"Matrix sizes for each module (rows x columns):");
          for (int m=0;m<2;m++) begin
            $fdisplay(report_file,"  Module %0d:",m+1);
            $fdisplay(report_file,"    Input:  %0d x %0d = %0d elements; 8 bits/element; %0d bits total",
                      config_i.input_rows,config_i.input_cols,
                      config_i.input_rows*config_i.input_cols,config_i.input_rows*config_i.input_cols*8);
            $fdisplay(report_file,"    Kernel: %0d x %0d = %0d elements; 8 bits/element; %0d bits total",
                      config_i.weight_rows,config_i.weight_cols,
                      config_i.weight_rows*config_i.weight_cols,config_i.weight_rows*config_i.weight_cols*8);
            $fdisplay(report_file,"    Output: %0d x %0d = %0d elements; 32 bits/element; %0d bits total",
                      config_i.weight_rows,config_i.input_cols,
                      config_i.weight_rows*config_i.input_cols,config_i.weight_rows*config_i.input_cols*32);
          end
          // Each output element takes weight_cols MACs; count both modules.
          total_macs=64'd2*config_i.weight_rows*config_i.weight_cols*config_i.input_cols;
          $fdisplay(report_file,"\nCombined throughput (both modules, including loading and output writes):");
          $fdisplay(report_file,"  Total MACs = 2 modules x %0d output rows x %0d inner elements x %0d output columns = %0d MACs",
                    config_i.weight_rows,config_i.weight_cols,config_i.input_cols,total_macs);
          $fdisplay(report_file,"  Total MACs/cycle = %0d MACs / %0d elapsed cycles = %0.4f MACs/cycle",
                    total_macs,cycle,real'(total_macs)/real'(cycle));
          $fdisplay(report_file,"\n%s",timeline);
          $fclose(report_file);
          $display("[TEST1 TIMING] Report: %s",report_path);
        end
      end
    end
  end
endmodule
