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
localparam WAIT_W1 =     6'd6;		
localparam IMGxW1 =  	 6'd7;	
localparam WAIT_ADD =    6'd8;	
localparam ADD =     	 6'd9;		
localparam B1_READ = 	 6'd10;		
localparam LOAD_B1 = 	 6'd11;
localparam ADD_BIAS =	 6'd12;
localparam WRITEBACK =	 6'd13;
localparam WRITE_COUNT = 6'd14;	
localparam CONTINUE =    6'd15;
localparam DONE = 		 6'd16;

localparam Z1_READ =	 6'd17;
localparam LOAD_Z1 =	 6'd18;	 	
localparam W2_READ = 	 6'd19;		
localparam LOAD_W2 = 	 6'd20;	
localparam Z1xW2 =  	 6'd21;	
localparam WAIT_ADD2 =   6'd22;	
localparam ADD2 =     	 6'd23;		
localparam B2_READ = 	 6'd24;		
localparam LOAD_B2 = 	 6'd25;
localparam ADD_BIAS2 =	 6'd26;
localparam WRITEBACK2 =	 6'd27;
localparam WRITE_COUNT2 =6'd28;	
localparam CONTINUE2 =   6'd39;
localparam DONE2 = 		 6'd30;



reg [31:0] dxwcount =0;  //up to 782, increment by 2
reg [31:0] img_count =0;  //up to 99, increment by 1
reg [31:0] node_count =0; //up to 199, increment by 1
reg [31:0] bias_count =0;
reg [31:0] wb_count =0;
reg [31:0] img_inc =0;
reg [31:0] w1_loadcount =0;
reg [31:0] pixel_count =0;
reg  add_finish = 0;
reg [5:0] state;
reg [5:0] nextstate = INITIAL;
reg [15:0] img;
reg [15:0] w11,w12,w13,w14;
reg signed [15:0] b1;
reg signed [15:0] mux0, mux1, mux2, mux3, mux4, mux5, mux6, mux7, mux8, mux9, mux10, mux11, mux12, mux13, mux14, mux15;
reg signed [15:0] out_add = 0;
//reg [15:0] final_add;


reg [31:0] IMG_address = 32'd0;       //base of img
reg [31:0] W1_address = 32'd40800;          //32'd157800;   //base of W1
reg [31:0] B1_address = 32'd40000;           //32'd157000;   //base of B1
reg [31:0] WB_address = 32'd143200;                     //32'd555400;   //base of write back 
reg [31:0] newIMG_address;
reg [31:0] newB1_address;
reg [31:0] newW1_address;

reg [31:0] Z1_address = 32'd143200; 
reg [31:0] W2_address = 32'd119200;
reg [31:0] B2_address = 32'd40400;
reg [31:0] WB2_address = 32'd183200;
reg [31:0] newZ1_address;
reg [31:0] newB2_address;
reg [31:0] newW2_address;

/*reg [31:0] Z2_address = 32'd300200;
reg [31:0] W3_address = 32'd139200;
reg [31:0] WB3_address = 32'd460200;
reg [31:0] newZ2_address;
reg [31:0] newW3_address;*/


// L2 control signal
reg [31:0] dxwcount2 =0;
reg [31:0] z1_count = 0;
reg [31:0] node_count2 = 0;
reg [31:0] bias_count2 = 0;
reg [31:0] wb_count2 = 0;
reg  add_finish2 = 0;
reg [15:0] w2;
reg [15:0] z1;
reg signed [15:0] b2;
reg signed [15:0] out_add2 = 0;
reg signed [15:0] mux20, mux21, mux22, mux23;



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
				if(SDRAM_readdatavalid)
					begin
					if(w1_loadcount == 3)
						nextstate = IMGxW1;
					else
						nextstate = WAIT_W1;
					end
				else
					nextstate = LOAD_W1;			
				end
		
		WAIT_W1: begin
				nextstate = W1_READ;
				end
				
		IMGxW1: begin
				nextstate = WAIT_ADD;
				end
		WAIT_ADD: begin
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
				nextstate = (pixel_count ==3) ? WRITEBACK: WRITE_COUNT;
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
				//nextstate = (start == 0) ? INITIAL : DONE;
				nextstate = Z1_READ;
			end
			
		////////////////////////// L2 state transition ////////////////////////
		
		Z1_READ: begin
				nextstate = (!SDRAM_waitrequest) ? LOAD_Z1 : Z1_READ;
				end
		
		LOAD_Z1: begin
				nextstate = (SDRAM_readdatavalid) ? W2_READ : LOAD_Z1;
				end
		
		W2_READ: begin
				nextstate = (!SDRAM_waitrequest) ? LOAD_W2 : W2_READ;
				end
				
		LOAD_W2: begin
					nextstate = (SDRAM_readdatavalid) ? Z1xW2 : LOAD_W2;
				end	
		
		Z1xW2: begin
				nextstate = WAIT_ADD2;
				end
				
		WAIT_ADD2: begin
				nextstate = ADD2;
				end
		
		ADD2: begin
				nextstate = (add_finish2) ? B2_READ : Z1_READ;
			 end
			 
		B2_READ: begin
				nextstate = (!SDRAM_waitrequest) ? LOAD_B2 : B2_READ;
				end
			
		LOAD_B2: begin
				nextstate =  (SDRAM_readdatavalid) ? ADD_BIAS2 : LOAD_B2;
				end
		
		ADD_BIAS2: begin
				nextstate = WRITEBACK2;
				end
			
		WRITEBACK2: begin
					nextstate = (SDRAM_waitrequest) ? WRITEBACK2 : WRITE_COUNT2;
					end
		WRITE_COUNT2: begin
					nextstate = CONTINUE2;
					end
		
		CONTINUE2: begin
				nextstate = (wb_count2 == 80000) ? DONE2 : Z1_READ;   //100*200
				end
		
		DONE2: begin
				nextstate = (start == 0) ? INITIAL : DONE2;//Z2_READ;
			end
	endcase
end

	
always @ (*) 
begin
	newIMG_address = (98*img_count) + img_inc;
	newW1_address = 40800 + (392*node_count) + dxwcount;
	newB1_address = 40000 + bias_count;
	
	newZ1_address = 143200 + (100*z1_count) + dxwcount2;
	newW2_address = 119200 + (100*node_count2) + dxwcount2;
	newB2_address = 40400 + bias_count2;
end	


always @ (*)
begin
	// L1
	if(state == IMG_READ)     //QUY
		SDRAM_address = IMG_address;
	if(state == W1_READ)
		SDRAM_address = W1_address;
	if(state == B1_READ)
		SDRAM_address = B1_address;
	if(state == WRITEBACK)
		SDRAM_address = WB_address;
/*	if(state == INITIAL || state == LOAD_IMG || state == LOAD_W1 || state == WAIT_W1)
		SDRAM_address = SDRAM_address;
	if(state == LOAD_B1 || state == IMGxW1 || state == WAIT_ADD || state == ADD)
		SDRAM_address = SDRAM_address;
	if(state == ADD_BIAS || state == WRITE_COUNT || state == CONTINUE || state == DONE)
		SDRAM_address = SDRAM_address;  */
	
	//L2
	if(state == Z1_READ)
		SDRAM_address = Z1_address;
	if(state == W2_READ)
		SDRAM_address = W2_address;
	if(state == B2_READ)
		SDRAM_address = B2_address;
	if(state == WRITEBACK2)
		SDRAM_address = WB2_address;
/*	if(state == LOAD_Z1 || state == LOAD_W2 || state == WAIT_Z1)
		SDRAM_address = SDRAM_address;
	if(state == LOAD_B2 || state == Z1xW2 || state == WAIT_ADD2 || state == ADD2)
		SDRAM_address = SDRAM_address;
	if(state == ADD_BIAS2 || state == WRITE_COUNT2 || state == CONTINUE2 || state == DONE2)
		SDRAM_address = SDRAM_address;  */
		
	if(state != IMG_READ && state != W1_READ && state != B1_READ && state != WRITEBACK && state != Z1_READ && state != W2_READ && state != B2_READ && state != WRITEBACK2 )
		SDRAM_address = SDRAM_address;
	
end

always @(*)
begin
	SDRAM_readn = (state == IMG_READ || state == W1_READ || state == B1_READ || state == Z1_READ || state == W2_READ || state == B2_READ) ? 0 : 1;   //QUY
	SDRAM_writen = (state == WRITEBACK || state == WRITEBACK2) ? 0 : 1;										//QUY
	done = (state == DONE2) ? 1 : 0;
	//SDRAM_writedata = final_add;

end


always @ (posedge clk)	
begin

	if(state == IMGxW1) begin
		mux0 <= (img[0] == 0) ? 0 : $signed(w11[3:0]);
		mux1 <= (img[1] == 0) ? 0 : $signed(w11[7:4]);
		mux2 <= (img[2] == 0) ? 0 : $signed(w11[11:8]);
		mux3 <= (img[3] == 0) ? 0 : $signed(w11[15:12]);
		
		mux4 <= (img[4] == 0) ? 0 : $signed(w12[3:0]);
		mux5 <= (img[5] == 0) ? 0 : $signed(w12[7:4]);
		mux6 <= (img[6] == 0) ? 0 : $signed(w12[11:8]);
		mux7 <= (img[7] == 0) ? 0 : $signed(w12[15:12]);
		
		mux8 <= (img[8] == 0) ? 0 : $signed(w13[3:0]);
		mux9 <= (img[9] == 0) ? 0 : $signed(w13[7:4]);
		mux10 <= (img[10] == 0) ? 0 : $signed(w13[11:8]);
		mux11 <= (img[11] == 0) ? 0 : $signed(w13[15:12]);
		
		mux12 <= (img[12] == 0) ? 0 : $signed(w14[3:0]);
		mux13 <= (img[13] == 0) ? 0 : $signed(w14[7:4]);
		mux14 <= (img[14] == 0) ? 0 : $signed(w14[11:8]);
		mux15 <= (img[15] == 0) ? 0 : $signed(w14[15:12]);
		
		end 
	else begin
		mux0 <= mux0;
		mux1 <= mux1;
		mux2 <= mux2;
		mux3 <= mux3;
		mux4 <= mux4;
		mux5 <= mux5;
		mux6 <= mux6;
		mux7 <= mux7;
		mux8 <= mux8;
		mux9 <= mux9;
		mux10 <= mux10;
		mux11 <= mux11;
		mux12 <= mux12;
		mux13 <= mux13;
		mux14 <= mux14;
		mux15 <= mux15;
		end

	if(state == ADD) 
		out_add <= out_add + mux0 + mux1 + mux2 + mux3 + mux4 + mux5 + mux6 + mux7 + mux8 + mux9 + mux10 + mux11 + mux12 + mux13 + mux14 + mux15;
	else if(state == WRITE_COUNT || state == DONE)
		out_add <= 0; 
	else 
		out_add <= out_add; 
		
	img <= (state == LOAD_IMG && SDRAM_readdatavalid) ? SDRAM_readdata : img;
	//w1 <= (state == LOAD_W1 && SDRAM_readdatavalid) ? SDRAM_readdata : w1;
	b1 <= (state == LOAD_B1 && SDRAM_readdatavalid) ? SDRAM_readdata : b1;
	
	
	if(state == LOAD_W1 && SDRAM_readdatavalid) begin
		case(w1_loadcount)
		0: w11 <= SDRAM_readdata;
		1: w12 <= SDRAM_readdata;
		2: w13 <= SDRAM_readdata;
		3: w14 <= SDRAM_readdata;
		endcase
	end
	else begin
		w11 <= w11;
		w12 <= w12;
		w13 <= w13;
		w14 <= w14;
	end
end



always @ (posedge clk)
begin
	if(state == W1_READ && SDRAM_waitrequest ==0)
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
		

	if(state == LOAD_W1 && SDRAM_readdatavalid ==1)
	begin
		if(w1_loadcount ==3)
			w1_loadcount <= 0;
		else 
			w1_loadcount <= w1_loadcount +1;
	end
	else if(state == DONE)
		w1_loadcount <= 0;
	else 
		w1_loadcount <= w1_loadcount;
end

/////////////////////////////////////////////////////////////	
always@(posedge clk)
begin
	if(state == IMGxW1) begin
		if(add_finish ==1)
			img_inc <= 0;
		else	
			img_inc <= img_inc +2; end
	else if(state == DONE)
		img_inc <= 0;
	else
		img_inc <= img_inc;
	

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
	
/*	if(state == WRITEBACK && !SDRAM_waitrequest)
		wb_count <= wb_count + 1;
	else if(state == DONE)
		wb_count <= 0;
	else
		wb_count <= wb_count; */
		
	if(state == ADD_BIAS) begin
			wb_count <= wb_count + 1;
			if(pixel_count == 3)
				pixel_count <= 0;
			else
				pixel_count <= pixel_count +1;
			end
	else if(state == DONE) begin
		wb_count <= 0;
		pixel_count <=0;
		end
	else begin
		wb_count <= wb_count;
		pixel_count <= pixel_count;
		end
end

always @(posedge clk)	
begin	
	
	if(state == WAIT_ADD || state == WRITE_COUNT)
		IMG_address <= newIMG_address;
	else if(state == DONE)
		IMG_address <= 32'd0;
	else
		IMG_address <= IMG_address;
	
	if((state == LOAD_W1 && SDRAM_readdatavalid ==1) || state == WRITE_COUNT)
		W1_address <= newW1_address;
	else if(state == DONE)
		W1_address <= 32'd40800;
	else 
		W1_address <= W1_address;
		
	if(state == ADD_BIAS)
		B1_address <= newB1_address;
	else if(state == DONE)
		B1_address <= 32'd40000; 
	else 
		B1_address <= B1_address;

	
	if(state == WRITEBACK && SDRAM_waitrequest == 0)
		WB_address <= (WB_address + 2);
	else if(state == DONE)
		WB_address <= 32'd143200;  
	else
		WB_address <= WB_address;
	
end	
	

/////////////////////////// Write Data ////////////////////////////////////////////////////////////////	
always @(posedge clk)
begin
	if(state == ADD_BIAS) begin
		case(pixel_count)
		0: SDRAM_writedata[3:0] <= ((out_add + b1)>= 0) ? 1 : 0;
		1: SDRAM_writedata[7:4] <= ((out_add + b1)>= 0) ? 1 : 0;
		2: SDRAM_writedata[11:8] <= ((out_add + b1)>= 0) ? 1 : 0;
		3: SDRAM_writedata[15:12] <= ((out_add + b1)>= 0) ? 1 : 0;
		endcase
		end
		
	//SDRAM_writedata <= (state == ADD_BIAS && (out_add + b1)>= 0) : SDRAM_writedata;
	if(state == ADD_BIAS2) begin
		if((out_add2 + b2)>= 0)
			SDRAM_writedata <= 1;
		else
			SDRAM_writedata <= 0;
		end
	
	if((state != ADD_BIAS) && (state != ADD_BIAS2))
		SDRAM_writedata <= SDRAM_writedata;
end



///////////////////////////////////////////////////////////////////////////////////////////////////////
//              L2 logic      
///////////////////////////////////////////////////////////////////////////////////////////////////////

always @ (posedge clk)	
begin

	if(state == Z1xW2) begin
		mux20 <= (z1[3:0] == 0) ? 0 : $signed(w2[3:0]);
		mux21 <= (z1[7:4] == 0) ? 0 : $signed(w2[7:4]);
		mux22 <= (z1[11:8] == 0) ? 0 : $signed(w2[11:8]);
		mux23 <= (z1[15:12] == 0) ? 0 : $signed(w2[15:12]);
		end 
	else begin
		mux20 <= mux20;
		mux21 <= mux21;
		mux22 <= mux22;
		mux23 <= mux23;
		end

	if(state == ADD2) 
		out_add2 <= out_add2 + mux20 + mux21 + mux22 + mux23;
	else if(state == WRITE_COUNT2 || state == DONE2)
		out_add2 <= 0; 
	else 
		out_add2 <= out_add2; 
		
	z1 <= (state == LOAD_Z1 && SDRAM_readdatavalid) ? SDRAM_readdata : z1;
	w2 <= (state == LOAD_W2 && SDRAM_readdatavalid) ? SDRAM_readdata : w2;
	b2 <= (state == LOAD_B2 && SDRAM_readdatavalid) ? SDRAM_readdata : b2;
	
end

always @ (posedge clk)
begin
	if(state == W2_READ && SDRAM_waitrequest ==0)
	begin
		if(dxwcount2 == 98) begin    //49*2
			add_finish2 <= 1;
			dxwcount2 <= 0; 
			end
		else begin
			add_finish2 <= 0;
			dxwcount2 <= dxwcount2 + 2;
			end	
	end
	else if(state == DONE2)
		begin
		add_finish2 <= 0;
		dxwcount2 <= 0;	
		end
	else begin
		add_finish2 <= add_finish2;
		dxwcount2 <= dxwcount2;
		end
end


/////////////////////////////////////////////////////////////	
always@(posedge clk)
begin

	if(state == ADD2 && add_finish2 == 1)
	begin
		if(node_count2 == 199) begin
			z1_count <= z1_count + 1;
			node_count2 <= 0;
			end 
		else begin
			z1_count <= z1_count;
			node_count2 <= node_count2 + 1;
			end
	end	
	else if(state == DONE2)
		begin
		z1_count <= 0;
		node_count2 <= 0;
		end
	else begin
		z1_count <= z1_count;
		node_count2 <= node_count2;
		end
		
	if(state == LOAD_B2 && SDRAM_readdatavalid)
	begin
		if(bias_count2 == 398)   //199*2
			bias_count2 <= 0;
		else
			bias_count2 <= bias_count2 + 2;
	end
	else if(state == DONE2)
		bias_count2 <= 0;
	else 
		bias_count2 <= bias_count2;
	
	if(state == WRITEBACK2 && !SDRAM_waitrequest)
		wb_count2 <= wb_count2 + 1;
	else if(state == DONE2)
		wb_count2 <= 0;
	else
		wb_count2 <= wb_count2; 
end


always@(posedge clk)	
begin	
	
	if(state == Z1xW2 || state == WRITE_COUNT2)
		Z1_address <= newZ1_address;
	else if(state == DONE2)
		Z1_address <= 32'd143200;
	else
		Z1_address <= Z1_address;
	
	if(state == Z1xW2 || state == WRITE_COUNT2)
		W2_address <= newW2_address;
	else if(state == DONE2)
		W2_address <= 32'd119200;
	else 
		W2_address <= W2_address;
		
	if(state == ADD_BIAS2)
		B2_address <= newB2_address;
	else if(state == DONE2)
		B2_address <= 32'd40400; 
	else 
		B2_address <= B2_address;

	
	if(state == WRITEBACK2 && SDRAM_waitrequest == 0)
		WB2_address <= (WB2_address + 2);
	else if(state == DONE2)
		WB2_address <= 32'd183200;  
	else
		WB2_address <= WB2_address;
	
end


endmodule


