// UtilFunc.sv

package UtilFunc;

    // function to compute ceil( log( x ) ) 
    // Note: log is computed in base 2
    function integer clogb2;
        input [31:0] value;
        begin
            value = value - 1;
            for (clogb2 = 0; value > 0; clogb2 = clogb2 + 1) begin
                value = value >> 1;
            end
        end
    endfunction

endpackage

