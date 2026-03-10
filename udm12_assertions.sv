module udm12_assertions(
    input logic [3:0] data_in, 
    input logic clk,
    input logic rstn,
    input logic mode,
    input logic load,
    input logic [3:0] data_out 
);

    // Reset    
    property reset;
        @(posedge clk)
            (!rstn) |=> data_out == 0;
    endproperty

    // load 
    property load_check;
        @(posedge clk)
            disable iff(!rstn)
                (load) |=> data_out == $past(data_in); //NOTE : Data out is output of previous data in, so if we directly assign current data in to data out the load check will fail.
    endproperty 

    // mode 1
    property mode1_max_check;
        @(posedge clk)
            disable iff(!rstn)
                (!load && mode && data_out == 11) |=> data_out == 0;
    endproperty 

    property mode1_up_check;
        @(posedge clk)
            disable iff(!rstn)
                (!load && mode && data_out != 11) |=> data_out == $past(data_out) + 1;
    endproperty


    // mode 0
    property mode0_low_check;
        @(posedge clk)
            disable iff(!rstn)
                (!load && !mode && data_out == 0) |=> data_out == 11;
    endproperty 

    property mode0_down_check;
        @(posedge clk)
            disable iff(!rstn)
                (!load && !mode && data_out != 0) |=> data_out == $past(data_out) - 1;
    endproperty


    RESET : assert property (reset)
                $display("PASS : -----RESET-----");
            else 
                $display("FAIL : -----RESET-----");

    LOAD_CHECK : assert property (load_check)  
                    $display("PASS : -----LOAD_CHECK-----");
                else begin
                    $display("FAIL : -----LOAD_CHECK----- at %0t",$time);
                    $display("data in = %0d ,load = %0d, data out = %0d, %0t",data_in, load, data_out,$time);
                end


    MODE_1_MAX_CHECK : assert property (mode1_max_check)
                        $display("PASS : -----MODE_1_MAX_CHECK-----");
                    else 
                        $display("FAIL : -----MODE_1_MAX_CHECK-----");

    MODE_1_UP_CHECK : assert property (mode1_up_check)
                        $display("PASS : -----MODE_1_UP_CHECK-----");
                    else 
                        $display("FAIL : -----MODE_1_UP_CHECK-----");

    MODE_0_LOW_CHECK : assert property (mode0_low_check)
                        $display("PASS : -----MODE_0_LOW_CHECK-----");
                    else 
                        $display("FAIL : -----MODE_0_LOW_CHECK-----");

    MODE_0_DOWN_CHECK : assert property (mode0_down_check)
                        $display("PASS : -----MODE_0_DOWN_CHECK-----");
                    else 
                        $display("FAIL : -----MODE_0_DOWN_CHECK-----");

endmodule 