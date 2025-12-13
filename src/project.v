/*
 * Copyright (c) 2024 Uri Shaked
 * SPDX-License-Identifier: Apache-2.0
 * * Modified for Tiny Tapeout: MERRY XMAS (Line 1) and MALIGAYANG PASKO (Line 2) - L, N, and G FIXED
 */

`default_nettype none

module tt_um_vga_example(
  input  wire [7:0] ui_in,    // Dedicated inputs
  output wire [7:0] uo_out,   // Dedicated outputs
  input  wire [7:0] uio_in,   // IOs: Input path
  output wire [7:0] uio_out,  // IOs: Output path
  output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
  input  wire       ena,      // always 1 when the design is powered, so you can ignore it
  input  wire       clk,      // clock
  input  wire       rst_n     // reset_n - low to reset
);

  // VGA signals
  wire hsync;
  wire vsync;
  wire [1:0] R; // 2-bit Red
  wire [1:0] G; // 2-bit Green
  wire [1:0] B; // 2-bit Blue
  wire video_active;
  wire [9:0] pix_x;
  wire [9:0] pix_y;
  wire sound; 

  // TinyVGA PMOD output mapping
  assign uo_out = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};

  // Unused outputs assigned to 0.
  assign uio_out = 0;
  assign uio_oe  = 0;

  // Suppress unused signals warning
  wire _unused_ok = &{ena, ui_in, uio_in};

  // hvsync_generator module call (assumed external)
  hvsync_generator hvsync_gen(
    .clk(clk),
    .reset(~rst_n),
    .hsync(hsync),
    .vsync(vsync),
    .display_on(video_active),
    .hpos(pix_x),
    .vpos(pix_y)
  );

  // --- SEQUENTIAL LOGIC (STAR BLINKING) ---
  reg [9:0] star_color_cycle = 10'b0;
  always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      star_color_cycle <= 10'b0;
    end else if (vsync) begin
      star_color_cycle <= star_color_cycle + 1;
    end
  end
  wire [1:0] color_select = star_color_cycle[9:8]; 

  // --- TREE DRAWING LOGIC (UNCHANGED) ---
  localparam [9:0] CENTER_X = 320;
  localparam [9:0] BASE_Y   = 400;
  localparam [9:0] TOP_Y    = 100;
  wire [9:0] rel_x = (pix_x > CENTER_X) ? (pix_x - CENTER_X) : (CENTER_X - pix_x);
  wire [9:0] dist_from_top = pix_y - TOP_Y; 
  wire is_tree_body = (pix_y >= TOP_Y) && (pix_y < BASE_Y) && (rel_x < (dist_from_top >> 1)); 

  localparam [9:0] TRUNK_WIDTH  = 40; 
  localparam [9:0] TRUNK_HEIGHT = 50;
  wire is_trunk = (pix_y >= BASE_Y) && (pix_y < BASE_Y + TRUNK_HEIGHT) && (rel_x < (TRUNK_WIDTH >> 1)); 

  localparam [9:0] STAR_CENTER_Y = TOP_Y - 15;
  localparam [9:0] STAR_SIZE     = 10;
  wire is_star = (pix_y > STAR_CENTER_Y - STAR_SIZE) && (pix_y < STAR_CENTER_Y + STAR_SIZE) && 
                 (rel_x < STAR_SIZE);

  wire is_light_stripe = (pix_y[3] ^ pix_y[5]); 

  // --- TEXT LOGIC: TWO LINES (16x16 font, 20px wide block) ---
  localparam [9:0] CHAR_WIDTH  = 20; 
  localparam [9:0] CHAR_HEIGHT = 16;
  localparam [9:0] LINE_SPACING = 5; 

  // --- LINE 1: MERRY XMAS (10 characters) ---
  localparam [3:0] TEXT1_LENGTH = 10;
  localparam [9:0] TEXT1_Y_POS  = BASE_Y + TRUNK_HEIGHT - 25; 
  localparam [9:0] TEXT1_START_X = CENTER_X - (TEXT1_LENGTH * CHAR_WIDTH / 2); // 220
  
  wire in_text1_area = (pix_y >= TEXT1_Y_POS) && (pix_y < TEXT1_Y_POS + CHAR_HEIGHT) && 
                       (pix_x >= TEXT1_START_X) && (pix_x < TEXT1_START_X + TEXT1_LENGTH * CHAR_WIDTH);

  // --- LINE 2: MALIGAYANG PASKO! (18 characters) ---
  localparam [4:0] TEXT2_LENGTH = 18; 
  localparam [9:0] TEXT2_Y_POS  = TEXT1_Y_POS + CHAR_HEIGHT + LINE_SPACING;
  localparam [9:0] TEXT2_START_X = CENTER_X - (TEXT2_LENGTH * CHAR_WIDTH / 2); // 140
  
  wire in_text2_area = (pix_y >= TEXT2_Y_POS) && (pix_y < TEXT2_Y_POS + CHAR_HEIGHT) && 
                       (pix_x >= TEXT2_START_X) && (pix_x < TEXT2_START_X + TEXT2_LENGTH * CHAR_WIDTH);
  
  // Selector for which line we are drawing, or 0 if neither.
  wire [1:0] text_line_select = in_text1_area ? 2'b01 : (in_text2_area ? 2'b10 : 2'b00);

  // Coordinates relative to the start of the active text line
  wire [9:0] x_in_text_block = text_line_select[0] ? (pix_x - TEXT1_START_X) : (pix_x - TEXT2_START_X);
  wire [9:0] y_in_text_block = text_line_select[0] ? (pix_y - TEXT1_Y_POS) : (pix_y - TEXT2_Y_POS);

  // 1. Character Index: Division by 20 
  wire [4:0] char_index_raw = x_in_text_block / CHAR_WIDTH; 
  
  // 2. Pixel Position within 20x16 block: Modulo 20
  wire [4:0] block_x_pixel_20 = x_in_text_block % CHAR_WIDTH; 

  // 3. Determine if the pixel is in the 16x16 font area (0-15) or the 4-pixel space area (16-19)
  wire is_char_pixel = block_x_pixel_20 < 16; 
  
  // 4. Map 16x16 block back to 8x8 font: Divide by 2 (Right shift by 1)
  wire [2:0] char_x_pixel = block_x_pixel_20[3:1]; 
  wire [2:0] char_y_pixel = y_in_text_block[3:1]; 

  // Hard-coded Font Logic (8 rows of 8 bits for one character)
  reg [7:0] char_row_data;
  reg [4:0] final_char_index;

  always @(*) begin
    char_row_data = 8'h00; 
    final_char_index = 5'b0;

    // --- Select Character Index based on the line ---
    if (text_line_select[0]) begin // Line 1: MERRY XMAS
      case (char_index_raw) 
        4'd0: final_char_index = 5'd13; // M
        4'd1: final_char_index = 5'd11; // E
        4'd2, 4'd3: final_char_index = 5'd18; // R
        4'd4: final_char_index = 5'd25; // Y
        4'd5: final_char_index = 5'd31; // Space
        4'd6: final_char_index = 5'd24; // X
        4'd7: final_char_index = 5'd13; // M
        4'd8: final_char_index = 5'd10; // A
        4'd9: final_char_index = 5'd19; // S
        default: ;
      endcase
    end else if (text_line_select[1]) begin // Line 2: MALIGAYANG PASKO!
      case (char_index_raw) 
        5'd0: final_char_index = 5'd13; // M
        5'd1: final_char_index = 5'd10; // A
        5'd2: final_char_index = 5'd12; // L 
        5'd3: final_char_index = 5'd14; // I
        5'd4: final_char_index = 5'd15; // G (FIXED)
        5'd5: final_char_index = 5'd10; // A
        5'd6: final_char_index = 5'd25; // Y
        5'd7: final_char_index = 5'd10; // A
        5'd8: final_char_index = 5'd16; // N 
        5'd9: final_char_index = 5'd15; // G (FIXED)
        5'd10: final_char_index = 5'd31; // Space
        5'd11: final_char_index = 5'd17; // P
        5'd12: final_char_index = 5'd10; // A
        5'd13: final_char_index = 5'd19; // S
        5'd14: final_char_index = 5'd20; // K
        5'd15: final_char_index = 5'd21; // O
        5'd16: final_char_index = 5'd26; // !
        default: ;
      endcase
    end

    // --- Character Data Lookup ---
    case (final_char_index)
      5'd10: case (char_y_pixel) 3'd0: char_row_data = 8'b01111110; 3'd1: char_row_data = 8'b10000001; 3'd2: char_row_data = 8'b10000001; 3'd3: char_row_data = 8'b11111111; 3'd4: char_row_data = 8'b10000001; 3'd5: char_row_data = 8'b10000001; 3'd6: char_row_data = 8'b10000001; default: ; endcase // A
      5'd11: case (char_y_pixel) 3'd0: char_row_data = 8'b11111111; 3'd1: char_row_data = 8'b10000000; 3'd2: char_row_data = 8'b10000000; 3'd3: char_row_data = 8'b11110000; 3'd4: char_row_data = 8'b10000000; 3'd5: char_row_data = 8'b10000000; 3'd6: char_row_data = 8'b11111111; default: ; endcase // E
      5'd12: case (char_y_pixel) 3'd0: char_row_data = 8'b10000000; 3'd1: char_row_data = 8'b10000000; 3'd2: char_row_data = 8'b10000000; 3'd3: char_row_data = 8'b10000000; 3'd4: char_row_data = 8'b10000000; 3'd5: char_row_data = 8'b10000000; 3'd6: char_row_data = 8'b11111111; default: ; endcase // L (Fixed)
      5'd13: case (char_y_pixel) 3'd0: char_row_data = 8'b10000001; 3'd1: char_row_data = 8'b11000011; 3'd2: char_row_data = 8'b10100101; 3'd3: char_row_data = 8'b10011001; 3'd4: char_row_data = 8'b10000001; 3'd5: char_row_data = 8'b10000001; 3'd6: char_row_data = 8'b10000001; default: ; endcase // M
    // I (MODIFIED: Shifted right 2 bits to reduce spacing)
      5'd14: case (char_y_pixel) 
            3'd0: char_row_data = 8'b00011000;
            3'd1: char_row_data = 8'b00001000; 
            3'd2: char_row_data = 8'b00001000; 
            3'd3: char_row_data = 8'b00001000; 
            3'd4: char_row_data = 8'b00001000; 
            3'd5: char_row_data = 8'b00001000; 
            3'd6: char_row_data = 8'b00011000;
            default: ; 
            endcase // I // G (FIXED: Added inner stem)
      5'd15: case (char_y_pixel) 3'd0: char_row_data = 8'b01111110; 3'd1: char_row_data = 8'b10000001; 3'd2: char_row_data = 8'b10000000; 3'd3: char_row_data = 8'b10011111; 3'd4: char_row_data = 8'b10000001; 3'd5: char_row_data = 8'b10000001; 3'd6: char_row_data = 8'b01111110; default: ; endcase // G
      5'd16: case (char_y_pixel) 3'd0: char_row_data = 8'b10000001; 3'd1: char_row_data = 8'b11000001; 3'd2: char_row_data = 8'b10100001; 3'd3: char_row_data = 8'b10010001; 3'd4: char_row_data = 8'b10001001; 3'd5: char_row_data = 8'b10000101; 3'd6: char_row_data = 8'b10000011; default: ; endcase // N (Fixed)
      5'd17: case (char_y_pixel) 3'd0: char_row_data = 8'b11111100; 3'd1: char_row_data = 8'b10000100; 3'd2: char_row_data = 8'b10000100; 3'd3: char_row_data = 8'b11111100; 3'd4: char_row_data = 8'b10000000; 3'd5: char_row_data = 8'b10000000; 3'd6: char_row_data = 8'b10000000; default: ; endcase // P
      5'd18: case (char_y_pixel) 3'd0: char_row_data = 8'b11111100; 3'd1: char_row_data = 8'b10000100; 3'd2: char_row_data = 8'b10000100; 3'd3: char_row_data = 8'b11111100; 3'd4: char_row_data = 8'b10100000; 3'd5: char_row_data = 8'b10010000; 3'd6: char_row_data = 8'b10001000; default: ; endcase // R
      5'd19: case (char_y_pixel) 3'd0: char_row_data = 8'b01111110; 3'd1: char_row_data = 8'b10000000; 3'd2: char_row_data = 8'b10000000; 3'd3: char_row_data = 8'b01111110; 3'd4: char_row_data = 8'b00000001; 3'd5: char_row_data = 8'b00000001; 3'd6: char_row_data = 8'b11111110; default: ; endcase // S
      5'd20: case (char_y_pixel) 3'd0: char_row_data = 8'b10000001; 3'd1: char_row_data = 8'b10000010; 3'd2: char_row_data = 8'b10000100; 3'd3: char_row_data = 8'b11111000; 3'd4: char_row_data = 8'b10000100; 3'd5: char_row_data = 8'b10000010; 3'd6: char_row_data = 8'b10000001; default: ; endcase // K 
      5'd21: case (char_y_pixel) 3'd0: char_row_data = 8'b01111110; 3'd1: char_row_data = 8'b10000001; 3'd2: char_row_data = 8'b10000001; 3'd3: char_row_data = 8'b10000001; 3'd4: char_row_data = 8'b10000001; 3'd5: char_row_data = 8'b10000001; 3'd6: char_row_data = 8'b01111110; default: ; endcase // O
      5'd24: case (char_y_pixel) 3'd0: char_row_data = 8'b10000001; 3'd1: char_row_data = 8'b01000010; 3'd2: char_row_data = 8'b00100100; 3'd3: char_row_data = 8'b00011000; 3'd4: char_row_data = 8'b00100100; 3'd5: char_row_data = 8'b01000010; 3'd6: char_row_data = 8'b10000001; default: ; endcase // X
      5'd25: case (char_y_pixel) 3'd0: char_row_data = 8'b10000001; 3'd1: char_row_data = 8'b01000010; 3'd2: char_row_data = 8'b00111100; 3'd3: char_row_data = 8'b00011000; 3'd4: char_row_data = 8'b00011000; 3'd5: char_row_data = 8'b00011000; 3'd6: char_row_data = 8'b00011000; default: ; endcase // Y (Fixed)
   //   5'd26: case (char_y_pixel) 3'd0: char_row_data = 8'b00100000; 3'd1: char_row_data = 8'b00100000; 3'd5: char_row_data = 8'b00100000; default: ; endcase // !
   // ! (MODIFIED: thicker and longer)
      5'd26: case (char_y_pixel) 
            3'd0: char_row_data = 8'b00110000; // Top line
            3'd1: char_row_data = 8'b00110000; // 
            3'd2: char_row_data = 8'b00110000; // 
            3'd3: char_row_data = 8'b00110000; // Bottom line
            // Row 4 is a gap
            3'd5: char_row_data = 8'b00110000; // Dot top
            3'd6: char_row_data = 8'b00110000; // Dot bottom
            default: ; 
          endcase
      5'd31: char_row_data = 8'h00; // Space
      default: char_row_data = 8'h00;
    endcase
  end

  // font_bit is high (1) if the current pixel (char_x_pixel, char_y_pixel) should be drawn
  wire font_bit_raw = char_row_data[7 - char_x_pixel]; 
  
  // The pixel should only be drawn if we are in the 16x16 area AND the font bit is set.
  wire font_bit = (in_text1_area || in_text2_area) && is_char_pixel && font_bit_raw;

  // --- COLOR ASSIGNMENTS ---
  
  reg [1:0] R_color; 
  reg [1:0] G_color;
  reg [1:0] B_color;

  always @(*) begin
    // Default to background (black)
    R_color = 2'b00;
    G_color = 2'b00;
    B_color = 2'b00;

    // Highest Priority: STAR
    if (is_star) begin
      case (color_select)
        2'b01: begin R_color = 2'b11; G_color = 2'b00; B_color = 2'b00; end // Red
        2'b10: begin R_color = 2'b11; G_color = 2'b11; B_color = 2'b00; end // Yellow
        2'b11: begin R_color = 2'b11; G_color = 2'b01; B_color = 2'b00; end // Orange
        default: begin R_color = 2'b10; G_color = 2'b00; B_color = 2'b00; end // Dark Red/Off
      endcase
    end
    
    // Second Highest Priority: TEXT
    else if (font_bit) begin
      // Text Color: White 
      R_color = 2'b11;
      G_color = 2'b11;
      B_color = 2'b11;
    end
    
    // Lower Priority: TREE/TRUNK/LIGHTS
    else if (is_tree_body) begin
      // Tree body: Green
      R_color = 2'b00;
      G_color = 2'b11; 
      B_color = 2'b00;
      
      // Add simple lights/garland 
      if (is_light_stripe) begin
          if (pix_x[3]) begin
              R_color = 2'b11;
              G_color = 2'b00;
          end else begin
              B_color = 2'b11;
              G_color = 2'b00;
          end
      end
      
    end else if (is_trunk) begin
      // Trunk: Brown
      R_color = 2'b10;
      G_color = 2'b01;
      B_color = 2'b00;
    end
  end

  // Assign the final color outputs only when the video is active
  assign R = video_active ? R_color : 2'b00;
  assign G = video_active ? G_color : 2'b00;
  assign B = video_active ? B_color : 2'b00;

endmodule
