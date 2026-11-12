require 'ruby2d'
require_relative 'pong'

set title: "Pong", width: 640, height: 480

def close_ai(pid)
  begin
    Process.kill("TERM", pid)

    deadline = Time.now + 5
    until Process.waitpid(pid, Process::WNOHANG)
      if Time.now > deadline
        Process.kill("KILL", pid)
        Process.waitpid(pid)
        break
      end
      sleep 0.1
    end
  rescue Errno::ESRCH, Errno::ECHILD
    # process already exited
  end
end

# --- MENU CLASS ---
class Menu
  attr_reader :btn_2player, :btn_demo, :btn_train

  def initialize
    @title = Text.new("CPaoU PONG", x: 194, y: 80, size: 36, color: '#00ffff')
    @hint  = Text.new("Press ESC in any game to return to Menu", x: 170, y: 380, size: 16, color: 'gray')

    # Button 1: 2-Player
    @btn_2player = Button.new(
      x: 225, y: 160,
      width: 190, height: 35,
      label: '2-Player',
      color: '#FF00FF',
      hover_color: '#444444',
      pressed_color: '#ff9800'
    ) do
      start_game(:two_player)
    end
    
    # Button 2: 1-Player Demo
    @btn_demo = Button.new(
      x: 225, y: 205,
      width: 190, height: 35,
      label: '1-Player (VS AI)',
      color: '#FF00FF',
      hover_color: '#444444',
      pressed_color: '#ff9800'
    ) do
      start_game(:demo)
    end
    
    # Button 1: 0-Player Training
    @btn_train = Button.new(
      x: 225, y: 250,
      width: 190, height: 35,
      label: '0-Player (Train AI)',
      color: '#FF00FF',
      hover_color: '#444444',
      pressed_color: '#ff9800'
    ) do
      start_game(:train)
    end
  end

  def hide
    @title.remove
    @hint.remove
    @btn_2player.remove
    @btn_demo.remove
    @btn_train.remove
  end

  def show
    @title.add
    @hint.add
    @btn_2player.add
    @btn_demo.add
    @btn_train.add
  end

  private

  def start_game(game_mode)
    hide
    $current_mode = game_mode
    $active_game = PongGame.new(game_mode)
    $current_state = :pong
    case game_mode
    when :two_player
      # don't do anything with the ai
    when :demo
      $ai_pid = spawn(".venv/bin/python ai.py")
    when :train
      $ai_pid = spawn(".venv/bin/python ai.py train")
    end
  end
end

# --- STATE AND INSTANCES ---
$current_state = :menu # :menu, :pong
$active_game = nil
menu = Menu.new

# --- MAIN GAME LOOP ---
update do
  case $current_state
  when :pong
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
      menu.send(:start_game)
    end

  when :pong
    if event.key == 'escape'
      $active_game.cleanup if $active_game
      $active_game = nil
      close_ai($ai_pid)
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
  when :pong
    $active_game.handle_key_up(event.key) if $active_game
  end
end
at_exit do
  close_ai($ai_pid)
end
show
