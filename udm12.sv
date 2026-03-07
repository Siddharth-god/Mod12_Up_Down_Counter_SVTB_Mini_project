//-------------------------------------------------------------RTL-------------------------------------------------------------
// Mod 12 (Up_down) counter  // _---------- write coverage as well.
module udm12(
    input logic [3:0] data_in, 
    input logic clk,
    input logic rstn,
    input logic mode,
    input logic load,
    output logic [3:0] data_out
);
    always@(posedge clk)
    begin 
        if(!rstn)
            data_out <= 4'd0;
        else if(load)   
            data_out <= data_in;
        else if(mode == 1)
            begin 
                if(data_out == 11)
                    data_out <= 4'd0;
                else    
                    data_out <= data_out + 1'b1;
            end
        else begin // If mode 0 then decrement or reset to 0.
            if(data_out == 0)
                data_out <= 4'd11;
            else 
                data_out <= data_out - 1'b1;  
        end
    end
endmodule : udm12
