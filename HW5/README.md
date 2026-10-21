
# HW5 Submission Template

This document contains the instructions and commands to prepare your Homework 5
submission for Gradescope auto-grading.  It makes use of the CMake build system
to run the common commands used in the Standard Class Tutorial (Tutorial 1).

## Overview
- [Decompress](#decompress)
- [Start Designing](#start-designing)
- [Simulation](#simulation)
- [Synthesis](#synthesis)
- [Submission](#submission)
- [Appendix](#appendix)

## Decompress
Once you have placed `HW5-template.tar.gz` at desired directory. Launch a
terminal at that directory and use the following command to tar.
```bash
tar xzf HW5-template.tar.gz
```
You should find the unzipped project folder `HW5/`

## Start Designing
### Setup script

`HW5/setup.sh` is to load Siemens ModelSim/Questa and Synopsys Design
Compiler/Design Vision. You can use differnt versions if you want, but these are
the verisons that will be used to test you design. 

To source the script:
```bash
cd HW5
source setup.sh
```
This script also enables you to <kbd>Tab</kbd> complete `make` commands

### Where to put your design

A Verilog file `HW5/srcs/rtl/dut.sv` is provided with all the ports already
connected to the test fixture. The file `dut.sv` is a stub to put your code in.
If your design spans multiple files, then all files must located in the
`HW5/srcs/rtl` directory and one file must include your top-level design
declared identically to the way it appears in `dut.sv`.

The test-bench for your design can be found in `HW5/srcs/tb`.  The top level
test-bench module is in `tb.sv`.  Some files in this directory are encrypted to
make the task more difficut for an LLM to reverse-engineer.  You are free to
modify the unencrypted files to explore the system, but be aware that we will
test your design using the original test-bench, not your modified files.

The file `HW5/srcs/cpp/memory_interface.cpp` contains System Verilog Direct
Programming Interface (DPI) functions used by the DRAM and SRAM models.  Do not
modify these files.

The detailed rundown of the directory structure can be found in the **Appendix**
of this document.


### How to setup build environment
To setup you build environment

```bash
cd HW5
source setup.sh
mkdir build
cd build
cmake .. --preset run
```
The `cmake` command will create a `Makefile` in your `build`
directory, along with many other files.  You will see a message showing the
default clock-period and Unity ID assumed for this assignment.
```
  DC_CLOCK_PER="4.0"
  TEST="-1"
  UNITY_ID="jdoe12"
```
From this point on, you can execute `make` commands from this directory.
But we want the commands to record your details, not these template details.
Before doing anything else, please change these two values in the
`CMakePresets.json` file to match your own minimum clock period and Unity
ID.  You may edit the file using your preferred text editor.  For example, edit
line 11 to set your Unity ID.
```
        "UNITY_ID": "jdoe12", -> "UNITY_ID": "your_id",
```
Once complete, run the `cmake .. --preset run` command again from the
`build` directory to update the build files with your new settings.  You may
use this command at any time to re-generate the build files later, if you forget
to do it in this step.

## Simulation

### Simulation Targets

This template provides two main simulation targets:

- **dut** — Build and run **your implementation**  
  - Synthesizable RTL intended for final submission  
  - Must meet interface timing and support pipelining  
  - Use this target to verify functionality, latency, and protocol compliance

- **mem** — Run the **DRAM test suite**  
  - Demonstrates expected behavior for back-to-back commands  
  - Complete simulation includes four sections, each of which shows 16 cases of
    two streaming reads, two streaming writes, read-after-write, and
    write-after-read respectively
  - The cases in each section show the behavior when the second command is
    issued 1 to 16 cycles after the first
  - For cases in which the second command is issued too soon, the test-bench
    prints the message "dropping READ" or "dropping WRITE"
  - For cases in which the seccon command is issued at an acceptable time, the
    test-bench prints the message "PASS"

### Run with Modelsim GUI

The easiest way to run a simulation flow to check your design is by examining
the output in the ModelSim graphical user interface.  The following command
buids `HW5/srcs/rtl/dut.sv` and launches the testbench in ModelSim.
```bash
make vsim-dut 
```
Note that `make vsim-mem` will do the same for the **mem** simulation target.

At this point, you will not see any output.  You may ask ModelSim to capture
waveforms by entering the following command at the ModelSim GUI window's "VSIM
#>" prompt:
```
do ../do/waves.do
```

Edit the file  `HW5/do/waves.do` as needed to capture the signals for your
desigin.  Once your captured waveforms are specified, you may reload, restart,
and rerun your tests any time you make changes to the Verilog files with the
following command, executed in ModelSim GUI window's "VSIM #>" prompt: 
```
make vlog-dut; restart -f; run -all
```

### Run ModelSim with no GUI

To evaluate you design headless/no-gui, change directory to `HW5/build` and
use the following commands:
```bash
make vsim-dut-c
```
You will not see waveforms, but you will see the output of any `$diplay` or
`$monitor` commands in your Verilog code.

Note that `make vsim-mem-c` will do the same for the **mem** simulation target.

To compile your `dut.sv` file without executing a simulation (to check for
syntax errors, for example), you may use the following simpler command:
```bash
make vlog-dut 
```


### Configuring for indivial tests:

The test-bench in `tb.sv` can different test-cases, depending on the value of TEST that is passed to `cmake`.  The `run` preset will run all tests, which is indicated by setting TEST to -1.  This template includes 4 total tests-cases, numbered 0-3.  Each test loads the `inputs/input{case}.dat` files for the DRAM and compares results to the `outputs/output{case}.dat` files for the SRAM.

If you want to run only one of these tests (to reduce the amount of output, for example), then you can configure `build` directory to do this with the commannd
```bash
cmake .. -DTEST={case}
```
where `[case]` is the index of the test case.  You may also use
```bash
cmake .. --preset test{case}
```
For example, to run test-case 2, use `cmake .. -DTEST=2` or `cmake .. --preset test2`.  After running this command, use `make vsim-dut`, `make vlog-dut`, and `make vsim-dut-c` as described above to run only that case.

Note that configuring one test-case with this approach has no effect on the **mem** simulation target.  The `make vsim-mem` and `make vsim-mem-c` targets will always load `input0.dat` before every one of its 64 example cases. 


### Evaluation Testing
To evaluate you design headless/no-gui, change directory to ```HW5/build/```
```
cmake .. --preset test
make vsim-dut-c # Runs the test in headless mode  
```
This will produce a log file that will highlight the results of your design. This should only be ran as a final step before Synthesis

Simulation log file is located here ```HW5/build/sim/logs/results.log```


## Synthesis

Once you have a functional design, you can synthesize it in `HW5/build/`

### Synthesis Command

The following command will synthesize your design with the clock period
specified in your `CMakePresets.json` file:
```bash
make synth  
```

If you change the the clock period specified in your `CMakePresets.json`
file, remember that you can always regenerate the build scripts with the command
`cmake .. --preset run` and use `make synth` again with your new clock
period.

### Synthesis Reports
You can find your timing report and area report in `HW5/build/synth/reports`.

## Submission
### Homework Report

Place the solutions requested in the HW5.pdf assignment in `HW5/report/`.  A
blank `report.pdf` file is provided as a template.  Please replace this file
with your report.

### Compress for submission

To generate the compressed file for Gradescope for submission, change directory
to `HW5/build` and use the following command:
```bash
cmake .. --preset run
make compress
```
The `cmake` command is necessary only as a safety check to ensure that your
clock-period and UnityID are correctly set.  Make sure the messages printed
reflect the your unity id and new clk.
```
  DC_CLOCK_PER="10.0" ->  DC_CLOCK_PER="YYY.XXX"
  UNITY_ID="jdoe12" -> UNITY_ID="your_id" 
```
You will find the generated tar.gz file in `HW5/build/submission.your_id.tar.gz` 

### Check before you submit

Please check your `.tar.gz` file and make sure all the files are present for
submission.  Your design simulation will be evalutate by Gradescope, you can
check you submission by un-tar-ing a fresh `HW5-template.tar.gz` and copying
you submission in to the root dir:
```bash
tar -xzvf HW5-template.tar.gz
cd HW5
cp ./path/to/tar/file/submission.jdoe12.tar.gz ./
tar xzvf submission.your_id.tar.gz
mkdir build
cd build
cmake .. --preset run
make vsim-dut-c synth
```
It is recommended to download a fresh copy of the HW5 directory and run the
command above to ensure that there are no problems with your submission.

### Submit your files
Upload the generated `HW5/build/submission.your_id.tar.gz` file to gradescope

## Appendix

### Directory Rundown

You will find the following directories in `HW5/`

* `HW5/`
  * Contains the `CMakeLists.txt` used to compile and simulate the design
* `HW5/inputs/input[1/2/3/4].dat` 
  * Contains the .dat files for the memory content for DRAM used in HW 
* `HW5/inputs/input[1/2/3/4].csv` 
  * Contains the .csv files for the steaming commands to the test fixture.
* `HW5/outputs/output[1/2/3/4].dat` 
  * Contains the .dat files for the output SRAM used in HW
* `HW/srcs/rtl/`
  * All .v and .sv files will be compiled when executing `make vlog-dut` in `HW5/build/`
  * A template `dut.sv` that interfaces with the test fixture is provided
* `report/`
  * Replace HW5/report/report.pdf with your HW report here before running `make compress MY_UID=<your_unity_id>` command
* `HW5/synthesis/`
  * The directory where the tcl scripts used to synthesize your design
  * Only the CompileAnalyze.tcl will be include in the submission.<your_unity_id>.tar.gz
  * Synthesis reports will be exported to `HW5/build/synth/reports/`
  * Synthesis logs will be exported to `HW5/build/logs/reports/`
  * Synthesized netlist will be generated to `HW5/build/synth/gl/`
* `HW5/srcs/tb/`
  * Contains the test fixture of the HW


