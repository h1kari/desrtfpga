desrtfpga
=========

This repo contains the FPGA code needed to execute the DES compute portion of [desrtop](https://github.com/h1kari/desrtop). The project is configured as a ring of DES cores that accepts jobs on an input stream from the [desrtop](https://github.com/h1kari/desrtop) program and returns back through an output stream as they are completed. The code is hard-wired to compute on the 1122334455667788 plaintext and currently implements 87 cores (3 cores in 29 regions) running on the [Xilinx XCKU060 FPGA](http://www.xilinx.com) on the [Pico AC-510](http://picocomputing.com/ac-510-superprocessor-module/) module and using the [Pico Computing framework](https://picocomputing.zendesk.com/hc/en-us). The project can be easily built to run with 116 cores (4 cores in 29 regions), but is currently running at reduced speed to save on power and heat.

Create Project
--------------

To generate the Xilinx Vivado project, we first recommend using Vivado 2015.2 as the Pico Framework works best with that version.

```
$ . /opt/Xilinx/Vivado/2015.2/settings64.sh
$ vivado -source desrtfpga.tcl
```

This will generate the vivado project and open it in vivado. Then simply run Generate Bitstream to create the FPGA bitstream.

Bug tracker
-----------

Have a bug? Please create an issue here on GitHub!

https://github.com/h1kari/desrtfpga/issues

Copyright
---------

Copyright 2017 David Hulton

Licensed under the BSD 3-Clause License: https://opensource.org/licenses/BSD-3-Clause
