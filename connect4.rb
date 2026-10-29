require 'ruby2d'
require_relative 'socket_client'

class Connect4Game
  ROWS = 6
  COLS = 7

  COLOR_EMPTY  = '#111111'
  COLOR_P1     = '#ff3333' # Red
  COLOR_P2     = '#ffff33' # Yellow
  COLOR_BOARD  = '#0033cc' # Blue
  COLOR_SELECT = '#00ffff' # Cyan selector

  def initialize
    # Board logical state: 6 rows x 7 cols (nil = empty, 1 = P1, 2 = P2)
    @grid = Array.new(ROWS) { Array.new(COLS, nil) }
    @current_player = 1
    @winner = nil # nil, 1, 2, or :draw
    @selected_col = 3 # Start in the middle column

    # AI configuration
    @p2_ai = true
    @ai_client = AIClient.new('127.0.0.1', 65433)
    @ai_timer = 0
    @ai_delay_frames = 20 # ~0.33 second delay so moves are visible

    # Visual sizing & positioning (Centered on 640x480 screen)
    @cell_size = 50
    @radius = 20
    @start_x = (Window.width - (COLS * @cell_size)) / 2 + @cell_size / 2
    @start_y = 120

    @render_objects = []

    # UI Text
    @title_text = Text.new(
      "CONNECT 4",
      x: Window.width / 2 - 80,
      y: 12,
      size: 26,
      color: '#00ffff'
    )
    @render_objects << @title_text

    @status_text = Text.new(
      "Player 1's Turn (Red)",
      x: Window.width / 2 - 110,
      y: 44,
      size: 18,
      color: COLOR_P1
    )
    @render_objects << @status_text

    @ai_status_text = Text.new(
      "P2 AI: ON (Press P to toggle)",
      x: Window.width / 2 - 110,
      y: 68,
      size: 14,
      color: '#00ff88'
    )
    @render_objects << @ai_status_text

    @help_text = Text.new(
      "LEFT/RIGHT: Move | SPACE: Drop | P: Toggle AI | R: Reset | ESC: Menu",
      x: Window.width / 2 - 240,
      y: Window.height - 30,
      size: 14,
      color: 'gray'
    )
    @render_objects << @help_text

    # Board background frame
    board_rect = Rectangle.new(
      x: @start_x - @cell_size / 2 - 5,
      y: @start_y - @cell_size / 2 - 5,
      width: COLS * @cell_size + 10,
      height: ROWS * @cell_size + 10,
      color: COLOR_BOARD
    )
    @render_objects << board_rect

    # Selector marker above the board
    @selector_marker = Circle.new(
      x: x_for_col(@selected_col),
      y: @start_y - 35,
      radius: 12,
      color: COLOR_P1
    )
    @render_objects << @selector_marker

    # Slot circles on the board
    @slots = Array.new(ROWS) { Array.new(COLS) }
    ROWS.times do |r|
      COLS.times do |c|
        slot = Circle.new(
          x: x_for_col(c),
          y: y_for_row(r),
          radius: @radius,
          color: COLOR_EMPTY
        )
        @slots[r][c] = slot
        @render_objects << slot
      end
    end
  end

  def update
    return if @winner != nil

    # AI Turn Handling
    if @current_player == 2 && @p2_ai
      @ai_timer += 1
      if @ai_timer >= @ai_delay_frames
        @ai_timer = 0
        trigger_ai_move
      end
    else
      @ai_timer = 0
    end
  end

  def handle_key_down(key)
    case key
    # Column selection (only allowed on human turns)
    when 'left', 'a'
      move_selector(-1) if human_turn?
    when 'right', 'd'
      move_selector(1) if human_turn?
    when 'space', 'down', 'return'
      drop_piece(@selected_col) if human_turn?
    when '1'..'7'
      if human_turn?
        col = key.to_i - 1
        @selected_col = col
        update_selector
        drop_piece(col)
      end

    # Toggle AI for Player 2
    when 'p'
      @p2_ai = !@p2_ai
      @ai_status_text.content = "P2 AI: #{@p2_ai ? 'ON' : 'OFF'} (Press P to toggle)"
      @ai_status_text.color = (@p2_ai ? '#00ff88' : '#ffaa00')

    # Reset game
    when 'r'
      reset_game
    end
  end

  def handle_key_up(key)
    # Not needed for turn-based gameplay
  end

  def cleanup
    @render_objects.each(&:remove)
    @render_objects.clear
  end

  private

  def human_turn?
    @winner.nil? && (@current_player == 1 || !@p2_ai)
  end

  def x_for_col(col)
    @start_x + col * @cell_size
  end

  def y_for_row(row)
    @start_y + row * @cell_size
  end

  def move_selector(delta)
    @selected_col = (@selected_col + delta).clamp(0, COLS - 1)
    update_selector
  end

  def update_selector
    @selector_marker.x = x_for_col(@selected_col)
    @selector_marker.color = (@current_player == 1 ? COLOR_P1 : COLOR_P2)
  end

  def trigger_ai_move
    # Send current board to Python server
    @ai_client.send_state({
      grid: @grid,
      current_player: 2,
      winner: nil,
      game_over: false
    })

    # Wait for chosen column from AI server
    if (action = @ai_client.receive_action)
      chosen_col = action.to_i
      if chosen_col.between?(0, COLS - 1)
        @selected_col = chosen_col
        update_selector
        drop_piece(chosen_col)
      end
    else
      # Fallback heuristic if Python server is not currently running:
      # Pick first available non-full column
      valid_cols = (0...COLS).select { |c| @grid[0][c].nil? }
      if valid_cols.any?
        fallback_col = valid_cols.sample
        @selected_col = fallback_col
        update_selector
        drop_piece(fallback_col)
      end
    end
  end

  def notify_ai_game_over(winner_symbol)
    @ai_client.send_state({
      grid: @grid,
      current_player: @current_player,
      winner: winner_symbol,
      game_over: true
    })
  end

  def drop_piece(col)
    # Find lowest available row in column
    target_row = (ROWS - 1).downto(0).find { |r| @grid[r][col].nil? }
    return if target_row.nil? # Column is full

    # Place piece in grid and update circle color
    @grid[target_row][col] = @current_player
    @slots[target_row][col].color = (@current_player == 1 ? COLOR_P1 : COLOR_P2)

    # Check for win or draw
    if check_win(target_row, col, @current_player)
      @winner = @current_player
      @status_text.content = "Player #{@winner} Wins! (Press R to restart)"
      @status_text.color = (@winner == 1 ? COLOR_P1 : COLOR_P2)
      @status_text.x = Window.width / 2 - 140
      @selector_marker.color = '#333333'
      notify_ai_game_over(@winner)
    elsif check_draw
      @winner = :draw
      @status_text.content = "It's a Draw! (Press R to restart)"
      @status_text.color = 'white'
      @status_text.x = Window.width / 2 - 110
      @selector_marker.color = '#333333'
      notify_ai_game_over('draw')
    else
      # Switch turn
      @current_player = (@current_player == 1 ? 2 : 1)
      turn_name = (@current_player == 1 ? "Player 1's Turn (Red)" : "Player 2's Turn#{@p2_ai ? ' [AI]' : ''} (Yellow)")
      @status_text.content = turn_name
      @status_text.color = (@current_player == 1 ? COLOR_P1 : COLOR_P2)
      @status_text.x = Window.width / 2 - 130
      update_selector
    end
  end

  def check_win(row, col, player)
    directions = [
      [0, 1],   # Horizontal
      [1, 0],   # Vertical
      [1, 1],   # Diagonal down-right
      [1, -1]   # Diagonal down-left
    ]

    directions.any? do |dr, dc|
      count = 1
      count += count_consecutive(row, col, dr, dc, player)
      count += count_consecutive(row, col, -dr, -dc, player)
      count >= 4
    end
  end

  def count_consecutive(row, col, dr, dc, player)
    count = 0
    r = row + dr
    c = col + dc
    while r.between?(0, ROWS - 1) && c.between?(0, COLS - 1) && @grid[r][c] == player
      count += 1
      r += dr
      c += dc
    end
    count
  end

  def check_draw
    @grid[0].none?(&:nil?)
  end

  def reset_game
    @grid = Array.new(ROWS) { Array.new(COLS, nil) }
    @current_player = 1
    @winner = nil
    @selected_col = 3
    @ai_timer = 0

    ROWS.times do |r|
      COLS.times do |c|
        @slots[r][c].color = COLOR_EMPTY
      end
    end

    @status_text.content = "Player 1's Turn (Red)"
    @status_text.color = COLOR_P1
    @status_text.x = Window.width / 2 - 110
    update_selector
  end
end
