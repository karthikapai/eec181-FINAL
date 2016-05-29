module reg32(clock, reset_n, D, byteenable,Q);

input [31:0] D;
input [3:0] byteenable;
input clock, reset_n;

output reg [31:0] Q;

always @ (posedge clock)
begin
	/*if (reset_n)
		begin
			Q = 32'h0000;
		end
	else begin*/
			if (byteenable[3])
			begin
				Q[31:24] <= D[31:24];
			end
			if (byteenable[2])
			begin
				Q[23:16] <= D[23:16];
			end
			if (byteenable[1])
			begin
				Q[15:8] <= D[15:8];
			end
			if (byteenable[0])
			begin
				Q[7:0] <= D[7:0];
			end
		//end
end
endmodule