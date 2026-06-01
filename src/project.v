`default_nettype none

module tt_um_pqc_ntt_butterfly (
    input  wire [7:0] ui_in,    // [7:0] A_in (Lower 8-bits)
    output wire [7:0] uo_out,   // [7:0] X_out (Lower 8-bits)
    input  wire [7:0] uio_in,   // [3:0] B_in (Lower 4-bits), [7:4] W_in (Twiddle Factor Lower 4-bits)
    output wire [7:0] uio_out,  // [7:0] Y_out (Lower 8-bits)
    output wire [7:0] uio_oe,   // Bidirectional pin output enable configuration
    input  wire       ena,      // Global design enable
    input  wire       clk,      // System clock
    input  wire       rst_n     // Active-low asynchronous reset
);

    // Pin configurations for Tiny Tapeout 1x1 footprint limits:
    // Because we only have 8-bit ports, we treat inputs as small unsigned integers 
    // to fit the hardware demo: A is 8-bit, B is 4-bit, W is 4-bit.
    wire [11:0] A = {4'b0, ui_in};
    wire [11:0] B = {8'b0, uio_in[3:0]};
    wire [11:0] W = {8'b0, uio_in[7:4]};

    // Kyber Prime Modulus constant
    localparam [11:0] Q = 12'd3329;

    // Registers for internal pipelining
    reg [11:0] x_reg;
    reg [11:0] y_reg;

    // Intermediate wires for modular arithmetic
    wire [23:0] mul_bw = B * W;
    
    // Step 1: Reduce (B * W) mod Q
    // Since max(B*W) = 15 * 15 = 225, which is already less than Q (3329),
    // (B * W) mod 3329 is simply equal to (B * W).
    wire [11:0] bw_mod = mul_bw[11:0];

    // Step 2: Compute X = (A + bw_mod) mod Q
    wire [12:0] sum_raw = A + bw_mod;
    wire [11:0] sum_sub = sum_raw - Q;
    // If sum_raw >= Q, use sum_sub, otherwise keep sum_raw
    wire [11:0] x_next  = (sum_raw >= Q) ? sum_sub : sum_raw[11:0];

    // Step 3: Compute Y = (A - bw_mod) mod Q
    // If A >= bw_mod, simple subtraction. If underflow, add Q to balance it.
    wire [11:0] y_next = (A >= bw_mod) ? (A - bw_mod) : (A + Q - bw_mod);

    // Sequential Clock Driven Execution
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            x_reg <= 12'b0;
            y_reg <= 12'b0;
        end else begin
            if (ena) begin
                x_reg <= x_next;
                y_reg <= y_next;
            end
        end
    end

    // Direct interface assignment back to Tiny Tapeout output buses
    assign uo_out  = x_reg[7:0];  // Lower 8 bits of X output
    assign uio_out = y_reg[7:0];  // Lower 8 bits of Y output
    
    // Configure uio_in[7:0] data directions: [3:0] are inputs, [7:4] are outputs for Y
    assign uio_oe  = 8'hF0;       // 1 = Output (uio_out[7:4]), 0 = Input (uio_in[3:0])

endmodule
