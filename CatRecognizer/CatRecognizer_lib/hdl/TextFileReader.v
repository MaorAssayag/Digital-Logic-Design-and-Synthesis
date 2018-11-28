//
// Verilog Module CatRecognizer_lib.TextFileReader
//
// Created:
//          by - MaorA.UNKNOWN (DESKTOP-8K7FTQN)
//          at - 10:57:07 13/11/2018
//
// using Mentor Graphics HDL Designer(TM) 2012.1 (Build 6)
//

`resetall
`timescale 1ns/10ps
module TextFileReader_TB;

integer   file_inputs; // var to see if file exists
integer   scan_inputs; // captured text handler

reg [5:0] captured_inputs;  ///Actual text obtained from inputs.txt lines
initial 
begin

  // TEXT FILE inputs
  file_inputs = $fopen("C:/Users/MaorA/Desktop/CatRecognizer/CatRecognizer/CatRecognizer_lib/InputFiles/WeightsTest.txt", "r"); //Opening text file (inputs)
  if (file_inputs == 0) begin               //If inputs file is not found
      $display("data_file handle was NULL");
      $finish;
  end
end

always @(* )
begin
   if (!$feof(file_inputs)) 
   begin
      scan_inputs = $fscanf(file_inputs, "%d\n", captured_inputs);//Inputs Line text
      $display ("Line :[inputs: %d]",captured_inputs);// Displaying each line at the simulation monitor 
   end

   else
   begin
    $finish;
    $fclose(file_inputs);
   end
end
endmodule