require 'ruby2d'
require 'socket'
require_relative 'pong'

set title: "Pong", width: 640, height: 480

AI_READY_PORT = 54321

def close_ai(pid)
  return unless pid # 2-player mode has no AI process

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
    @title.x = (Window.width - @title.width) / 2
    @hint  = Text.new("Press ESC in any game to return to Menu", x: 170, y: 380, size: 16, color: 'gray')
    @hint.x = (Window.width - @hint.width) / 2
    @loading = Text.new("Loading...", x: 194, y: 80, size: 36, color: '#00ffff')
    @loading.x = (Window.width - @loading.width) / 2
    @loading.y = (Window.height - @loading.height) / 2
    @loading.remove

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

    @btn_2player.x = (Window.width - @btn_2player.width) / 2
    @btn_demo.x = (Window.width - @btn_demo.width) / 2
    @btn_train.x = (Window.width - @btn_train.width) / 2
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

  # Called once per frame while $current_state == :loading.
  # Never blocks, so the window keeps redrawing.
  def poll_loading
    dots = ((Time.now - @load_started) * 3).to_i % 4
    @loading.content = "Loading" + "." * dots

    # Timeout of 0 = check and return immediately
    return unless IO.select([@ready_sock], nil, nil, 0)

    msg, _ = @ready_sock.recvfrom(64)
    return unless msg.strip == "ready"

    cancel_loading
    $active_game = PongGame.new($current_mode)
    $current_state = :pong
  end

  # Tears down the loading screen (used when ready, and when ESC is pressed)
  def cancel_loading
    @loading.remove
    @ready_sock&.close
    @ready_sock = nil
  end

  private

  def begin_loading
    @loading.content = "Loading"
    @loading.add
    @load_started = Time.now
    @ready_sock = UDPSocket.new
    @ready_sock.bind("127.0.0.1", AI_READY_PORT)
    $current_state = :loading
  end

  def start_game(game_mode)
    hide
    $current_mode = game_mode

    case game_mode
    when :two_player
      $active_game = PongGame.new(game_mode)
      $current_state = :pong
    when :demo
      $ai_pid = spawn(".venv/bin/python ai.py")
      begin_loading
    when :train
      $ai_pid = spawn(".venv/bin/python ai.py train")
      begin_loading
    end
    $steps = ($current_mode == :train) ? 3 : 1
  end
end

# --- STATE AND INSTANCES ---
$current_state = :menu # :menu, :loading, :pong
$active_game = nil
$ai_pid = nil
menu = Menu.new

# --- MAIN GAME LOOP ---
update do
  case $current_state
  when :loading
    menu.poll_loading
  when :pong
    $steps.times { $active_game.update } if $active_game
    # $active_game.update if $active_game
  end
end

# --- KEY DOWN ROUTER ---
on :key_down do |event|
  case $current_state
  when :menu
    # Keyboard shortcuts to start games directly
    case event.key
    when '1' then menu.send(:start_game, :two_player)
    when '2' then menu.send(:start_game, :demo)
    when '3' then menu.send(:start_game, :train)
    end

  when :loading
    if event.key == 'escape'
      menu.cancel_loading
      close_ai($ai_pid)
      $ai_pid = nil
      menu.show
      $current_state = :menu
    end

  when :pong
    if event.key == 'escape'
      $active_game.cleanup if $active_game
      $active_game = nil
      close_ai($ai_pid)
      $ai_pid = nil
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