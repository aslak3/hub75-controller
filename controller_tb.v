module tb #(BITS_PER_PIXEL=0);
    reg n_reset;
    reg clk;
    wire [1:0] hub75_red;
    wire [1:0] hub75_green;
    wire [1:0] hub75_blue;
    wire [3:0] hub75_addr;
    wire hub75_latch;
    wire hub75_clk;
    wire hub75_oe;
    reg spi_clk;
    reg spi_mosi;
    reg spi_ss;
    reg spi_miso;
    reg user_led;

    reg [31:0] input_image [64 * 32];

    localparam period = 1;

    localparam BITS_PER_RGB = BITS_PER_PIXEL / 4;

    controller #(BITS_PER_PIXEL) dut (
        n_reset,
        clk,
        hub75_red,
        hub75_green,
        hub75_blue,
        hub75_addr,
        hub75_clk,
        hub75_latch,
        hub75_oe,
        spi_clk,
        spi_mosi,
        spi_ss,
        spi_miso,
        user_led
    );

    initial begin
        $dumpfile("controller.vcd");
        $dumpvars();

        n_reset = 1'b1;
        clk = 1'b0;
        spi_clk = 1'b0;
        spi_mosi = 1'b0;
        spi_ss = 1'b0;

        #period;
        n_reset = 1'b0;

        #period;
        n_reset = 1'b1;
    end

    integer write_buffer_count;
    integer write_pixel_count;
    integer write_bit_count;

    initial begin
        // Must be the 32bbp input image
        $readmemh("test-bars-32.txt", input_image);

        // Wait for the intial state to be done
        #(period * 10);

        spi_ss = 1'b0;

        // Feed the image in with SS set to 0
        for (write_pixel_count = 0; write_pixel_count < 64 * 32; write_pixel_count++) begin
            for (write_bit_count = 0; write_bit_count < 32; write_bit_count++) begin
                #period;
                spi_clk = 1'b0;
                spi_mosi = input_image[write_pixel_count][31 - write_bit_count];

                #period;
                spi_clk = 1'b1;
            end
        end

        // Now flip the SS to 1; the reader side will be reading what we just wrote
        #period;
        spi_ss = 1'b1;
        #period;

        // Drive the reader (display) clock forever, well until the end of the frame is reached
        forever begin
            clk = 1'b1;
            #period;

            clk = 1'b0;
            #period;
        end
    end

    reg [5:0] this_line_x = 6'b000000;
    reg [1:0] this_line_red[64];
    reg [1:0] this_line_green[64];
    reg [1:0] this_line_blue[64];

    // Pull in the individual rows into a local buffer (top and bottom at the same time)
    always @ (posedge hub75_clk) begin
        this_line_red[this_line_x] <= hub75_red;
        this_line_green[this_line_x] <= hub75_green;
        this_line_blue[this_line_x] <= hub75_blue;
        this_line_x <= this_line_x + 6'b000001;
    end

    reg [1:0] latched_line_red[64];
    reg [1:0] latched_line_green[64];
    reg [1:0] latched_line_blue[64];

    // Copy the current line into the latched line on the latched clock edge
    always @ (posedge clk) begin
        if (hub75_latch == 1'b1) begin
            for (integer x_count = 0; x_count < 64; x_count++) begin
                latched_line_red[x_count] <= this_line_red[x_count];
                latched_line_green[x_count] <= this_line_green[x_count];
                latched_line_blue[x_count] <= this_line_blue[x_count];
            end
        end
    end

    integer screen_red[64][32];
    integer screen_green[64][32];
    integer screen_blue[64][32];

    // Must init the screen memory as we add to it through the frame
    initial begin
        for (integer y_count = 0; y_count < 32; y_count++) begin
            for (integer x_count = 0; x_count < 64; x_count++) begin
                screen_red[x_count][y_count] = 0;
                screen_green[x_count][y_count] = 0;
                screen_blue[x_count][y_count] = 0;
            end
        end
    end

    always @ (posedge clk) begin
        if (hub75_oe == 1'b0) begin
            // Sum up the intensities when the Output Enable input is asserted
            for (integer x_count = 0; x_count < 64; x_count++) begin
                if (latched_line_red[x_count][0] == 1'b1) begin
                    screen_red[x_count][{1'b0, hub75_addr}] = screen_red[x_count][{1'b0, hub75_addr}] + 1;
                end
                if (latched_line_red[x_count][1] == 1'b1) begin
                    screen_red[x_count][{1'b1, hub75_addr}] = screen_red[x_count][{1'b1, hub75_addr}] + 1;
                end
                if (latched_line_green[x_count][0] == 1'b1) begin
                    screen_green[x_count][{1'b0, hub75_addr}] = screen_green[x_count][{1'b0, hub75_addr}] + 1;
                end
                if (latched_line_green[x_count][1] == 1'b1) begin
                    screen_green[x_count][{1'b1, hub75_addr}] = screen_green[x_count][{1'b1, hub75_addr}] + 1;
                end
                if (latched_line_blue[x_count][0] == 1'b1) begin
                    screen_blue[x_count][{1'b0, hub75_addr}] = screen_blue[x_count][{1'b0, hub75_addr}] + 1;
                end
                if (latched_line_blue[x_count][1] == 1'b1) begin
                    screen_blue[x_count][{1'b1, hub75_addr}] = screen_blue[x_count][{1'b1, hub75_addr}] + 1;
                end
            end
        end
    end

    // Watch for the top addr bit going low, this indicates the end of the frame
    always @ (negedge hub75_addr[3]) begin
        for (integer y_count = 0; y_count < 32; y_count++) begin
            for (integer x_count = 0; x_count < 64; x_count++) begin
                // Output the RGB of each pixel in unscaled form, which will turn back into a BMP by scaling
                // such that the maximum intensity of any pixels R, G or B will be 255
                $display("%0d,%0d,%0d", screen_red[x_count][y_count], screen_green[x_count][y_count],
                    screen_blue[x_count][y_count]);
            end
        end
        $finish();
    end
endmodule
