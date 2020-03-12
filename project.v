// LEDR[5:0] displays the current state in the FSM
// KEY[0] is the reset switch

// ADDITIONAL TODO: Refactor the FSM code so its not just one whole module where the game runs?
module proj(
		CLOCK_50,						//	On Board 50 MHz
		// Your inputs and outputs here
        KEY,
		LEDR,
		// The ports below are for the VGA output.  Do not change.
		VGA_CLK,   						//	VGA Clock
		VGA_HS,							//	VGA H_SYNC
		VGA_VS,							//	VGA V_SYNC
		VGA_BLANK_N,						//	VGA BLANK
		VGA_SYNC_N,						//	VGA SYNC
		VGA_R,   						//	VGA Red[9:0]
		VGA_G,	 						//	VGA Green[9:0]
		VGA_B   						//	VGA Blue[9:0]
	);

	input CLOCK_50;
	input [3:0] KEY;
	output [17:0] LEDR;

	// Declare your inputs and outputs here
	// Do not change the following outputs
	output			VGA_CLK;   				//	VGA Clock
	output			VGA_HS;					//	VGA H_SYNC
	output			VGA_VS;					//	VGA V_SYNC
	output			VGA_BLANK_N;				//	VGA BLANK
	output			VGA_SYNC_N;				//	VGA SYNC
	output	[9:0]	VGA_R;   				//	VGA Red[9:0]
	output	[9:0]	VGA_G;	 				//	VGA Green[9:0]
	output	[9:0]	VGA_B;   				//	VGA Blue[9:0]
    

	// VGA Controller
	vga_adapter VGA(
			.resetn(1'b1),
			.clock(CLOCK_50),
			.colour(colour),
			.x(x),
			.y(y),
			.plot(1'b1),
			/* Signals for the DAC to drive the monitor. */
			.VGA_R(VGA_R),
			.VGA_G(VGA_G),
			.VGA_B(VGA_B),
			.VGA_HS(VGA_HS),
			.VGA_VS(VGA_VS),
			.VGA_BLANK(VGA_BLANK_N),
			.VGA_SYNC(VGA_SYNC_N),
			.VGA_CLK(VGA_CLK));
		defparam VGA.RESOLUTION = "160x120";
		defparam VGA.MONOCHROME = "FALSE";
		defparam VGA.BITS_PER_COLOUR_CHANNEL = 1;
		defparam VGA.BACKGROUND_IMAGE = "black.mif";
	 

	reg [5:0] state;
	reg [3:0] state2;
	// Set of x and y coordinates that are directly sent to the VGA to draw/update, note that x and y have to constantly swap between
	// paddle, ball, and blocks
	reg [7:0] x, y;
	// Coordinates for each object on the screen, currently has 5 block coordinate vars, can add more if needed.
	reg [7:0] p_x, p_y, b_x, b_y, bl_1_x, bl_1_y, bl_2_x, bl_2_y, bl_3_x, bl_3_y, bl_4_x, bl_4_y, bl_5_x, bl_5_y;
	reg [2:0] colour;
	// 1 bit vars to keep track of which direction (up down, left right) the ball is heading
	reg b_x_direction, b_y_direction;
	reg [17:0] draw_counter;
	reg [2:0] block_1_colour, block_2_colour, block_3_colour, block_4_colour, block_5_colour;
	// Better name, or the more familiar name that we have for this is the "enable" in LAB4, is 1 when rate_divider == 0
	wire frame;
	// store coordinates reading from text
	wire [79:0] data;
    wire i;
	wire [3:0] done_reading;

	assign LEDR[5:0] = state;
	 
	// States in the FSM
	localparam RESET_BLACK       = 6'b000000,
			INIT_PADDLE       = 6'b000001,
			INIT_BALL         = 6'b000010,
			INIT_BLOCK_1      = 6'b000011,
			INIT_BLOCK_2      = 6'b000100,
			INIT_BLOCK_3      = 6'b000101,
			INIT_BLOCK_4      = 6'b000110,
			INIT_BLOCK_5      = 6'b000111,
			IDLE              = 6'b001000,
			ERASE_PADDLE	  = 6'b001001,
			UPDATE_PADDLE     = 6'b001010,
			DRAW_PADDLE 	  = 6'b001011,
			ERASE_BALL        = 6'b001100,
			UPDATE_BALL       = 6'b001101,
			DRAW_BALL         = 6'b001110,
			UPDATE_BLOCK_1    = 6'b001111,
			DRAW_BLOCK_1      = 6'b010000,
			UPDATE_BLOCK_2    = 6'b010001,
			DRAW_BLOCK_2      = 6'b010010,
			UPDATE_BLOCK_3    = 6'b010011,
			DRAW_BLOCK_3      = 6'b010100,
			UPDATE_BLOCK_4    = 6'b010101,
			DRAW_BLOCK_4      = 6'b010110,
			UPDATE_BLOCK_5    = 6'b010111,
			DRAW_BLOCK_5      = 6'b011000,
			DEAD    		  = 6'b011001;

	// Instantiate a module to update the game 60 times each second
	clock c0(
		.clock(CLOCK_50), 
		.clk(frame)
		);

    read_text t1(
		.clock(CLOCK_50),
		.reset(resetn),
		.out(data)
	);

    new_blocks new1(.bl_1_x(bl_1_x),
	                .bl_1_y(bl_1_y),
					.bl_2_x(bl_2_x), 
					.bl_2_y(bl_2_y), 
					.bl_3_x(bl_3_x), 
					.bl_3_y(bl_3_y), 
					.bl_4_x(bl_4_x), 
					.bl_4_y(bl_4_y), 
					.bl_5_x(bl_5_x), 
					.bl_5_y(bl_5_y),
					.clock(CLOCK_50),
					.state2(state2),
					.i(i),
					.done_reading(done_reading),
					.data(data)
	               );

	assign LEDR[7] = ((b_y_direction) && (b_y > p_y - 8'd1) && (b_y < p_y + 8'd2) && (b_x >= p_x) && (b_x <= p_x + 8'd8));

	always@(posedge CLOCK_50)
    	begin
			colour = 3'b000;
			x = 8'b00000000;
			y = 8'b00000000;
			if (~KEY[0]) 
				state = RESET_BLACK;
			// FSM
			case (state)
				RESET_BLACK: begin
					if (draw_counter < 17'b10000000000000000) begin
						x = draw_counter[7:0];
						y = draw_counter[16:8];
						draw_counter = draw_counter + 1'b1;
					end
					else begin
						draw_counter= 8'b00000000;
						state = INIT_PADDLE;
					end
				end
				// Whole lotta initialization here
				INIT_PADDLE: begin
					if (draw_counter < 6'b10000) begin
						p_x = 8'd76;
						p_y = 8'd110;
						x = p_x + draw_counter[3:0];
						y = p_y + draw_counter[4];
						draw_counter = draw_counter + 1'b1;
						colour = 3'b111;
					end
					else begin
						draw_counter= 8'b00000000;
						state = INIT_BALL;
					end
				end
				INIT_BALL: begin
					b_x = 8'd80;
					b_y = 8'd108;
					x = b_x;
					y = b_y;
					colour = 3'b111;
					state = INIT_BLOCK_1;
				end
				INIT_BLOCK_1: begin
					bl_1_x = 8'd15;
					bl_1_y = 8'd30;
					block_1_colour = 3'b010;
						state = INIT_BLOCK_2;
				end
				INIT_BLOCK_2: begin
					bl_2_x = 8'd45;
					bl_2_y = 8'd30;
					block_2_colour = 3'b010;
						state = INIT_BLOCK_3;
				end
				INIT_BLOCK_3: begin
					bl_3_x = 8'd75;
					bl_3_y = 8'd30;
					block_3_colour = 3'b010;
						state = INIT_BLOCK_4;
				end
				INIT_BLOCK_4: begin
					bl_4_x = 8'd105;
					bl_4_y = 8'd30;
					block_4_colour = 3'b010;
						state = INIT_BLOCK_5;
				end
				INIT_BLOCK_5: begin
					bl_5_x = 8'd135;
					bl_5_y = 8'd30;
					block_5_colour = 3'b010;
						state = IDLE;
				end
				IDLE: begin
					// Frame is the rateDivider, when the rate divider hits 0, begin updating the game
					if (frame)
						state = ERASE_PADDLE;
					end
				ERASE_PADDLE: begin
					if (draw_counter < 6'b100000) begin
						x = p_x + draw_counter[3:0];
						y = p_y + draw_counter[4];
						draw_counter = draw_counter + 1'b1;
					end
					else begin
						draw_counter= 8'b00000000;
						state = UPDATE_PADDLE;
					end
				end
				UPDATE_PADDLE: begin
					if (~KEY[1] && p_x < 8'd144)
						p_x = p_x + 1'b1;
					if (~KEY[2] && p_x > 8'd0)
						p_x = p_x - 1'b1;

					state = DRAW_PADDLE;
				end
				DRAW_PADDLE: begin
					if (draw_counter < 6'b100000) begin
						x = p_x + draw_counter[3:0];
						y = p_y + draw_counter[4];
						draw_counter = draw_counter + 1'b1;
						colour = 3'b111;
					end
					else begin
						draw_counter= 8'b00000000;
						state = ERASE_BALL;
					end
				end
				ERASE_BALL: begin
					x = b_x;
					y = b_y;
					state = UPDATE_BALL;
				end
				UPDATE_BALL: begin
					// Move the ball by incrementing its direction
					if (~b_x_direction) 
						b_x = b_x + 1'b1;
					else 
						b_x = b_x - 1'b1;

					if (b_y_direction) 
						b_y = b_y + 1'b1;
					else 
						b_y = b_y - 1'b1;

					// Screen is 160px wide (x), therefore reverse x's direction if we hit a boundary
					if ((b_x == 8'd0) || (b_x == 8'd160)) 
						b_x_direction = ~b_x_direction;
					
					// Check if we hit the paddle, this is where we need to increment the counter
					if ((b_y == 8'd0) || ((b_y_direction) && (b_y > p_y - 8'd1) && (b_y < p_y + 8'd2) && (b_x >= p_x) && (b_x <= p_x + 8'd15)))
						b_y_direction = ~b_y_direction;
					// If we hit the bottom of the screen, the ball is dead, else continue drawing the ball
					if (b_y >= 8'd120) 
						state = DEAD;
					else 
						state = DRAW_BALL;
				end
				// Just updating the ball's coordinates here, nothing special
				DRAW_BALL: begin
					x = b_x;
					y = b_y;
					colour = 3'b111;
					state = UPDATE_BLOCK_1;
				end
				// TODO: THIS IS WHERE WE SHOULD REDRAW THE BLOCKS BY UPDATING THEIR Y COORD TO GO DOWN
				UPDATE_BLOCK_1: begin
					// Unit collision code
					// If the block's colour is not black, means it is still active, then check if the ball is inside the block's boundaries
					if ((block_1_colour != 3'b000) && (b_y > bl_1_y - 8'd1) && (b_y < bl_1_y + 8'd2) && (b_x >= bl_1_x) && (b_x <= bl_1_x + 8'd7)) begin
						// If collision detected, block should be set the black, meaning its been hit
						b_y_direction = ~b_y_direction;
						block_1_colour = 3'b000;
						// NOTE: WITH THIS CODE, WE CAN EASILY SET UP BLOCKS TO TAKE MULTIPLE HITS, BY CHANGING THE COLOUR
					end
					state = DRAW_BLOCK_1;
				end
				DRAW_BLOCK_1: begin
					// draw counter represents the loop to fill the block's rectangle
					if (draw_counter < 5'b10000) begin
						x = bl_1_x + draw_counter[2:0];
						y = bl_1_y + draw_counter[3];
						draw_counter = draw_counter + 1'b1;
						colour = block_1_colour;
					end
					else begin
						draw_counter= 8'b00000000;
						state = UPDATE_BLOCK_2;
					end
				end
				UPDATE_BLOCK_2: begin
					if ((block_2_colour != 3'b000) && (b_y > bl_2_y - 8'd1) && (b_y < bl_2_y + 8'd2) && (b_x >= bl_2_x) && (b_x <= bl_2_x + 8'd7)) begin
						b_y_direction = ~b_y_direction;
						block_2_colour = 3'b000;
					end
					state = DRAW_BLOCK_2;
				end
				DRAW_BLOCK_2: begin
					if (draw_counter < 5'b10000) begin
						x = bl_2_x + draw_counter[2:0];
						y = bl_2_y + draw_counter[3];
						draw_counter = draw_counter + 1'b1;
						colour = block_2_colour;
						end
					else begin
						draw_counter= 8'b00000000;
						state = UPDATE_BLOCK_3;
					end
				end
				UPDATE_BLOCK_3: begin
					if ((block_3_colour != 3'b000) && (b_y > bl_3_y - 8'd1) && (b_y < bl_3_y + 8'd2) && (b_x >= bl_3_x) && (b_x <= bl_3_x + 8'd7)) begin
						b_y_direction = ~b_y_direction;
						block_3_colour = 3'b000;
					end
					state = DRAW_BLOCK_3;
				end
				DRAW_BLOCK_3: begin
					if (draw_counter < 5'b10000) begin
						x = bl_3_x + draw_counter[2:0];
						y = bl_3_y + draw_counter[3];
						draw_counter = draw_counter + 1'b1;
						colour = block_3_colour;
					end
					else begin
						draw_counter= 8'b00000000;
						state = UPDATE_BLOCK_4;
					end
				end
				UPDATE_BLOCK_4: begin
					if ((block_4_colour != 3'b000) && (b_y > bl_4_y - 8'd1) && (b_y < bl_4_y + 8'd2) && (b_x >= bl_4_x) && (b_x <= bl_4_x + 8'd7)) begin
						b_y_direction = ~b_y_direction;
						block_4_colour = 3'b000;
					end
					state = DRAW_BLOCK_4;
				end
				DRAW_BLOCK_4: begin
					if (draw_counter < 5'b10000) begin
						x = bl_4_x + draw_counter[2:0];
						y = bl_4_y + draw_counter[3];
						draw_counter = draw_counter + 1'b1;
						colour = block_4_colour;
						end
					else begin
						draw_counter= 8'b00000000;
						state = UPDATE_BLOCK_5;
					end
				end
				UPDATE_BLOCK_5: begin
					if ((block_5_colour != 3'b000) && (b_y > bl_5_y - 8'd1) && (b_y < bl_5_y + 8'd2) && (b_x >= bl_5_x) && (b_x <= bl_5_x + 8'd7)) begin
						b_y_direction = ~b_y_direction;
						block_5_colour = 3'b000;
					end
					state = DRAW_BLOCK_5;
				end
				DRAW_BLOCK_5: begin
					if (draw_counter < 5'b10000) begin
						x = bl_5_x + draw_counter[2:0];
						y = bl_5_y + draw_counter[3];
						draw_counter = draw_counter + 1'b1;
						colour = block_5_colour;
						end
					else begin
						draw_counter= 8'b00000000;
						state = IDLE;
					end
				end
				DEAD: begin
					if (draw_counter < 17'b10000000000000000) begin
						x = draw_counter[7:0];
						y = draw_counter[16:8];
						draw_counter = draw_counter + 1'b1;
						colour = 3'b100;
					end
				end
         	endcase
    	end
endmodule

module clock(input clock, output clk);
	reg [19:0] frame_counter;
	reg frame;
	always@(posedge clock)
    begin
        if (frame_counter == 20'b00000000000000000000) begin
			// This is the number 833,332 - meaning with a 50MHz clock, frame is set to 1 60 times, VGA is updating at 60hz
			frame_counter = 20'b11001011011100110100;
			frame = 1'b1;
		end
        else begin
			frame_counter = frame_counter - 1'b1;
			frame = 1'b0;
		end
    end
	assign clk = frame;
endmodule

module new_blocks(clock, bl_1_x, bl_1_y, bl_2_x, bl_2_y, bl_3_x, bl_3_y, bl_4_x, bl_4_y, bl_5_x, bl_5_y, state2, i, data);
	input clock;
	input [79:0] data;
	input i;
	input [3:0] state2;
	output [7:0] bl_1_x, bl_1_y, bl_2_x, bl_2_y, bl_3_x, bl_3_y, bl_4_x,bl_4_y, bl_5_x, bl_5_y;

	// States in the FSM
	localparam 
	           LD_BL_1_X = 4'b0001,
			   LD_BL_1_Y = 4'b0010,
			   LD_BL_2_X = 4'b0011,
			   LD_BL_2_Y = 4'b0100,
			   LD_BL_3_X = 4'b0101,
			   LD_BL_3_Y = 4'b0110,
			   LD_BL_4_X = 4'b0111,
			   LD_BL_4_Y = 4'b1000,
			   LD_BL_5_X = 4'b1001,
			   LD_BL_5_Y = 4'b1010,
	           FINISH_READING = 4'b1011;

always@(posedge clock) begin
	if(i == 1'b0) begin
		case (state2)

			LD_BL_1_X: begin
			bl_1_x <= data [7:0];
			state2 = LD_BL_1_Y;
			end

			LD_BL_1_Y: begin 
			bl_1_y = data [15:8];
			state2 = LD_BL_2_X;
			end 

			LD_BL_2_X: begin
			bl_2_x = data [23:16];
			state2 = LD_BL_2_Y;
			end

			LD_BL_2_Y: begin
			bl_2_y = data [31:24];
			state2 = LD_BL_3_X;
			end

			LD_BL_3_X: begin
			bl_3_x = data [39:32];
			state2 = LD_BL_3_Y;
			end 

			LD_BL_3_Y: begin
			bl_3_y = data [47:40];
			state2 = LD_BL_4_X;
			end 

			LD_BL_4_X: begin
			bl_4_x = data [55:48];
			state2 = LD_BL_4_Y;
			end 

			LD_BL_4_Y: begin
			bl_4_y = data [63:56];
			state2 = LD_BL_5_X;
			end 

			LD_BL_5_X: begin
			bl_4_x = data [71:64];
			state2 = LD_BL_5_Y;
			end 
			LD_BL_5_Y: begin
			bl_5_y = data [79:72];
			state = FINISH_READING;
			end 

			FINISH_READING: begin
			i = 1'b1;
			end
		endcase
  	end
end
endmodule


module read_text(reset,clock, out);
	input  reset, clock;
	output [79:0] out;
	reg [79:0] x;
    reg i;
	reg [79:0] mem [0:159];

	initial          
		$readmemb("I:\my_data_x.txt", mem);

    always@(posedge clock)
    begin
        if(reset)
            begin
                x = 0;
				i = 0;
            end
        else 
            begin
                x = mem[i];
                i=i+1;
            end
    end

	assign out[79:0] = x [79:0];

endmodule