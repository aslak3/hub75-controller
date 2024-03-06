module controller #(parameter BITS_PER_PIXEL=0)
    (
        input n_reset,
        input clk,
        output reg [1:0] hub75_red,
        output reg [1:0] hub75_green,
        output reg [1:0] hub75_blue,
        output [3:0] hub75_addr,
        output hub75_clk,
        output reg hub75_latch,
        output reg hub75_oe,
        input spi_clk,
        input spi_mosi,
        input spi_ss,
        output spi_miso,
        output reg user_led
    );

    localparam BITS_PER_PIXEL_CLOG2 = $clog2(BITS_PER_PIXEL);
    localparam BITS_PER_RGB = BITS_PER_PIXEL / 4;
    localparam BITS_PER_RGB_CLOG2 = $clog2(BITS_PER_RGB);

    reg [4:0] clk_counter;
    always @ (posedge clk) begin
        clk_counter <= clk_counter + 5'h1;
    end
    wire slow_clk = clk_counter[1];

    // reg reset = 1'b1;
    // reg [23:0] reset_counter = 24'h0;
    // always @ (posedge slow_clk) begin
    //     if (reset_counter != 24'hffffff) begin
    //         reset_counter <= reset_counter + 1;
    //     end else begin
    //          reset = ~n_reset;
    //     end
    // end

    wire reset = ~n_reset;

    wire [BITS_PER_PIXEL-1:0] write_data;
    wire write_pixel_clk;
    reg [10:0] write_addr; // top bit is the double-buffer flipper

    spi_slave #(BITS_PER_PIXEL) spi_slave (
        reset, spi_clk, spi_mosi, write_data, write_pixel_clk
    );

    always @ (posedge spi_ss, posedge write_pixel_clk) begin
        if (spi_ss == 1'b1) begin
            write_addr <= 11'b0;
        end else begin
            write_addr <= write_addr + 11'b1;
        end
    end

    reg [3:0] row_addr = 4'h0;
    reg [9:0] column_addr = 10'b0000000000;
    wire [9:0] read_addr = { row_addr, column_addr[5:0] };
    wire [BITS_PER_PIXEL-1:0] read_data_top;
    wire [BITS_PER_PIXEL-1:0] read_data_bottom;
    sync_pdp_ram #(BITS_PER_PIXEL) sync_pdp_ram (
        spi_ss,
        write_pixel_clk, write_addr, write_data, 1'b1,
        slow_clk, read_addr, read_data_top, read_data_bottom, 1'b1
    );

    localparam
        READ_STATE_PIXELS = 0,
        READ_STATE_SET_LATCH_DELAY = 1,
        READ_STATE_SET_LATCH = 2,
        READ_OE_STROBE = 3,
        READ_END_OF_ROW = 4,
        READ_STATE_NEXT_LINE = 5;
    integer read_state = READ_STATE_PIXELS;

    reg run_hub75_clk = 1'b0;
    integer bit_count = 0;
    reg [9:0] oe_strobe_column_addr;
    always @ (posedge reset, negedge slow_clk) begin
        if (reset == 1'b1) begin
            run_hub75_clk <= 1'b0;
            hub75_red <= 2'b00;
            hub75_green <= 2'b00;
            hub75_blue <= 2'b00;
            hub75_latch <= 1'b0;
            hub75_oe <= 1'b1;
            row_addr <= 4'b0000;
            column_addr <= 10'b0000000000;
            oe_strobe_column_addr <= 10'b0000011111;
        end else begin
            case (read_state)
                READ_STATE_PIXELS: begin
                    run_hub75_clk <= 1'b1;
                    hub75_red <= {
                        read_data_bottom[BITS_PER_RGB*3 + bit_count],
                        read_data_top[BITS_PER_RGB*3 + bit_count]
                    };
                    hub75_green <= {
                        read_data_bottom[BITS_PER_RGB*2 + bit_count],
                        read_data_top[BITS_PER_RGB*2 + bit_count]
                    };
                    hub75_blue <= {
                        read_data_bottom[BITS_PER_RGB*1 + bit_count],
                        read_data_top[BITS_PER_RGB*1 + bit_count]
                    };

                    column_addr <= column_addr + 10'b0000000001;
                    if (column_addr == 10'b0000111111) begin
                        read_state <= READ_STATE_SET_LATCH_DELAY;
                    end
                end

                READ_STATE_SET_LATCH_DELAY: begin
                    run_hub75_clk <= 1'b0;
                    read_state <= READ_STATE_SET_LATCH;
                end

                READ_STATE_SET_LATCH: begin
                    hub75_latch <= 1'b1;
                    column_addr <= 10'b0000000000;
                    read_state <= READ_OE_STROBE;
                end

                READ_OE_STROBE: begin
                    hub75_latch <= 1'b0;
                    hub75_oe <= 1'b0;
                    column_addr <= column_addr + 10'b0000000001;
                    if (column_addr == oe_strobe_column_addr) begin
                        hub75_oe <= 1'b1;
                        read_state <= READ_END_OF_ROW;
                    end
                end

                READ_END_OF_ROW: begin
                    bit_count <= bit_count + 1;
                    oe_strobe_column_addr <= { oe_strobe_column_addr[8:0], 1'b1 };
                    if (bit_count == BITS_PER_RGB - 1) begin
                        bit_count <= 0;
                        oe_strobe_column_addr <= 10'b0000011111;
                        row_addr <= row_addr + 4'h1; 
                    end
                    read_state <= READ_STATE_NEXT_LINE;
                end

                READ_STATE_NEXT_LINE: begin
                    column_addr <= 10'b0000000000;
                    read_state <= READ_STATE_PIXELS;
                end
            endcase
        end
    end

    wire _unused_ok = &{1'b0,
        read_data_bottom[3:0],
        read_data_top[3:0],
        1'b0};

    assign hub75_addr = row_addr;
    assign hub75_clk = run_hub75_clk ? slow_clk : 1'b0;
    assign spi_miso = 1'b0;

    // Just for testing
    reg [23:0] counter;
    always @ (posedge slow_clk) begin
        counter <= counter + 1;
    end
    assign user_led = counter[22];
endmodule
