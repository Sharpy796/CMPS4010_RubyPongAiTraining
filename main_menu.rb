require 'ruby2d'
require_relative 'pong'

set title: "Arcade Hub", width: 640, height: 480

# --- MENU CLASS ---
class Menu
  def initialize
    @title = Text.new("ARCADE MENU", x: 200, y: 100, size: 36, color: '#00ffff')
    @opt1  = Text.new("Press 1 for Pong", x: 180, y: 200, size: 22, color: 'red')
    @opt2  = Text.new("Connect 4 Coming Soon!", x: 180, y: 250, size: 22, color: 'red')
    @hint  = Text.new("Press ESC in any game to return to Menu", x: 150, y: 380, size: 16, color: 'gray')
  end

  def hide
    @title.remove
    @opt1.remove
    @opt2.remove
    @hint.remove
  end

  def show
    @title.add
    @opt1.add
    @opt2.add
    @hint.add
  end
end

# --- GAME 1: Simple Clicker (Dummy Game) ---
=begin
class ClickerGame
  def initialize
    @score = 0
    @title = Text.new("Clicker Game!", x: 230, y: 130, size: 28, color: 'yellow')
    @score_text = Text.new("Score: 0", x: 270, y: 190, size: 24, color: 'white')
    @instructions = Text.new("Press SPACE to score | Press ESC for Menu", x: 130, y: 270, size: 18, color: 'gray')
  end

  def handle_key_down(key)
    if key == 'space'
      @score += 1
      @score_text.text = "Score: #{@score}"
    end
  end

  def handle_key_up(key)
    # No action needed for clicker
  end

  def cleanup
    @title.remove
    @score_text.remove
    @instructions.remove
  end
end
=end
# --- STATE AND INSTANCES ---
$current_state = :menu # :menu, :clicker, :pong
menu = Menu.new
active_game = nil

# --- MAIN GAME LOOP ---
update do
  case $current_state
  when :pong
    active_game.update if active_game
  end
end

# --- KEY DOWN ROUTER ---
on :key_down do |event|
  case $current_state
  when :menu
    #if event.key == '1'
      #menu.hide
      #active_game = ClickerGame.new
      #$current_state = :clicker
    if event.key == '1'
      menu.hide
      active_game = PongGame.new
      $current_state = :pong
    end

  when :clicker, :pong
    if event.key == 'escape'
      active_game.cleanup if active_game
      active_game = nil
      menu.show
      $current_state = :menu
    else
      active_game.handle_key_down(event.key) if active_game
    end
  end
end

# --- KEY UP ROUTER ---
on :key_up do |event|
  case $current_state
  when :pong, :clicker
    active_game.handle_key_up(event.key) if active_game
  end
end

show
