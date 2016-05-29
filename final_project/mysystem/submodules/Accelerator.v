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
output reg done =0

);

assign SDRAM_chipselect = 1'b1;
assign SDRAM_byteenable = 2'b11;

// img base = 0
//weight base = 39200*2
//bias base = (78400+39200) * 2


localparam INITIAL = 	 6'd1;   
localparam IMG_READ =	 6'd2;
localparam LOAD_IMG =	 6'd3;	 	
localparam W1_READ = 	 6'd4;		
localparam LOAD_W1 = 	 6'd5;		
localparam IMGxW1 =  	 6'd6;		
localparam ADD =     	 6'd7;		
localparam B1_READ = 	 6'd8;		
localparam LOAD_B1 = 	 6'd9;
localparam ADD_BIAS =	 6'd10;
localparam WRITEBACK =	 6'd11;
localparam WRITE_COUNT = 6'd12;	
localparam CONTINUE =    6'd13;
localparam DONE = 		 6'd14;



reg [31:0] dxwcount =0;  //up to 782, increment by 2
reg [31:0] img_count =0;  //up to 99, increment by 1
reg [31:0] node_count =0; //up to 199, increment by 1
reg [31:0] bias_count =0;
reg [31:0] wb_count =0;
reg [5:0] state;
reg [5:0] nextstate = INITIAL;
reg [15:0] img;
reg [15:0] w1;
reg signed [15:0] b1;
reg signed [15:0] mux1, mux2, mux3, mux4;
reg signed [15:0] out_add = 0;
reg [15:0] final_add;
reg  add_finish = 0;

reg [31:0] IMG_address = 32'd0;       //base of img
reg [31:0] W1_address = 32'd158400;          //32'd157800;   //base of W1
reg [31:0] B1_address = 32'd157600;           //32'd157000;   //base of B1
reg [31:0] WB_address = 32'd320800;                     //32'd555400;   //base of write back 
reg [31:0] newIMG_address;
reg [31:0] newB1_address;
reg [31:0] newW1_address;


// Sequential current state logic
always @(posedge clk)
begin 
	state <= nextstate; 
end


//next state logic
always @(*)
begin
	case(state)
		INITIAL: begin
				nextstate = (start) ? IMG_READ : INITIAL;
				end
				
		IMG_READ: begin
				nextstate = (!SDRAM_waitrequest) ? LOAD_IMG : IMG_READ;
				end
		
		LOAD_IMG: begin
				nextstate = (SDRAM_readdatavalid) ? W1_READ : LOAD_IMG;
				end

		W1_READ: begin
				nextstate = (!SDRAM_waitrequest) ? LOAD_W1 : W1_READ;
				end
				
		LOAD_W1: begin
				nextstate = (SDRAM_readdatavalid) ? IMGxW1 : LOAD_W1;			
				end
				
		IMGxW1: begin
				nextstate = ADD;
				end
				
		ADD: begin
				nextstate = (add_finish) ? B1_READ : IMG_READ;
			 end
		
		B1_READ: begin
				nextstate = (!SDRAM_waitrequest) ? LOAD_B1 : B1_READ;
				end
			
		LOAD_B1: begin
				nextstate =  (SDRAM_readdatavalid) ? ADD_BIAS : LOAD_B1;
				end
			
		ADD_BIAS: begin
				nextstate = WRITEBACK;
				end
			
		WRITEBACK: begin
					nextstate = (SDRAM_waitrequest) ? WRITEBACK : WRITE_COUNT;
					end
		WRITE_COUNT: begin
					nextstate = CONTINUE;
					end
		
		CONTINUE: begin
				nextstate = (wb_count == 80000) ? DONE : IMG_READ;   //100*200
				end
		
		DONE: begin
				nextstate = (start == 0) ? INITIAL : DONE;
			end
		
	endcase
end

	
always @ (*) 
begin
	newIMG_address = (392*img_count) + dxwcount;
	newW1_address = 158400 + (392*node_count) + dxwcount;
	newB1_address = 157600 + bias_count;
end	


always @ (*)
begin
	if(state == IMG_READ)
		SDRAM_address = IMG_address;
	if(state == W1_READ)
		SDRAM_address = W1_address;
	if(state == B1_READ)
		SDRAM_address = B1_address;
	if(state == WRITEBACK)
		SDRAM_address = WB_address;
	if(state == INITIAL || state == LOAD_IMG || state == LOAD_W1)
		SDRAM_address = SDRAM_address;
	if(state == LOAD_B1 || state == IMGxW1 || state == ADD)
		SDRAM_address = SDRAM_address;
	if(state == ADD_BIAS || state == WRITE_COUNT || state == CONTINUE || state == DONE)
		SDRAM_address = SDRAM_address;
end

always @(*)
begin
	SDRAM_readn = (state == IMG_READ || state == W1_READ || state == B1_READ) ? 0 : 1;
	SDRAM_writen = (state == WRITEBACK) ? 0 : 1;
	done = (state == DONE) ? 1 : 0;
	//SDRAM_writedata = final_add;

end


always @ (posedge clk)	
begin

	if(state == IMGxW1) begin
		mux1 <= (img[3:0] == 0) ? 0 : $signed(w1[3:0]);
		mux2 <= (img[7:4] == 0) ? 0 : $signed(w1[7:4]);
		mux3 <= (img[11:8] == 0) ? 0 : $signed(w1[11:8]);
		mux4 <= (img[15:12] == 0) ? 0 : $signed(w1[15:12]);
		
	/*	if(img == 0)               
			mux <= 0; 
		else
			mux <= w1;*/
		end 
	else begin
		mux1 <= mux1;
		mux2 <= mux2;
		mux3 <= mux3;
		mux4 <= mux4;
		end

	if(state == ADD) 
		out_add <= out_add + mux1 + mux2 + mux3 + mux4;
	else if(state == WRITE_COUNT || state == DONE)
		out_add <= 0; 
	else 
		out_add <= out_add; 
		
	img <= (state == LOAD_IMG && SDRAM_readdatavalid) ? SDRAM_readdata : img;
	w1 <= (state == LOAD_W1 && SDRAM_readdatavalid) ? SDRAM_readdata : w1;
	b1 <= (state == LOAD_B1 && SDRAM_readdatavalid) ? SDRAM_readdata : b1;
	SDRAM_writedata <= (state == ADD_BIAS) ? (out_add + b1) : SDRAM_writedata;
end



always @ (posedge clk)
begin
	if(state == LOAD_W1 && SDRAM_readdatavalid)
	begin
		if(dxwcount == 390) begin    //195*2
			add_finish <= 1;
			dxwcount <= 0; 
			end
		else begin
			add_finish <= 0;
			dxwcount <= dxwcount + 2;
			end	
	end
	else if(state == DONE)
		begin
		add_finish <= 0;
		dxwcount <= 0;	
		end
	else begin
		add_finish <= add_finish;
		dxwcount <= dxwcount;
		end

		
	if(state == ADD && add_finish == 1)
	begin
		if(node_count == 199) begin
			img_count <= img_count + 1;
			node_count <= 0;
			end 
		else begin
			img_count <= img_count;
			node_count <= node_count + 1;
			end
	end	
	else if(state == DONE)
		begin
		img_count <= 0;
		node_count <= 0;
		end
	else begin
		img_count <= img_count;
		node_count <= node_count;
		end
		
	if(state == LOAD_B1 && SDRAM_readdatavalid)
	begin
		if(bias_count == 398)   //199*2
			bias_count <= 0;
		else
			bias_count <= bias_count + 2;
	end
	else if(state == DONE)
		bias_count <= 0;
	else 
		bias_count <= bias_count;
	
	if(state == WRITEBACK && !SDRAM_waitrequest)
		wb_count <= wb_count + 1;
	else if(state == DONE)
		wb_count <= 0;
	else
		wb_count <= wb_count;
end

always @(posedge clk)	
begin	
	
	if(state == IMGxW1 || state == WRITE_COUNT)
		IMG_address <= newIMG_address;
	else if(state == DONE)
		IMG_address <= 32'd0;
	else
		IMG_address <= IMG_address;
	
	if(state == IMGxW1 || state == WRITE_COUNT)
		W1_address <= newW1_address;
	else if(state == DONE)
		W1_address <= 32'd158400;
	else 
		W1_address <= W1_address;
		
	if(state == ADD_BIAS)
		B1_address <= newB1_address;
	else if(state == DONE)
		B1_address <= 32'd157600; 
	else 
		B1_address <= B1_address;

	
	if(state == WRITEBACK && SDRAM_waitrequest == 0)
		WB_address <= (WB_address + 2);
	else if(state == DONE)
		WB_address <= 32'd320800;  
	else
		WB_address <= WB_address;
	
end	
	//IMG_address <= (state == IMGxW1 || state == WRITE_COUNT) ? newIMG_address : IMG_address;
	//W1_address <= (state == IMGxW1 || state == WRITE_COUNT) ?  newW1_address : W1_address;
	//B1_address <= (state == ADD_BIAS) ? newB1_address : B1_address;
	//WB_address <= (state == WRITEBACK && SDRAM_waitrequest == 0) ? (WB_address + 2) : WB_address;
	


endmodule


