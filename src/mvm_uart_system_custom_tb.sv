module mvm_uart_system_tb;

  `timescale 1ns/1ps
  localparam  R=3, C=4, W_X=8, W_K=8,
              W_Y_OUT          = 32,
              CLOCKS_PER_PULSE = 4, //200_000_000/9600,
              BITS_PER_WORD    = 8,
              W_Y              = W_X + W_K + $clog2(C),
              W_BUS_KX         = R*C*W_K + C*W_X, // 128
              W_BUS_Y          = R*W_Y_OUT, // 128
              N_WORDS_KX       = W_BUS_KX/BITS_PER_WORD, // 128/8 = 16
              N_WORDS_Y        = W_BUS_Y /BITS_PER_WORD, // 128/8 = 16
              PACKET_SIZE_TX   = BITS_PER_WORD+5,
              CLK_PERIOD       = 10,
              NUM_EXP          = 1;

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

  // Define the known 4x4 matrices and vector
  logic [W_X-1:0] x1 [C-1:0] = '{8'd13, 8'd12, 8'd11, 8'd10}; // Vector
  logic [W_K-1:0] k1 [R-1:0][C-1:0] = '{
    '{8'd05, 8'd07, 8'd06, 8'd12},
    '{8'd11, 8'd02, 8'd01, 8'd15},
    '{8'd01, 8'd03, 8'd05, 8'd07}
  }; // Matrix
  int idx = 0; // Declare idx here
  initial begin
    assert (W_BUS_KX % BITS_PER_WORD == 0);
    assert (W_BUS_Y  % BITS_PER_WORD == 0);
    $dumpfile("dump.vcd"); $dumpvars;

    repeat(2)  @(posedge clk) #1;
    rstn = 1;

    // Known matrix and vector

    for (int c = 0; c < C; c++) begin
      s_data[idx++] = x1[c];
    end
    for (int r = 0; r < R; r++) begin
      for (int c = 0; c < C; c++) begin
        s_data[idx++] = k1[r][c];
      end
    end

    queue_kx.push_front(s_data);
    for (int iw = 0; iw < N_WORDS_KX; iw++) begin
      s_packet = {1'b1, s_data[iw], 1'b0};

      repeat ($urandom_range(1, 20)) @(posedge clk);

      for (int ib = 0; ib < BITS_PER_WORD + 2; ib++)
        repeat(CLOCKS_PER_PULSE) begin
          #1 rx <= s_packet[ib];
          @(posedge clk);
        end
    end

    repeat ($urandom_range(1, 100)) @(posedge clk);
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
      for (int iw = 0; iw < N_WORDS_Y; iw++) begin // get each word

        wait(!tx);
        repeat (CLOCKS_PER_PULSE/2) @(posedge clk); // go to middle of start bit

        for (int ib = 0; ib < BITS_PER_WORD; ib++) begin
          repeat (CLOCKS_PER_PULSE) @(posedge clk); // go to middle of data bit
          m_packet[ib] = tx;
        end
        m_data[iw] = m_packet;

        for (int ib = 0; ib < PACKET_SIZE_TX - BITS_PER_WORD - 1; ib = ib + 1) begin
          repeat (CLOCKS_PER_PULSE) @(posedge clk);
          assert (tx == 1) else $error("Incorrect end bits/padding");
        end
      end

      {k_out, x_out} = queue_kx.pop_back();

      // Matrix Vector Multiplication in software
      exp_data = '0;
      for (int r = 0; r < R; r = r + 1) begin
        for (int c = 0; c < C; c = c + 1) begin
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
    for (int n = 0; n < PACKET_SIZE_TX; n++) begin
      tx_bits += 1;
      repeat (CLOCKS_PER_PULSE) @(posedge clk);
    end
  end
  initial forever begin
    rx_bits = 0;
    wait(!rx);
    for (int n = 0; n < BITS_PER_WORD + 2; n++) begin
      rx_bits += 1;
      repeat (CLOCKS_PER_PULSE) @(posedge clk);
    end
  end

endmodule
