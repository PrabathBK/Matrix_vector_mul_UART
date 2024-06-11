module matvec_mul #(
    parameter R=8, C=8, W_X=8, W_K=8

  )(  
    input  logic clk, cen,
    input  logic signed [R-1:0][C-1:0][W_K-1:0] k,
    input  logic signed        [C-1:0][W_X-1:0] x, 
    output logic signed        [R-1:0][W_Y-1:0] y
  );
      localparam DEPTH = $clog2(C),
               W_M = W_X + W_K,
               W_Y = W_M + DEPTH;

  // Padding
  
  localparam C_PAD = 2**$clog2(C);
  logic signed [W_Y-1:0] tree [R][DEPTH+1][C_PAD]; // adder tree

  wire signed        [C_PAD-1:0][W_X-1:0] x_pad = {'0, x};
  wire signed [R-1:0][C_PAD-1:0][W_K-1:0] k_pad;      

   genvar r, c, d, a;
    generate
        for (r = 0; r < R; r = r + 1) begin : row_loop
            assign k_pad[r] = { '0, k[r] }; // Padding

            for (c = 0; c < C_PAD; c = c + 1) begin : col_loop
                always_ff @(posedge clk) begin
                    if (cen) begin
                        tree[r][0][c] <= $signed(k_pad[r][c]) * $signed(x_pad[c]);
                    end
                end
            end

            for (d = 0; d < DEPTH; d = d + 1) begin : depth_loop
                for (a = 0; a < C_PAD / (2**(d+1)); a = a + 1) begin : adder_loop
                    always_ff @(posedge clk) begin
                        if (cen) begin
                            tree[r][d+1][a] <= tree[r][d][2*a] + tree[r][d][2*a+1];
                        end
                    end
                end
            end

            assign y[r] = tree[r][DEPTH][0];
        end
    endgenerate
endmodule