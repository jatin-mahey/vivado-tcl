# check if arguments provided
if {$argc != 1} {
    puts "vivado -mode batch -source tcl/make.tcl -notrace -tclargs <action>"
    exit 1
}

# delete log files that get generated
foreach logs [glob -nocomplain -types f *backup*] {
    file delete -force $logs
}

# =====> Supress excessive logs <===== #
set_msg_config -severity INFO -suppress
set_msg_config -id {Synth 8-638} -suppress
set_msg_config -id {Common 17-349} -suppress
set_msg_config -id {Vivado 12-1000} -suppress

# =====> Set variables <===== #
set action [lindex $argv 0]
set projectDir [pwd]
set outputDir $projectDir/build
set partNum xck26-sfvc784-2LV-c

# =====> On clean <===== #
if {$action eq "clean"} {
    # clean build folder
    set files [glob -nocomplain "$outputDir/*"]
    if {[llength $files] != 0} {
        puts "Deleting contents of $outputDir ..."
        file delete -force {*}[glob -directory $outputDir *]; 
    } else {
        puts "$outputDir is empty"
    }
    # close project if exists
    set result [catch {current_project} project]
    if {$result == 0} {
        puts "Closing open projects ..."
        close_project -force
    }
    puts "\n/////////////////////// Cleanup finished ///////////////////////\n"
}

# =====> On init <===== #
if {$action eq "init"} {
    puts "Creating temp project and adding board ..."
    file mkdir $outputDir
    # create temp project and set part
    create_project project $outputDir -part $partNum
    set_property board_part xilinx.com:kv260_som:part0:1.4 [current_project]
    puts "\n/////////////////////// Initialization finished ///////////////////////\n"
}

# =====> On synth <===== #
if {$action eq "synth"} {
    # add source files
    # read_vhdl -library usrDefLib [ glob path/to/vhdl/sources/*.vhdl ]
    read_verilog [glob $projectDir/rtl/*.v]
    # read_xdc [ glob $projectDir/xdc/*.xdc]

    # run synthesis
    synth_design -top top -part $partNum
    write_checkpoint -force $outputDir/Synthesis.runs/post_synth.dcp
    report_timing_summary -file $outputDir/Synthesis.runs/post_synth_timing_summary.rpt
    report_utilization -file $outputDir/Synthesis.runs/post_synth_util.rpt
    puts "\n/////////////////////// Synthesis finished ///////////////////////\n"
}

# =====> On impl <===== #
if {$action eq "impl"} {
    # run optimization
    opt_design
    place_design
    report_clock_utilization

    # get timing violations and run optimizations if needed
    if {[get_property SLACK [get_timing_paths -max_paths 1 -nworst 1 -setup]] < 0} {
    puts "Found setup timing violations => running physical optimization"
    phys_opt_design
    }
    write_checkpoint -force $outputDir/Implementation.runs/post_place.dcp
    report_utilization -file $outputDir/Implementation.runs/post_place_util.rpt
    report_timing_summary -file $outputDir/Implementation.runs/post_place_timing_summary.rpt

    # route design and generate bitstream
    route_design -directive Explore
    write_checkpoint -force $outputDir/Implementation.runs/post_route.dcp
    report_route_status -file $outputDir/Implementation.runs/post_route_status.rpt
    report_timing_summary -file $outputDir/Implementation.runs/post_route_timing_summary.rpt
    report_power -file $outputDir/Implementation.runs/post_route_power.rpt
    report_drc -file $outputDir/Implementation.runs/post_imp_drc.rpt
    write_verilog -force $outputDir/Implementation.runs/impl_netlist.v -mode timesim -sdf_anno true
    puts "\n/////////////////////// Implementation finished ///////////////////////\n"
}

# =====> On gen-bit <===== #
if {$action eq "gen-bit"} {
    # write_bitstream -force $outputDir/nameOfBitstream.bit
    puts "\n/////////////////////// Bitstream generation finished ///////////////////////\n"
}
