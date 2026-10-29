require 'ruby2d'
require_relative 'pong'
require_relative 'connect4'

set title: "Arcade Hub", width: 640, height: 480

# --- MENU CLASS ---
class Menu
  attr_reader :btn_pong, :btn_connect4

  def initialize
    @title = Text.new("ARCADE MENU", x: 170, y: 80, size: 36, color: '#00ffff')
    @hint  = Text.new("Press ESC in any game to return to Menu", x: 170, y: 380, size: 16, color: 'gray')

    # Button 1: Pong
    @btn_pong = Button.new(
      x: 225, y: 160,
      width: 190, height: 35,
      label: 'Play Pong',
      color: '#FF00FF',
      hover_color: '#444444',
      pressed_color: '#ff9800'
    ) do
      start_game(:pong)
    end

    # Button 2: Connect 4
    @btn_connect4 = Button.new(
      x: 225, y: 220,
      width: 190, height: 35,
      label: 'Play Connect 4',
      color: '#0033cc',
      hover_color: '#0055ff',
      pressed_color: '#0088ff'
    ) do
      start_game(:connect4)
    end
  end

  def hide
    @title.remove
    @hint.remove
    @btn_pong.remove
    @btn_connect4.remove
  end

  def show
    @title.add
    @hint.add
    @btn_pong.add
    @btn_connect4.add
  end

  private

  def start_game(game_type)
    hide
    case game_type
    when :pong
      $active_game = PongGame.new
      $current_state = :pong
    when :connect4
      $active_game = Connect4Game.new
      $current_state = :connect4
    end
  end
end

# --- STATE AND INSTANCES ---
$current_state = :menu # :menu, :pong, :connect4
$active_game = nil
menu = Menu.new

# --- MAIN GAME LOOP ---
update do
  case $current_state
  when :pong, :connect4
    $active_game.update if $active_game
  end
end

# --- KEY DOWN ROUTER ---
on :key_down do |event|
  case $current_state
  when :menu
    # Keyboard shortcuts to start games directly
    if event.key == '1'
      menu.send(:start_game, :pong)
    elsif event.key == '2'
      menu.send(:start_game, :connect4)
    end

  when :pong, :connect4
    if event.key == 'escape'
      $active_game.cleanup if $active_game
      $active_game = nil
      menu.show
      $current_state = :menu
    else
      $active_game.handle_key_down(event.key) if $active_game
    end
  end
end

# --- KEY UP ROUTER ---
on :key_up do |event|
  case $current_state
  when :pong, :connect4
    $active_game.handle_key_up(event.key) if $active_game
  end
end

show
