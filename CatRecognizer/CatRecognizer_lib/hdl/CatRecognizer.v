// ====================================================================
//	File Name:		CatRecognizer.v
//	Description:	
//
// Parameters :   Amba_Word = 24/32
//                Amba_Addr_Depth = 12/13/14
//                WeightPrecision = 5/8/16
//
//	Date:			28/11/2018
//	Designers:		Maor Assayag, Refael Shetrit
// ====================================================================

module CatRecognizer (clk,rst,PENABLE,PSEL,PWRITE,PADDR,PWDATA,PRDATA,CatRecOut);                 // Output result
  
   // PARAMETERS
   parameter Amba_Word = 24;
   parameter Amba_Addr_Depth = 12;
   parameter WeightPrecision = 5; 
  
   // LOCAL PARAMETERS
   localparam pixelNumber = 12288;
   localparam PixelWidth  = 8;
   localparam resultWidth = (14 + Amba_Word + WeightPrecision);
   localparam iteration   = 4096;
   localparam WeightRowWidth = 3 * WeightPrecision;
    
   // DEFINE INPUTS VARS
   input wire clk;                        // system clock
   input wire rst;                        // Reset active low
   input wire PENABLE;                    // APB Bus Enable/clk
   input wire PSEL;                       // APB Bus Select
   input wire PWRITE;                     // APB Bus Write
   input wire [Amba_Addr_Depth-1:0] PADDR;// APB Address Bus
   input wire [Amba_Word-1:0] PWDATA;     // APB Write Data Bus
   
   // DEFINE OUTPUT VARS
   output wire[Amba_Word-1:0] PRDATA; // APB Read Data Bus
   output wire CatRecOut;             // CatRecognizer result
  
   // LOCAL vars
   reg doneFlag;
   reg doneAddingBias;
   reg doneIteration;
   reg reset;
   reg signed [15:0] bias [2:0];
   reg [13:0] iterator;
   reg signed [resultWidth - 1: 0] currentResult;
   reg [(Amba_Addr_Depth -1):0] currentAddress;
   reg CatResultOut;
  
   //APB regs
   reg [1:0] APB_control;
   reg [Amba_Word-1:0] APB_WriteData;
   reg [(Amba_Addr_Depth -1):0] APB_address;
   wire [Amba_Word-1:0] APB_ReadData;
   wire [Amba_Word-1:0] Start_work_reg;
  
   //WeightsBank regs
   reg [1:0] Weights_control;
   wire [WeightRowWidth-1:0] Weights_ReadData;
   reg [(Amba_Addr_Depth -1):0] Weights_address;
  
   reg [(Amba_Word-1):0] PixelData_temp;
   reg [(WeightRowWidth-1):0] WeightsData_temp;
   wire signed [(2*(WeightPrecision+PixelWidth)):0] Result_1;
   wire signed [(2*(WeightPrecision+PixelWidth)):0] Result_2;
   wire signed [(2*(WeightPrecision+PixelWidth)):0] Result_3;
  
   // MODULES
   APB #(
    .Amba_Word(Amba_Word),
    .Amba_Addr_Depth(Amba_Addr_Depth)) APB_Bank(
    .clock (clk),
    .reset(reset),
    .control (APB_control),
    .address (APB_address),
    .WriteData (APB_WriteData),
    .ReadData (APB_ReadData),
    .Start_work_reg(Start_work_reg));
        
   WeighstBank #(
    .Amba_Addr_Depth(Amba_Addr_Depth),
    .WeightPrecision(WeightPrecision),
    .WeightRowWidth(WeightRowWidth)) Weights_Bank(
    .clock (clk),
    .reset(reset),
    .control (Weights_control),
    .address (Weights_address),
    .WriteData (Weights_WriteData),
    .ReadData (Weights_ReadData));
     
   Neuron #(
    .PixelWidth(PixelWidth),
    .WeightWidth(WeightPrecision)) Neuron_1 (
    .p({1'b0,PixelData_temp[PixelWidth-1 :0]}),
    .w(WeightsData_temp[WeightPrecision -1 :0]),
    .result(Result_1));

  Neuron #(
    .PixelWidth(PixelWidth),
    .WeightWidth(WeightPrecision)) Neuron_2 (
    .p({1'b0,PixelData_temp[(2*PixelWidth)-1 : PixelWidth]}),
    .w(WeightsData_temp[(2*WeightPrecision)-1 : WeightPrecision]),
    .result(Result_2));

  Neuron #(
    .PixelWidth(PixelWidth),
    .WeightWidth(WeightPrecision)) Neuron_3 (
    .p({1'b0,PixelData_temp[(3*PixelWidth)-1 :(2*PixelWidth)]}),
    .w(WeightsData_temp[(3*WeightPrecision)-1 :(2*WeightPrecision)]),
    .result(Result_3));
            
   always @(posedge clk) begin : CatRecognizerOperation
     if (rst)
        begin
        // Intialize all local reg's
        reset          <= 1'b1;
        doneFlag       <= 1'b0;
        CatResultOut   <= 1'bz;
        doneAddingBias <= 1'b0;
        doneIteration  <= 1'b0;
        APB_control    <= 2'b00;
        currentResult  <= {(resultWidth){1'b0}};
        WeightsData_temp <= {(WeightRowWidth){1'b0}};  
        APB_WriteData    <= {(Amba_Word){1'b0}};
        PixelData_temp   <= {(Amba_Word){1'b0}};
        APB_address      <= {(Amba_Addr_Depth){1'b0}};
        Weights_address  <= {(Amba_Addr_Depth){1'b0}};
        currentAddress   <= {{(Amba_Addr_Depth -1){1'b0}}, 1'b1};
        bias[0]<= 16'b0000000000000000; // bias = 0
        bias[1]<= 16'b1111111111111111; // bias = -1
        bias[2]<= 16'b1111111001110110; // bias = -394
    end
    else if (PSEL) 
       begin
        reset <= 1'b0; // Next STATE is ENABLE
        if (PENABLE & PWRITE)
          begin
          // Write data to APB 
          APB_WriteData <= PWDATA;
          APB_address <= PADDR;
          APB_control <= 2'b01; // WRITE
        end 
        else if ((Start_work_reg == 'b1) & (doneFlag == 0)) 
          begin
          if (doneIteration == 0) 
            begin      
            // Compute sigma of 12,288 multiplication
            //READ data
            APB_address <= currentAddress;
            APB_control <= 2'b10; 
            Weights_address <= currentAddress-1; // weights start from address 0
            Weights_control <=2'b10;
            
            //Update current pixelData and WeightsData
            PixelData_temp <= APB_ReadData;
            WeightsData_temp <= Weights_ReadData;
             
            // Accumulate current Result - all signed, avoid accumulate 'z' or 'x'
            if (PixelData_temp >= 0) 
              begin
              currentResult <= currentResult + Result_1 + Result_2 + Result_3;
            end  
            
            // Check if we done with the accumulation
            if (currentAddress == iteration + 3)
              begin
              doneIteration <= 1'b1;
            end
                 
            // Iterat
            currentAddress <= currentAddress + {{(Amba_Addr_Depth -1){1'b0}},1'b1};  
          end 
          else if (doneAddingBias == 1'b0)
            begin
            case (WeightPrecision)
              5'b00101 : currentResult <= currentResult + bias[0];// Add bias
              5'b01000 : currentResult <= currentResult + bias[1]; // Add bias
              5'b10000 : currentResult <= currentResult + bias[2]; // Add bias
              default  : currentResult <= currentResult + bias[0]; // Add bias
            endcase 
            doneAddingBias <= 1'b1; // stop entering compute sigma/adding bias "loop"
          end 
          else 
            begin 
            case (currentResult[resultWidth - 1]) //sigmoid function on signed results - positive or negative
              0 : CatResultOut <= 1'b1;
              1 : CatResultOut <= 1'b0;
              default : CatResultOut <= 1'bz;
            endcase
            doneFlag <= 1'b1; // stop entering compute sigma/adding bias "loop"
          end  
        end // IF !doneFLAG
      end // if PSEL
  end //always begin
  
  assign CatRecOut = (doneFlag) ? CatResultOut : 1'bz;
endmodule