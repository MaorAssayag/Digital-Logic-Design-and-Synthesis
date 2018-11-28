
module adder_multiplier_custom #(parameter PixelWidth=8, parameter WeightWidth=5, parameter PixelRowWidth=24, parameter WeightRowWidth=15)(
 input   [PixelRowWidth-1:0]    PixelRow,
 input   [WeightRowWidth-1:0]    WeightRow,
 output  [(2*(WeightWidth+PixelWidth)):0] Result);
 
 assign Result = PixelRow[0+:PixelWidth]*WeightRow[0+:WeightWidth]
               + PixelRow[PixelWidth+:PixelWidth]*WeightRow[WeightWidth+:WeightWidth]
               + PixelRow[(PixelWidth<<1)+:PixelWidth]*WeightRow[(WeightWidth<<1)+:WeightWidth];
endmodule
