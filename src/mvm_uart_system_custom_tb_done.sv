module mvm_uart_system_tb;

  `timescale 1ns/1ps
  localparam  R=4, C=4, W_X=8, W_K=8,
              W_Y_OUT          = 32,
              CLOCKS_PER_PULSE = 4, //200_000_000/9600,
              BITS_PER_WORD    = 8,
              W_Y              = W_X + W_K + $clog2(C),
              W_BUS_KX         = R*C*W_K + C*W_X, //32
              W_BUS_Y          = R*W_Y_OUT, //  64
              N_WORDS_KX       = W_BUS_KX/BITS_PER_WORD, // 32/8 = 4
              N_WORDS_Y        = W_BUS_Y /BITS_PER_WORD,// 64/8 = 8
              PACKET_SIZE_TX   = BITS_PER_WORD+5,
              CLK_PERIOD       = 10,
              NUM_EXP          = 2; // Change to 2 for the 2 known matrices

  logic clk=0, rstn=0, rx=1, tx;
  initial forever #(CLK_PERIOD/2) clk <= !clk;

  mvm_uart_system #(
    .CLOCKS_PER_PULSE (CLOCKS_PER_PULSE), //200_000_000/9600
    .BITS_PER_WORD (BITS_PER_WORD),
    .PACKET_SIZE_TX(PACKET_SIZE_TX),
    .R(R), .C(C), .W_X(W_X), .W_K(W_K)) dut (.*);

  // Driver

  logic [N_WORDS_KX-1:0][BITS_PER_WORD-1:0] s_data;
  logic [BITS_PER_WORD+2-1:0] s_packet;
  logic [N_WORDS_KX-1:0][BITS_PER_WORD-1:0] queue_kx[$]={'0};

  // Define the two known 2x2 matrices
  logic [W_X-1:0] x1 [C-1:0] = '{8'd13, 8'd12,8'd11, 8'd10}; // First vector
  // logic [W_X-1:0] x2 [C-1:0] = '{8'h03, 8'h04}; // Second vector

  logic [W_K-1:0] k1 [R-1:0][C-1:0] = '{ '{8'd05, 8'd7,8'd6, 8'd12}, '{8'd11, 8'd02,8'd1, 8'd15}, '{8'd01, 8'd3,8'd5, 8'd7}, '{8'd2, 8'd4,8'd6, 8'd8}}; // First matrix
  // logic [W_K-1:0] k2 [R-1:0][C-1:0] = '{ '{8'h09, 8'h0A}, '{8'h0B, 8'h0C} }; // Second matrix

  initial begin
    assert (W_BUS_KX % BITS_PER_WORD == 0);
    assert (W_BUS_Y  % BITS_PER_WORD == 0);
    $dumpfile("dump.vcd"); $dumpvars;

    repeat(2)  @(posedge clk) #1;
    rstn = 1;

    // First known matrix and vector
    s_data[0] = x1[0];
    s_data[1] = x1[1];
    s_data[2] = k1[0][0];
    s_data[3] = k1[0][1];
    s_data[4] = k1[1][0];
    s_data[5] = k1[1][1];

    queue_kx.push_front(s_data);
    for (int iw=0; iw<N_WORDS_KX; iw++) begin
      s_packet = {1'b1, s_data[iw], 1'b0};

      repeat ($urandom_range(1,20)) @(posedge clk);

      for (int ib=0; ib<BITS_PER_WORD+2; ib++)
        repeat(CLOCKS_PER_PULSE) begin
          #1 rx <= s_packet[ib];
          @(posedge clk);
        end
    end

    repeat ($urandom_range(1,100)) @(posedge clk);

    // // Second known matrix and vector
    // s_data[0] = x2[0];
    // s_data[1] = x2[1];
    // s_data[2] = k2[0][0];
    // s_data[3] = k2[0][1];
    // s_data[4] = k2[1][0];
    // s_data[5] = k2[1][1];

    // queue_kx.push_front(s_data);
    // for (int iw=0; iw<N_WORDS_KX; iw++) begin
    //   s_packet = {1'b1, s_data[iw], 1'b0};

    //   repeat ($urandom_range(1,20)) @(posedge clk);

    //   for (int ib=0; ib<BITS_PER_WORD+2; ib++)
    //     repeat(CLOCKS_PER_PULSE) begin
    //       #1 rx <= s_packet[ib];
    //       @(posedge clk);
    //     end
    // end

    // repeat ($urandom_range(1,100)) @(posedge clk);
  end

  // Monitor

  logic        [C-1:0][W_X-1:0] x_out;
  logic [R-1:0][C-1:0][W_K-1:0] k_out;
  logic        [C-1:0][W_K-1:0] k_row_out;
  logic        [R-1:0][W_Y_OUT-1:0] exp_data;
  logic [N_WORDS_Y -1:0][BITS_PER_WORD-1:0] m_data;
  logic [BITS_PER_WORD-1  :0] m_packet;

  initial begin
    repeat (NUM_EXP) begin
      m_data <= 'x;
      for (int iw=0; iw<N_WORDS_Y; iw++) begin // get each word

        wait(!tx);
        repeat (CLOCKS_PER_PULSE/2) @(posedge clk); // go to middle of start bit

        for (int ib=0; ib<BITS_PER_WORD; ib++) begin
          repeat (CLOCKS_PER_PULSE) @(posedge clk); // go to middle of data bit
          m_packet[ib] = tx;
        end
        m_data[iw] = m_packet;

        for (int ib=0; ib<PACKET_SIZE_TX-BITS_PER_WORD-1; ib=ib+1) begin
          repeat (CLOCKS_PER_PULSE) @(posedge clk);
          assert (tx == 1) else $error("Incorrect end bits/padding");
        end
      end

      {k_out, x_out} = queue_kx.pop_back();

      // Matrix Vector Multiplication in software
      exp_data = '0;
      for (int r=0; r<R; r=r+1) begin
        for (int c=0; c<C; c=c+1) begin
          exp_data[r] = $signed(exp_data[r]) + $signed(k_out[r][c]) * $signed(x_out[c]);
        end
      end

      // Compare
      if (exp_data == m_data)
        $display("Outputs match: %d", exp_data);
      else $fatal(0, "Expected: %d != Output: %d", exp_data, m_data);
    end
    $finish();
  end

  // Count TX, RX bits to read waveform easily

  int tx_bits, rx_bits;
  initial forever begin
    tx_bits = 0;
    wait(!tx);
    for (int n=0; n<PACKET_SIZE_TX; n++) begin
      tx_bits += 1;
      repeat (CLOCKS_PER_PULSE) @(posedge clk);
    end
  end
  initial forever begin
    rx_bits = 0;
    wait(!rx);
    for (int n=0; n<BITS_PER_WORD+2; n++) begin
      rx_bits += 1;
      repeat (CLOCKS_PER_PULSE) @(posedge clk);
    end
  end

endmodule
