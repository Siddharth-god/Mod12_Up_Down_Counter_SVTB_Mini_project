//-------------------------------------------------------------RTL-------------------------------------------------------------
// Mod 12 (Up_down) counter  // _---------- write coverage as well.
module udm(
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
endmodule : udm

//-------------------------------------------------------------INTERFACE-------------------------------------------------------------

interface udm_if(input bit clk); // An interface models what the testbench drives. DUT it observes so we don't often put it in interface - although we can do no worries. 
    logic rstn, load, mode;
    logic [3:0] data_in;
    logic [3:0] data_out; // DUT-driven, TB observes

    clocking wr_drv_cb@(posedge clk);
        default output #1; // output = driving
        output rstn;
        output load;
        output mode;
        output data_in; 
        //input data_out;
    endclocking: wr_drv_cb

    clocking wr_mon_cb@(posedge clk);
        default input #2; // input = sampling
        input rstn;
        input load;
        input mode;
        input data_in;
        //input data_out;
    endclocking: wr_mon_cb

    clocking rd_mon_cb@(posedge clk);
        default input #2; // input = sampling
        input data_out;
    endclocking: rd_mon_cb

    modport WR_DRV_MP(input wr_drv_cb);
    modport WR_MON_MP(input wr_mon_cb);
    modport RD_MON_MP(input rd_mon_cb);

endinterface : udm_if

//-------------------------------------------------------------CONFIG-TRANSACTIONS-------------------------------------------------------------
class udm_cfg;
  static int number_of_transactions = 10;
endclass

//-------------------------------------------------------------TRANSACTION-CLASS-------------------------------------------------------------

class udm_trans;
    rand bit [3:0] data_in;
    bit [3:0] data_out;
    bit [3:0] exp_out;
    rand bit load, mode; 
    rand bit rstn;
    static int trans_id;
    static int no_of_mode_trans;
    static int no_of_load_trans;

    constraint valid_data{
        data_in inside {[0 : 11]};
        load dist{1 := 7, 0 := 3};
        mode dist{1 := 1, 0 := 1};
        rstn dist{1 := 8, 0 := 2};
    }
    // constraint valid_load {
    //     rstn -> load dist {1 := 7, 0 := 3};
    // }
    // constraint valid_rstn {
    //     !(rstn == 0 && load == 1);
    // }

    virtual function void write_drv_display(string message);
        $display("========================================");
        $display("%s at t=%0t",message,$time);
        $display("data input = %0d",data_in);
        $display("load = %0d",load);
        $display("mode = %0d",mode);
        $display("========================================");
    endfunction : write_drv_display

    virtual function void write_mon_display(string message);
    $display("========================================");
        $display("%s at t=%0t",message,$time);
        $display("data input = %0d",data_in);
        $display("load = %0d",load);
        $display("mode = %0d",mode);
        $display("rstn = %0d",rstn);
        $display("========================================");
    endfunction : write_mon_display

    virtual function void read_mon_display(string message);
        $display("========================================");
        $display("%s at t=%0t",message,$time);
        $display("data_out = %0d",data_out);
        $display("========================================");
    endfunction : read_mon_display

    virtual function bit compare(
    input  udm_trans rd_m,
    output string    message
    );
        $display("EXPECTED OUTPUT %p at t=%0t",exp_out,$time);
        if (this.exp_out != rd_m.data_out) begin
            message = "-----------------DATA MISMATCH-----------------";
            $display("At time : %0t", $time);
            return 0;
        end
        else begin
            message = "-----------------SUCCESSFULLY COMPARED-----------------";
            return 1;
        end
    endfunction

    function void post_randomize();
        trans_id ++;
        if(this.mode == 1)
            no_of_mode_trans++;
        if(this.load == 1)
            no_of_load_trans++;
    endfunction : post_randomize
endclass : udm_trans

//-------------------------------------------------------------GENERATOR-------------------------------------------------------------

class generator; 
    udm_trans gen_trans; // To create transaction stimuls object
    udm_trans data2send; // to create shallow copy and copy data before putting on mailbox
    mailbox #(udm_trans) gen2wrd;

    function new(mailbox #(udm_trans) gen2wrd); 
        this.gen2wrd = gen2wrd;
        gen_trans = new;
    endfunction : new

    virtual task start();
        fork
            begin 
                for(int i=0; i<udm_cfg::number_of_transactions; i++) 
                begin 
                    if(!gen_trans.randomize())
                        $error("Randomization falied!");
                    data2send = new gen_trans;
                    gen2wrd.put(data2send);
                    $display("generator generated data %p",data2send);
                end
            end
        join_none
    endtask : start
endclass : generator

//-------------------------------------------------------------WRITE_DRIVER-------------------------------------------------------------

class udm_write_drv;
    virtual udm_if.WR_DRV_MP wr_drv_if;
    udm_trans wr_trans;
    mailbox #(udm_trans) gen2wrd;

    function new(virtual udm_if.WR_DRV_MP wr_drv_if,
                mailbox #(udm_trans) gen2wrd);
        this.wr_drv_if = wr_drv_if;
        this.gen2wrd = gen2wrd;
    endfunction : new

    virtual task drive();
        @(wr_drv_if.wr_drv_cb);
        wr_trans.write_drv_display("WRITE DATA IS DRIVEN");
        wr_drv_if.wr_drv_cb.data_in <= wr_trans.data_in;
        wr_drv_if.wr_drv_cb.mode <= wr_trans.mode;
        wr_drv_if.wr_drv_cb.load <= wr_trans.load;
        wr_drv_if.wr_drv_cb.rstn <= wr_trans.rstn;
    endtask 

    virtual task start();
        fork
            forever begin // Once we call task the driving should happen until we stop it.
                gen2wrd.get(wr_trans); // After getting the data using trans handle, we drive the data to dut using same handle where we get the data.
                drive(); 
            end
        join_none
    endtask
endclass : udm_write_drv

//-------------------------------------------------------------WRITE_MONITOR-------------------------------------------------------------

class udm_write_mon;
    virtual udm_if.WR_MON_MP wr_mon_if;
    mailbox #(udm_trans) wrmon2ref;
    udm_trans wr_mon;
    udm_trans send2ref;
    udm_trans cov_data;

    int wr_cycle;

    covergroup udm_coverage;

        RST : coverpoint cov_data.rstn{
            bins RST_0 = {0};
            bins RST_1 = {1};
        }

        LD : coverpoint cov_data.load{
            bins LOAD_0 = {0};
            bins LOAD_1 = {1};
        }

        MD : coverpoint cov_data.mode{
            bins MODE_0 = {0};
            bins MODE_1 = {1};
        }

        DATA : coverpoint cov_data.data_in{
            bins ZERO   = {0};
            bins MIN    = {[1:4]};
            bins MID    = {[5:8]};
            bins MAX    = {[9:11]};
        }

        RST_LD_MD_DATA : cross RST,LD,MD,DATA;
    endgroup : udm_coverage

    function new(virtual udm_if.WR_MON_MP wr_mon_if,
                mailbox #(udm_trans) wrmon2ref);
        this.wr_mon_if = wr_mon_if;
        this.wrmon2ref = wrmon2ref;
        wr_mon = new; //---------------> Not creating object for monitor, will throw error while sampling data - bad reference handle.
        udm_coverage = new;
    endfunction : new

    virtual task wr_monitor();
        @(wr_mon_if.wr_mon_cb);
        begin 
            wr_cycle++;
            wr_mon.data_in = wr_mon_if.wr_mon_cb.data_in;
            wr_mon.load = wr_mon_if.wr_mon_cb.load;
            wr_mon.mode = wr_mon_if.wr_mon_cb.mode;
            wr_mon.rstn = wr_mon_if.wr_mon_cb.rstn; // How is it even possible ? Who is passing reset to cb ? 

            send2ref = new wr_mon;
            cov_data = new wr_mon;
            $display("WR_MON cycle=%0d time=%0t", wr_cycle, $time);

            wrmon2ref.put(send2ref);
            udm_coverage.sample();
            wr_mon.write_mon_display("WRITE DATA IS SAMPLED");
        end
    endtask : wr_monitor

    virtual task start();
        fork
            forever begin 
                wr_monitor();
            end
        join_none
    endtask : start
endclass : udm_write_mon

//-------------------------------------------------------------READ_MONITOR-------------------------------------------------------------

class udm_read_mon;
    virtual udm_if.RD_MON_MP rd_mon_if;
    mailbox #(udm_trans) rdmon2sb;
    udm_trans rd_mon, send2sb;
    int rd_cycle;

    function new(virtual udm_if.RD_MON_MP rd_mon_if,
                mailbox #(udm_trans) rdmon2sb);
        this.rd_mon_if = rd_mon_if;
        this.rdmon2sb = rdmon2sb;
        rd_mon = new;  //---------------> Not creating object for monitor, will throw error while sampling data - bad reference handle.
    endfunction : new

    virtual task rd_monitor();
        @(rd_mon_if.rd_mon_cb);
        begin 
            rd_cycle++;
            rd_mon.data_out = rd_mon_if.rd_mon_cb.data_out;

            send2sb = new rd_mon;
            $display("RD_MON cycle=%0d time=%0t", rd_cycle, $time);
            rdmon2sb.put(send2sb);
            rd_mon.read_mon_display("READ DATA OUT IS SAMPLED");
        end
    endtask : rd_monitor

    virtual task start();
        fork : READ_MON
            forever begin 
                rd_monitor();
            end
        join_none : READ_MON
    endtask : start
endclass : udm_read_mon

//-------------------------------------------------------------REF_MODEL-------------------------------------------------------------

class udm_rfmodel;
    int exp_count; // To store temp values then assign to trans object exp_out
    int ref_cycle;
    udm_trans wrmon_data, data_to_sb;
    mailbox #(udm_trans) ref2sb;
    mailbox #(udm_trans) wrmon2ref;

    function new(mailbox #(udm_trans) ref2sb,
                mailbox #(udm_trans) wrmon2ref);
        this.ref2sb = ref2sb;
        this.wrmon2ref = wrmon2ref;
    endfunction : new

    virtual task start();
        fork 
            forever 
                begin 
                    wrmon2ref.get(wrmon_data); // Acting as posedge. 
                    ref_cycle++;
                    $display("REF cycle=%0d time=%0t", ref_cycle, $time);
                    if(!wrmon_data.rstn) begin 
                        $display("RESET HITT!!!!!!!!!");
                        exp_count = 1'b0;
                        $display("REF RESET----");
                    end
                    else if(wrmon_data.load) begin 
                        exp_count = wrmon_data.data_in;
                        $display("REF load----");
                    end
                    else if(wrmon_data.mode) begin 
                        exp_count = (exp_count == 11) ? 4'b0 : exp_count + 1'b1;
                        $display("REF mode----");
                    end 
                    else  begin 
                        exp_count = (exp_count == 0) ? 4'd11 : exp_count - 1'b1;
                        $display("REF else mode----");
                    end
                    data_to_sb = new wrmon_data; // Shallow copy
                    data_to_sb.exp_out = exp_count;  
                    ref2sb.put(data_to_sb); // Send to scoreboard
                end           
        join_none
    endtask : start
endclass : udm_rfmodel

//-------------------------------------------------------------SCORE_BOARD-------------------------------------------------------------
class udm_sb;

    event DONE;

    int ref_data_count = 0;
    int rdmon_data_count = 0;
    int data_verified = 0;

    mailbox #(udm_trans) ref2sb;
    mailbox #(udm_trans) rdmon2sb;

    udm_trans ref_data;
    udm_trans rdm_data;
    udm_trans cov_data;

    // Queue to align expected with DUT latency (1 cycle)
    udm_trans exp_q[$];

    // Coverage model
    covergroup udm_coverage;
        DATA : coverpoint cov_data.data_out {
            bins ZERO   = {0};
            bins MIN    = {[1:4]};
            bins MID    = {[5:8]};
            bins MAX    = {[9:11]};
        }
    endgroup : udm_coverage

    function new(
        mailbox #(udm_trans) ref2sb,
        mailbox #(udm_trans) rdmon2sb
    );
        this.ref2sb   = ref2sb;
        this.rdmon2sb = rdmon2sb;
        udm_coverage  = new;
    endfunction : new

    // Start task
    virtual task start();
        fork
            forever begin
                // Get expected from reference model
                ref2sb.get(ref_data);
                ref_data_count++;
                exp_q.push_back(ref_data);

                // Get actual from read monitor
                rdmon2sb.get(rdm_data);
                rdmon_data_count++;

                // Align: DUT output corresponds to previous expected
                if (exp_q.size() > 1) begin
                    udm_trans exp_aligned;
                    exp_aligned = exp_q.pop_front();
                    check(exp_aligned, rdm_data);
                end
            end
        join_none
    endtask : start

    // Check task
    virtual task check(udm_trans exp_h, udm_trans act_h);
        string diff;

        $display("REF DATA USED FOR COMPARE %p", exp_h);
        $display("READ DATA USED FOR COMPARE %p", act_h);

        if (!exp_h.compare(act_h, diff)) begin
            $display("SB FAIL : %s\n%m\n\n", diff);
        end
        else begin
            $display("SB PASS : %s\n%m\n\n", diff);
        end

        cov_data = new act_h;
        udm_coverage.sample();

        data_verified++;
        if (data_verified >= udm_cfg::number_of_transactions)
            -> DONE;
    endtask : check

    // Report
    function void report();
        $display("ref_data_count = %0d", ref_data_count);
        $display("rdmon_data_count = %0d", rdmon_data_count);
        $display("data_verified   = %0d", data_verified);
        $display("total transactions = %0d", udm_trans::trans_id);
        $display("No of mode shifts = %0d", udm_trans::no_of_mode_trans);
        $display("No of load shifts = %0d", udm_trans::no_of_load_trans);
    endfunction : report

endclass : udm_sb

//-------------------------------------------------------------ENVIRONMENT-------------------------------------------------------------

class environment;
    virtual udm_if.WR_DRV_MP wr_drv_if;
    virtual udm_if.WR_MON_MP wr_mon_if;
    virtual udm_if.RD_MON_MP rd_mon_if;

    mailbox #(udm_trans) gen2wrd    = new();
    mailbox #(udm_trans) wrmon2ref  = new();
    mailbox #(udm_trans) ref2sb     = new();
    mailbox #(udm_trans) rdmon2sb   = new();

// Handles of all the low level TB components
    generator      gen_h;
    udm_write_drv  wr_drv_h;
    udm_write_mon  wr_mon_h;
    udm_read_mon   rd_mon_h;
    udm_rfmodel    rf_model_h;
    udm_sb         sb_h;

    function new(
            virtual udm_if.WR_DRV_MP wr_drv_if,
            virtual udm_if.WR_MON_MP wr_mon_if,
            virtual udm_if.RD_MON_MP rd_mon_if
            );
        this.wr_drv_if = wr_drv_if;
        this.wr_mon_if = wr_mon_if;
        this.rd_mon_if = rd_mon_if;
    endfunction : new
/*
    virtual task apply_reset();
        // drive reset via driver interface
        wr_drv_if.wr_drv_cb.rstn <= 1;
        repeat (2) @(wr_drv_if.wr_drv_cb);
        
        wr_drv_if.wr_drv_cb.rstn <= 0;
        wr_drv_if.wr_drv_cb.load <= 0;
        wr_drv_if.wr_drv_cb.mode <= 0;
        wr_drv_if.wr_drv_cb.data_in <= 0;

        repeat (5) @(wr_drv_if.wr_drv_cb); // hold reset for 2 cycles

        wr_drv_if.wr_drv_cb.rstn <= 1;
        @(wr_drv_if.wr_drv_cb);            // release on clean edge
    endtask
*/

    virtual task build();
        gen_h      = new(gen2wrd);
        wr_drv_h    = new(wr_drv_if, gen2wrd); 
        wr_mon_h    = new(wr_mon_if, wrmon2ref);
        rd_mon_h    = new(rd_mon_if, rdmon2sb);        
        rf_model_h  = new(ref2sb, wrmon2ref);       
        sb_h        = new(ref2sb, rdmon2sb);
    endtask : build

    virtual task start();
        gen_h.start();
        wr_drv_h.start();      
        wr_mon_h.start();
        rd_mon_h.start();  
        rf_model_h.start();   
        sb_h.start();
    endtask : start

    virtual task stop();
        //wait(sb_h.DONE.triggered);
        @sb_h.DONE;
    endtask : stop

    virtual task run();
        
        fork : RUN_FORK
            begin
            //apply_reset();
            start();        // starts all components
            stop();         // waits for DONE
            end
        join

        disable RUN_FORK;   
        sb_h.report();
    endtask : run
endclass : environment

//-------------------------------------------------------------TEST-CLASS-------------------------------------------------------------

class test;

// Creating virtual interface handles so that we can link to static interfaces. 
    virtual udm_if.WR_DRV_MP wr_drv_if;
    virtual udm_if.WR_MON_MP wr_mon_if;
    virtual udm_if.RD_MON_MP rd_mon_if; 

    environment env_h; // Yet to write environment class

// Overiding Constructor
    function new( 
            virtual udm_if.WR_DRV_MP wr_drv_if,
            virtual udm_if.WR_MON_MP wr_mon_if,
            virtual udm_if.RD_MON_MP rd_mon_if
            );
        this.wr_drv_if = wr_drv_if;
        this.wr_mon_if = wr_mon_if;
        this.rd_mon_if = rd_mon_if;

        env_h = new(wr_drv_if, wr_mon_if, rd_mon_if);
    endfunction : new

// Virtual task build 
    virtual task build();
        env_h.build();
    endtask : build 

// Virtual task run
    virtual task run();
        env_h.run();
    endtask : run

endclass : test

//-------------------------------------------------------------TOP-------------------------------------------------------------

module udm12_svtb;
    parameter cycle = 10;
    reg clk;
    udm_if DUT_IF(clk);
    test test_h;

    udm Up_down_mod_12_counter (.clk(clk),
                                .load(DUT_IF.load),
                                .mode(DUT_IF.mode),
                                .rstn(DUT_IF.rstn),
                                .data_in(DUT_IF.data_in),
                                .data_out(DUT_IF.data_out));

    // Generate clock
    initial begin 
        clk = 1'b0;
        forever #(cycle/2) clk = ~clk; // Why we are writing like this ?
    end

    initial begin 
        test_h = new(DUT_IF, DUT_IF, DUT_IF);
        test_h.build();
        test_h.run();
        $finish;
    end
endmodule : udm12_svtb