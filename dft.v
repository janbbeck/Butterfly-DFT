module dft(
	clk,        
	reset,
	dft_start,
	dft_done,
	wenr,    
	weni,     
	cenr,     
	ceni,     
	addrr,    
	addri,    
	dr,       
	di,       
	qr,       
	qi        );  

input           clk;        
input           reset;
input	        dft_start;
output	        dft_done;
output	        wenr;    
output	        weni;     
output	        cenr;     
output	        ceni;     
output [7:0]	addrr;    
output [7:0]	addri;    
output [63:0]   dr;       
output [63:0]	di;       
input  [63:0]	qr;       
input  [63:0]	qi;  


reg  [3:0] state;
wire [3:0] STATEEND = 7;


///////////////////////////////////////////////////////////////////
// start and done logic 
reg        dft_start_delayed;
reg        dft_start_edge;
wire       dft_done;

always @(posedge clk) dft_start_delayed <= dft_start;
always @(posedge clk) dft_start_edge    <= dft_start & !dft_start_delayed;


///////////////////////////////////////////////////////////////////
// Indexing logic declarations
reg  [8:0] j;
wire       increment_j;
wire       reset_j;
wire [7:0] jend;
wire       j_finished;

reg  [8:0] k;
wire       increment_k;
wire       reset_k;
wire [7:0] kend;
wire       k_finished;

reg  [8:0] m;
wire       shift_m;
reg        reset_m; 

reg  [3:0] b;


reg  [7:0] rom_index;

//////////////////////////////////////////////////////////////////////////
// M logic 
always @(posedge clk) reset_m <= dft_start_edge;
assign shift_m   = j_finished ; 
assign dft_done = ~(|m);

always @(posedge clk)
	if(reset) 
             m <= 0;	
	else if(reset_m) 
             m <= 2;	
	else if(shift_m) 
             m <= m << 1;	
	else 
             m <= m;

//////////////////////////////////////////////////////////////////////////
// B logic 
always @(posedge clk)
	if(reset) 
             b <= 1;	
	else if(reset_m) 
             b <= 1;	
	else if(shift_m) 
             b <= b + 1;	
	else 
             b <= b;


//////////////////////////////////////////////////////////////////////////
// j logic
assign increment_j          = k_finished;
assign reset_j              = shift_m || j_finished || reset_m || dft_start_edge;
assign jend                 = (m >> 1) - 1;
assign j_finished           = (j == jend) & k_finished;

always @(posedge clk)
	if(reset_j) 
             j <= 0;	
	else if(increment_j)
             j <= j + 1;
	else 
             j <= j;

//////////////////////////////////////////////////////////////////////////
// k logic
assign reset_k = reset_j || k_finished || reset_m || dft_start_edge; 
assign increment_k = (state == STATEEND) ;
assign kend        = 256 - m + j;
assign k_finished  = (k == kend) & increment_k;

always @(posedge clk)
	if(reset_m) 
             rom_index <= 0;	
	else if(increment_j)
             rom_index <= rom_index + 1;
	else 
             rom_index <= rom_index;

always @(posedge clk)
	if(reset_j) 
             k <= 0;	
	else if(increment_j)
             k <= j + 1;
	else if(reset_k) 
             k <= j;	
	else if(increment_k) 
             k <= k + m;	
	else 
             k <= k;


always @(posedge clk)
	if(reset)
		state <= 0;
	else if(state == 0 && !dft_done)
		state <= 1;
	else if(state == 1 && !dft_done)
		state <= 2;
	else if(state == STATEEND)
		state <= 1;
	else if(!dft_done) 
		state <= state + 1;
	else 
		state <= state;


///////////////////////////////////////////////////////////////////
// register control
reg  [63:0] real_data;
reg  [63:0] imag_data;
reg  [63:0] treal;
reg  [63:0] timag;
reg  [63:0] ureal;
reg  [63:0] uimag;
wire [25:0] wreal;
wire [25:0] wimag;
	   
wire [89:0]  treal_product1;
wire [89:0]  treal_product2;
wire [89:0]  timag_product1;
wire [89:0]  timag_product2;

always @(posedge clk)
	if(state==2)
		real_data = qr;
	else 
		real_data = real_data;

always @(posedge clk)
	if(state==2)
		imag_data = qi;
	else 
		imag_data = imag_data;

always @(posedge clk)
	if(state==3)
		ureal = qr;
	else 
		ureal = ureal;

always @(posedge clk)
	if(state==3)
		uimag = qi;
	else 
		uimag = uimag;

always @(posedge clk)
	if(state==5)
		treal = treal_product1[87:24] - treal_product2[87:24];
	else 
		treal = treal;

always @(posedge clk)
	if(state==5)
		timag = timag_product1[87:24] + timag_product2[87:24];
	else 
		timag = timag;


///////////////////////////////////////////////////////////////////
// memory access code 
reg	    wenr;    
reg	    weni;     
reg	    cenr;     
reg	    ceni;     
reg [7:0]   addrr;    
reg [7:0]   addri;    
wire [63:0] dr = (state==6) ? ureal+treal : ureal-treal;       
wire [63:0] di = (state==6) ? uimag+timag : uimag-timag;       
wire [7:0]  address_one = (k + (m>>1));
wire [7:0]  address_two = k ;

always @( 
          state or
          address_one or
          address_two
          )
      casez(state)
	      0: // idle
	      begin
                 wenr   <= 1;    
                 weni   <= 1;     
                 cenr   <= 1;     
                 ceni   <= 1;     
                 addrr  <= address_one; 
                 addri  <= address_one; 
              end
	      1:// read 1
	      begin
                 wenr   <= 1;              
                 weni   <= 1;               
                 cenr   <= 0;               
                 ceni   <= 0;               
                 addrr  <= address_one; 
                 addri  <= address_one;
              end
	      2: // read 2
	      begin
                 wenr   <= 1;              
                 weni   <= 1;               
                 cenr   <= 0;               
                 ceni   <= 0;               
                 addrr  <= address_two ;       
                 addri  <= address_two ;       
              end
	      6: // write 1
	      begin
                 wenr   <= 0;              
                 weni   <= 0;               
                 cenr   <= 0;               
                 ceni   <= 0;               
                 addrr  <= address_two;       
                 addri  <= address_two;       
              end
	      7: // write 2
	      begin
                 wenr   <= 0;              
                 weni   <= 0;               
                 cenr   <= 0;               
                 ceni   <= 0;               
                 addrr  <= address_one;    
                 addri  <= address_one;    
              end
	      default: // 
	      begin
                 wenr   <= 1;              
                 weni   <= 1;               
                 cenr   <= 1;               
                 ceni   <= 1;               
                 addrr  <= address_one;    
                 addri  <= address_one;    
              end
           endcase

///////////////////////////////////////////////////////////////////
// Multipliers 
	   
signed_multiplier3 treal1 (
	.ain(  real_data           ),
	.bin(  wreal[25:0]         ),
	.pout( treal_product1     ));

signed_multiplier3 treal2  (
	.ain(  imag_data           ),
	.bin(  wimag[25:0]         ),
	.pout( treal_product2     ));

signed_multiplier3 timag1   (
	.ain(  imag_data          ),
	.bin(  wreal[25:0]        ),
	.pout( timag_product1     ));

signed_multiplier3 timag2  (
	.ain(  real_data          ),
	.bin(  wimag[25:0]        ),
	.pout( timag_product2     ));


//////////////////////////////////////////////////////////////
// Omega ROMs
//
wreal_rom wreal_rom (
   .Q              ( wreal               ),
	.CLK            ( clk                 ),
	.CEN            ( 1'b0                ),
	.A              ( rom_index           ));
wimag_rom wimag_rom (
   .Q              ( wimag               ),
	.CLK            ( clk                 ),
	.CEN            ( 1'b0                ),
	.A              ( rom_index           ));

     endmodule



