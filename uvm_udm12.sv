
import uvm_pkg::*;
`include "uvm_macros.svh"

// Interface we write with TB pov not DUT

interface udm12_if(input bit clk); 

    logic [3:0] data_in;
    logic rstn;
    logic mode;
    logic load;
    logic [3:0] data_out;

    // Clocking block for DRIVER (drives inputs)
    clocking drv_cb @(posedge clk);
        default input #1 output #1;
        output data_in;
        output rstn;
        output mode;
        output load;
    endclocking

    // Clocking block for MONITOR (samples signals) -- monitor usually sees all signals for debugging purpose
    clocking mon_cb @(posedge clk);
        default input #1 output #1;
        input data_in;
        input rstn;
        input mode;
        input load;
        input data_out;
    endclocking

    // Modports referencing clocking blocks
    modport DRV (clocking drv_cb);
    modport MON (clocking mon_cb);
endinterface : udm12_if

// UVM_TB  TFF 

// Transaction -----------------------------------------------------------------------------------------
class xtn extends uvm_sequence_item;

    `uvm_object_utils(xtn)

    rand bit [3:0] data_in;
    rand bit mode, load;
    rand bit rstn;
    bit [3:0] data_out;

    function new(string name = "xtn");
        super.new(name);
    endfunction 

    constraint valid_vals{
        foreach(data_in[i])
            data_in inside {[0:11]};
        mode dist { 1:=5, 0:=5};
        load dist { 1:=5, 0:=5};
        rstn dist { 1:=8, 0:=2};
    }

    // do copy and compare not needed here - using basic comparision in sb

    virtual function void do_print(uvm_printer printer);
        super.do_print(printer);
        printer.print_field("data_in",  data_in,    4, UVM_DEC);
        printer.print_field("rstn",     rstn,       1, UVM_DEC);
        printer.print_field("mode",     mode,       1, UVM_DEC);
        printer.print_field("load",     load,       1, UVM_DEC);
        printer.print_field("data_out", data_out,   4, UVM_DEC);
    endfunction

endclass 

// Config -----------------------------------------------------------------------------------------
class global_config extends uvm_object;
    `uvm_object_utils(global_config)

    virtual udm12_if vif;
    uvm_active_passive_enum is_active;

    static int inputs_sent_to_dut;
    static int outputs_sampled_from_dut;


    function new(string name = "global_config");
        super.new(name);
    endfunction
endclass 

// sequence -----------------------------------------------------------------------------------------

class seq_base extends uvm_sequence #(xtn);

    `uvm_object_utils(seq_base)

    function new(string name = "seq_base");
        super.new(name);
    endfunction

endclass 

// reset sequence
class seq_rstn extends seq_base;
    `uvm_object_utils(seq_rstn)

    function new(string name = "seq_rstn");
        super.new(name);
    endfunction

    task body();
        m_sequencer.grab(this);
        repeat(1) begin
            req = xtn::type_id::create("req");
            start_item(req);
            assert(req.randomize() with {rstn == 0;});
            finish_item(req);
        end
        m_sequencer.ungrab(this);
    endtask
endclass 

// load 1 - data in sequence
class seq_load extends seq_base;
    `uvm_object_utils(seq_load)

    function new(string name = "seq_load");
        super.new(name);
    endfunction

    task body();
        m_sequencer.lock(this);
        repeat(7) begin
            req = xtn::type_id::create("req");
            start_item(req);
            assert(req.randomize() with {rstn == 1 && load == 1;});
            finish_item(req);
        end
        m_sequencer.unlock(this);
    endtask
endclass 

// mode 1 - Upcount sequence 
class seq_md1 extends seq_base;
    `uvm_object_utils(seq_md1)

    function new(string name = "seq_md1");
        super.new(name);
    endfunction

    task body();
        m_sequencer.grab(this);
        repeat(5) begin
            req = xtn::type_id::create("req");
            start_item(req);
            assert(req.randomize() with {rstn == 1 && load == 0 && mode == 1;});
            finish_item(req);
        end
        m_sequencer.ungrab(this);
    endtask
endclass 

// mode 0 - Downcount sequence 
class seq_md0 extends seq_base;
    `uvm_object_utils(seq_md0)

    function new(string name = "seq_md0");
        super.new(name);
    endfunction

    task body();
        m_sequencer.grab(this);
        repeat(5) begin
            req = xtn::type_id::create("req");
            start_item(req);
            assert(req.randomize() with {rstn == 1 && load == 0 && mode == 0;});
            finish_item(req);
        end
        m_sequencer.ungrab(this);
    endtask
endclass 


// Sequencer -----------------------------------------------------------------------------------------
class seqr extends uvm_sequencer #(xtn);

    `uvm_component_utils(seqr)

    function new(string name, uvm_component parent);
        super.new(name,parent);
    endfunction 

endclass 

// Virtual sequencer ---------------------------------------------------------------------------------
class vseqr extends uvm_sequencer #(uvm_sequence_item);

    `uvm_component_utils(vseqr)

    function new(string name, uvm_component parent);
        super.new(name,parent);
    endfunction 

    seqr seqrh;

endclass 

// Virtual sequence -----------------------------------------------------------------------------------
class vseq extends uvm_sequence #(uvm_sequence_item);

    `uvm_object_utils(vseq)

    function new(string name = "vseq");
        super.new(name);
    endfunction

    vseqr vseqrh;

    seq_rstn seq_rstn_h;
    seq_load seq_load_h;
    seq_md1 seq_md1_h;
    seq_md0 seq_md0_h;

    task body();

        if(!$cast(vseqrh,m_sequencer))
            `uvm_fatal(get_type_name(),"Failed to cast");

        seq_rstn_h = seq_rstn::type_id::create("seq_rstn_h");
        seq_load_h = seq_load::type_id::create("seq_load_h");
        seq_md1_h = seq_md1::type_id::create("seq_md1_h");
        seq_md0_h = seq_md0::type_id::create("seq_md0_h");

        fork 
            seq_rstn_h.start(vseqrh.seqrh); // grab - to make sure rstn alwaysg gets exacuted first. 
            seq_load_h.start(vseqrh.seqrh); // lock - to give exclusive access to this sequence
            seq_md1_h.start(vseqrh.seqrh);  // grab - 3rd priority
            seq_md0_h.start(vseqrh.seqrh);  // grab - 2nd priority
        join
    endtask 

endclass 

// Driver -----------------------------------------------------------------------------------------
class driver extends uvm_driver #(xtn);

    `uvm_component_utils(driver)

    virtual udm12_if vif;   
    global_config g_cfg;

    function new(string name, uvm_component parent);
        super.new(name,parent);
    endfunction 

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        
        if(!uvm_config_db #(global_config)::get(this,"","global_config",g_cfg))
            `uvm_fatal("DRIVER","cannot get() vif from TEST")
    endfunction 

    function void connect_phase(uvm_phase phase);
        vif = g_cfg.vif;
    endfunction

    task run_phase(uvm_phase phase);

        // Initial reset sequence  // NOTE : As we are giving sequence for reset - we don't need to give it manually - but remember, sequence is used just increase the number of sequences, manual sequence is always better. 

/*        @(vif.drv_cb);
        vif.drv_cb.rstn <= 0;
        vif.drv_cb.data_in <= 0;
        vif.drv_cb.mode <= 0;
        vif.drv_cb.load <= 0;

        // Hold reset low for a few cycles
        repeat (5) @(vif.drv_cb);

        // Release reset
        @(vif.drv_cb);
        vif.drv_cb.rstn <= 1;
*/ 
        // Now drive transactions forever
        forever begin
            seq_item_port.get_next_item(req);

            @(vif.drv_cb);
            vif.drv_cb.rstn <= req.rstn;
            vif.drv_cb.data_in <= req.data_in;
            vif.drv_cb.mode <= req.mode;
            vif.drv_cb.load <= req.load;
            // keep reset stable high during normal operation

            seq_item_port.item_done();
        end

    endtask
endclass 

// Monitor -----------------------------------------------------------------------------------------
class monitor1 extends uvm_monitor;

    `uvm_component_utils(monitor1)

    virtual udm12_if vif;
    global_config g_cfg;
   
    uvm_analysis_port #(xtn) monitor_port;

    function new(string name, uvm_component parent);
        super.new(name,parent);
        monitor_port = new("monitor_port",this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        
        if(!uvm_config_db #(global_config)::get(this,"","global_config",g_cfg))
            `uvm_fatal("MONITOR","cannot get() vif from TEST")
    endfunction 


    function void connect_phase(uvm_phase phase);
        vif = g_cfg.vif;
    endfunction

    task run_phase(uvm_phase phase);

        xtn sample_dut;

        forever begin 
            
            @(vif.mon_cb)  

                //if(vif.mon_cb.rstn) // only sample on off rstn. To check rstn behaviour we cannot use this.
                begin
                    sample_dut = xtn::type_id::create("sample_dut");

                    sample_dut.data_in = vif.mon_cb.data_in;
                    sample_dut.mode = vif.mon_cb.mode;
                    sample_dut.load = vif.mon_cb.load;
                    sample_dut.rstn = vif.mon_cb.rstn;

                    monitor_port.write(sample_dut);

                    g_cfg.inputs_sent_to_dut ++;
                    $display("Report: Number of driven inputs = %0d",g_cfg.inputs_sent_to_dut);
                end
        end
    endtask 
endclass 


class monitor2 extends uvm_monitor;

    `uvm_component_utils(monitor2)

    virtual udm12_if vif;
    global_config g_cfg;
   
    uvm_analysis_port #(xtn) monitor2_port;

    function new(string name, uvm_component parent);
        super.new(name,parent);
        monitor2_port = new("monitor2_port",this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        
        if(!uvm_config_db #(global_config)::get(this,"","global_config",g_cfg))
            `uvm_fatal("MONITOR","cannot get() vif from TEST")
    endfunction 


    function void connect_phase(uvm_phase phase);
        vif = g_cfg.vif;
    endfunction

    task run_phase(uvm_phase phase);

        xtn sample_dut;

        forever begin 
            
            @(vif.mon_cb)  

            //if(vif.mon_cb.rstn) // We are using rstn sequence -to observe rstn behaviour we cannot use this condition as this will skip rstn = 0
            begin
                sample_dut = xtn::type_id::create("sample_dut");
                sample_dut.data_out = vif.mon_cb.data_out;

                monitor2_port.write(sample_dut);

                g_cfg.outputs_sampled_from_dut ++;
                $display("Report: Number of Sampled outputs = %0d",g_cfg.outputs_sampled_from_dut);
            end
        end
    endtask 

endclass 

// Agent -----------------------------------------------------------------------------------------
class agent_drv extends uvm_agent;

    `uvm_component_utils(agent_drv)

    seqr seqrh;
    driver drvh;
    monitor1 monh;
    global_config g_cfg;

    function new(string name, uvm_component parent);
        super.new(name,parent);
    endfunction 

    function void build_phase(uvm_phase phase);

        super.build_phase(phase);

        seqrh = seqr::type_id::create("seqrh",this);
        drvh = driver::type_id::create("drvh",this);
        monh = monitor1::type_id::create("monh",this);
        
    endfunction 

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        drvh.seq_item_port.connect(seqrh.seq_item_export);
    endfunction

endclass 


class agent_mon extends uvm_agent;

    `uvm_component_utils(agent_mon)

    monitor2 monh;

    function new(string name, uvm_component parent);
        super.new(name,parent);
    endfunction 

    function void build_phase(uvm_phase phase);

        super.build_phase(phase);
        monh = monitor2::type_id::create("monh",this);
        
    endfunction 


endclass 


// Scoreboard -----------------------------------------------------------------------------------------
class sb extends uvm_scoreboard;

    `uvm_component_utils(sb)

    uvm_tlm_analysis_fifo #(xtn) fifo_driver_mon_port;
    uvm_tlm_analysis_fifo #(xtn) fifo_sampler_mon_port;

    bit [3:0] exp_op;
    
    function new(string name, uvm_component parent);
        super.new(name,parent);
        fifo_driver_mon_port = new("fifo_driver_mon_port",this); // Remember second argument "this" is very important here. 
        fifo_sampler_mon_port = new("fifo_sampler_mon_port",this);
    endfunction 


    function void exp_out(ref xtn xtn_h);

        if(!xtn_h.rstn)
            exp_op = 4'd0;
        else if(xtn_h.load)   
            exp_op = xtn_h.data_in;
        else if(xtn_h.mode == 1)
            begin 
                if(exp_op == 11)
                    exp_op = 4'd0;
                else    
                    exp_op = exp_op + 1'b1;
            end
        else begin 
            if(exp_op == 0)
                exp_op = 4'd11;
            else 
                exp_op = exp_op - 1'b1;  
        end
    endfunction 

    task run_phase(uvm_phase phase);

        xtn in_xtn;
        xtn out_xtn;
        
        forever begin
           
            fifo_sampler_mon_port.get(out_xtn);
            fifo_driver_mon_port.get(in_xtn);

            if(exp_op == out_xtn.data_out)  
                `uvm_info(get_type_name(),
                            $sformatf("\n[---Data Match successful---] ==> DATA IN = %0d MODE = %0d LOAD = %0d RESET = %0d ==> [ DATA OUT = EXP OUT ] : [%0d = %0d]\n",
                                    in_xtn.data_in,
                                    in_xtn.mode,
                                    in_xtn.load,
                                    in_xtn.rstn,
                                    out_xtn.data_out,
                                    exp_op),
                            UVM_LOW)  
            else 
                `uvm_error(get_type_name(), $sformatf(
                            "\n\nScoreboard Error [Data Mismatch]: \n Received Transaction: %d \n Expected Transaction: %d\n",
                            out_xtn.data_out, exp_op));

                exp_out(in_xtn);              
        end
    endtask 

endclass 

// Env -----------------------------------------------------------------------------------------
class env extends uvm_env;

    `uvm_component_utils(env)

    agent_drv drv_agnth;
    agent_mon mon_agnth;
    sb sb_h;
    vseqr vseqrh;

    function new(string name, uvm_component parent);
        super.new(name,parent);
    endfunction 

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        vseqrh = vseqr::type_id::create("vseqrh",this);
        drv_agnth = agent_drv::type_id::create("drv_agnth",this);
        mon_agnth = agent_mon::type_id::create("mon_agnth",this);
        sb_h = sb::type_id::create("sb_h",this);
    endfunction 

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        vseqrh.seqrh = drv_agnth.seqrh;
        // connect monitor analysis port with fifo tlm port
        drv_agnth.monh.monitor_port.connect(sb_h.fifo_driver_mon_port.analysis_export);
        mon_agnth.monh.monitor2_port.connect(sb_h.fifo_sampler_mon_port.analysis_export);
    endfunction 

endclass 

// Test -----------------------------------------------------------------------------------------
class test extends uvm_test;

    `uvm_component_utils(test)

    env envh;
    global_config g_cfg;
    vseq vseqh;

    function new(string name, uvm_component parent);
        super.new(name,parent);
    endfunction 

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        g_cfg = global_config::type_id::create("g_cfg");
        vseqh = vseq::type_id::create("vseqh");

        if(!uvm_config_db #(virtual udm12_if)::get( this, "", "udm12_if", g_cfg.vif))
            `uvm_fatal(get_full_name(),"Cannot get() global config from ---TOP---")

        uvm_config_db #(global_config)::set( this, "*", "global_config", g_cfg);

        envh = env::type_id::create("envh",this);
    endfunction 

    function void end_of_elaboration_phase(uvm_phase phase);
        uvm_top.print_topology();
    endfunction

    task run_phase(uvm_phase phase);

        //seq_base seqh;

        phase.raise_objection(this);
    
        vseqh.start(envh.vseqrh);
        //seqh = seq_base::type_id::create("seqh");
        //seqh.start(envh.drv_agnth.seqrh);
        phase.drop_objection(this);
    endtask 
endclass 

// Top -----------------------------------------------------------------------------------------
module uvm_udm12;

    bit clk = 0;
    int cc = 10;

    udm12_if UDM_FF(clk);
       
    udm12 DUT(
        .data_in(UDM_FF.data_in), 
        .clk(clk),
        .rstn(UDM_FF.rstn),
        .mode(UDM_FF.mode),
        .load(UDM_FF.load),
        .data_out(UDM_FF.data_out)
    );

    bind udm12 udm12_assertions UDM_ASSERTION(
                                        .data_in(data_in),
                                        .clk(clk),
                                        .rstn(rstn),
                                        .mode(mode),
                                        .load(load),
                                        .data_out(data_out)
                                    );

    always #(cc/2) clk = ~clk;

    initial begin 
        uvm_config_db #(virtual udm12_if)::set(null,"*","udm12_if",UDM_FF);
        run_test("test");
    end
endmodule 
