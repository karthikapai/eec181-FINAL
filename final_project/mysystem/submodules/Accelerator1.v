module accelerator(
input clk,
input reset_n,
output reg SDRAM_readn,
output reg SDRAM_writen,
output SDRAM_chipselect,
input SDRAM_waitrequest,
output reg [31:0] SDRAM_address = 0,
output [1:0] SDRAM_byteenable,
input SDRAM_readdatavalid,
input [15:0] SDRAM_readdata,
output reg [15:0] SDRAM_writedata,
input start,
output reg done

);

assign SDRAM_chipselect = 1'b1;
assign SDRAM_byteenable = 2'b11;

// img base = 0
//weight base = 39200*2
//bias base = (78400+39200) * 2


localparam INITIAL =  8'b00000001;
localparam LOAD_IMG = 8'b00000010;
localparam LOAD_W1 =  8'b00000100;
localparam IMGxW1 =   8'b00001000;
localparam ADD =      8'b00010000;
localparam LOAD_B1 =  8'b00100000;
localparam ADD_BIAS = 8'b01000000;
localparam WRITEBACK =8'B10000000;


reg [9:0] dxwcount;  //up to 782, increment by 2
reg [9:0] img_count;  //up to 99, increment by 1
reg [9:0] node_count; //up to 199, increment by 1
reg [9:0] bias_count;
reg [15:0] wb_count;
reg [7:0] state = INITIAL;
reg [7:0] nextstate;
reg [15:0] img;
reg [15:0] w1;
reg [15:0] b1;
reg [15:0] mux;
reg [15:0] out_add = 0;
reg [15:0] final_add;
reg [1:0] flag = 0;

// Sequential current state logic
always @(posedge clk)
begin 
   if(reset_n==0) begin            // synchronous active low reset signal
	   state <= INITIAL;        // reset state is S1
	   //nextstate <= INITIAL;
	   end
	else
	   state <= nextstate; // if reset is off, go to nextstate
end




//next state logic
always @(*)
begin
	case(state)
		INITIAL: begin
				nextstate = (start) ? LOAD_IMG : INITIAL;
				end
		
		LOAD_IMG: begin
				nextstate = (!SDRAM_waitrequest && SDRAM_readdatavalid) ? LOAD_W1 : LOAD_IMG;
				end

		LOAD_W1: begin
				nextstate = (!SDRAM_waitrequest && SDRAM_readdatavalid) ? IMGxW1 : LOAD_W1;
				end
				
		IMGxW1: begin
				nextstate = ADD;
				end
				
		ADD: begin
			if(flag == 1)
				nextstate = LOAD_B1;
			else if (flag == 3)
				nextstate = ADD_BIAS;
			else 
				nextstate = LOAD_IMG;
			end
			
		LOAD_B1: begin
			nextstate =  (!SDRAM_waitrequest && SDRAM_readdatavalid) ? LOAD_IMG : LOAD_B1;
			end
			
		ADD_BIAS: begin
			nextstate = WRITEBACK;
			end
			
		WRITEBACK: begin
			if(!SDRAM_waitrequest && done) 
				nextstate = INITIAL;
			else if(!SDRAM_waitrequest && !done)
				nextstate = LOAD_IMG;
			else 
				nextstate = WRITEBACK;
		end
	endcase
end

//output logic 
always @(posedge clk)
begin
	case(nextstate)
		INITIAL: begin
				SDRAM_readn <= 1;
				SDRAM_writen <= 1;
				SDRAM_address <= 0;					
				dxwcount <= 0;  //up to 782, increment by 2
				img_count <= 0;  //up to 99, increment by 1
				node_count <= 0; //up to 199, increment by 1
				bias_count <= 0;
				wb_count <=0;
				flag <= 0;
				end

		LOAD_IMG: begin
				SDRAM_address <= (784*img_count) + dxwcount;   // addr of img
				SDRAM_readn <= 0;                             // turn on read
				SDRAM_writen <= 1;
				img <= SDRAM_readdata;                         // read img
				end
			
		LOAD_W1: begin
				SDRAM_address <= 79200 + (784*node_count + dxwcount);
				SDRAM_readn <= 0;
				SDRAM_writen <= 1;
				w1 <= SDRAM_readdata;
				end
				
		IMGxW1: begin
				SDRAM_readn <= 1;
				SDRAM_writen <= 1;
				if(img[0] == 0)
					mux[7:0] <= 0;
				else
					mux[7:0] <= w1[7:0];
					
				if(img[8] == 0)
					mux[15:8] <= 0;
				else
					mux[15:8] <= w1[15:8];
					
				end
				
		ADD: begin
			SDRAM_readn <= 1;
			SDRAM_writen <= 1;
			if(flag == 0) 
				out_add[15:8] <= out_add[15:8] + (mux[7:0] + mux[15:8]);  //first node
				
			if(flag == 2)
				out_add[7:0] <= out_add[7:0] + (mux[7:0] + mux[15:8]);    //second node
				
			dxwcount <= dxwcount + 2;
			
			if(dxwcount == 782) begin
				dxwcount <= 0;
				node_count <= node_count + 1; 
				flag <= flag + 1;
				end
				
			if(node_count == 199) begin
				node_count <= 0;
				bias_count <= 0;
				img_count <= img_count + 1;
			end	
			
			end	
			

		LOAD_B1: begin
				SDRAM_address <= 78600 + bias_count;
				bias_count <= bias_count + 2;
				SDRAM_readn <= 0;
				SDRAM_writen <= 1;
				b1 <= SDRAM_readdata;
				flag <= flag + 1;
				end
				
		ADD_BIAS: begin
				flag <= 0;
				final_add[15:8] <= out_add[15:8] + b1[15:8];
				final_add[7:0] <= out_add[7:0] + b1[7:0];
				SDRAM_readn <= 1;
				SDRAM_writen <= 1;
				end
		
		WRITEBACK: begin
				SDRAM_address <= 320000 + wb_count;
				SDRAM_writen <= 0;
				SDRAM_readn <= 1;
				SDRAM_writedata <= final_add;
				out_add <= 0;       //clear this reg to store the next 2 nodes
				if(!SDRAM_waitrequest)
					wb_count <= wb_count + 1;
				end
		
		endcase
			
end

always @(*)
begin
	if(wb_count == 100*100)
		done <= 1;
	else
		done <= 0;
end

/*always @(*)
begin
	if(node_count == 200) begin
		node_count = 0;
		bias_count = 0;
		img_count = img_count + 1;
	end
end*/

endmodule
