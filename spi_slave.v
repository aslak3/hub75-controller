module spi_slave #(parameter BITS_PER_PIXEL=0)
    (
        input reset,
        input spi_clk,
        input spi_mosi,
        output [BITS_PER_PIXEL-1:0] data,
        output pixel_clk
    );

    localparam BITS_PER_RGB = BITS_PER_PIXEL / 4;

    reg [31:0] tmp_data = 32'b0;
    reg [4:0] bit_counter = 5'b0;

    always @ (posedge reset, posedge spi_clk) begin
        if (reset == 1'b1) begin
            bit_counter <= 5'b11111;
        end else begin
            tmp_data[bit_counter] <= spi_mosi;
            bit_counter <= bit_counter - 5'b00001;
        end
    end

    assign data = { tmp_data[4*8-1:(4*8)-BITS_PER_RGB],
                    tmp_data[3*8-1:(3*8)-BITS_PER_RGB],
                    tmp_data[2*8-1:(2*8)-BITS_PER_RGB],
                    tmp_data[1*8-1:(1*8)-BITS_PER_RGB]
    };
    assign pixel_clk = bit_counter[4];

endmodule
