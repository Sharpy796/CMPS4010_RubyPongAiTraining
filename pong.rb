require 'ruby2d'
require_relative 'socket_client' # Loads your socket client helper

# Initialize AI Socket Client
ai_client = AIClient.new

# Window setup
set title: "Pong"
set background: '#000000'
set width: 640
set height: 480
set icon: 'icons/pong_icon.png'
$game_color_1 = '#ff00ff'
$game_color_2 = '#00ffff'
$p1_cpu = true
$p2_cpu = true

class Paddle
  HEIGHT = 100
  WIDTH = 20

  attr_reader :x, :y, :side
  attr_writer :direction, :y

  def initialize(side)
    @side = side
    @direction = nil
    @y = 165
    @movement_speed = 8

    if side == :left
      @x = 40
    else
      @x = 580
    end
    
    @obj = Rectangle.new(x: @x, y: @y, width: WIDTH, height: HEIGHT, color: $game_color_1)
  end

  def move
    if @direction == :up
      @y = [@y - @movement_speed, 0].max
    elsif @direction == :down
      @y = [@y + @movement_speed, max_y].min
    end
  end

  def draw
    @obj.x = @x
    @obj.y = @y
  end

  private

  def max_y
    Window.height - HEIGHT
  end
end

class Ball
  SIZE = 15
  attr_reader :x, :y, :x_speed, :y_speed

  def initialize
    reset
    @obj = Square.new(x: @x, y: @y, size: SIZE, color: $game_color_2)
  end

  def reset
    @x = Window.width / 2
    @y = Window.height / 2
    @x_speed = [5,-5].sample
    @y_speed = rand(-4..4)
    @y_speed = 3 if @y_speed.zero?
  end

  def move
    @x += @x_speed
    @y += @y_speed

    # Bounce off top and bottom walls
    if @y <= 0
      @y_speed = (@y_speed).abs
    elsif @y + SIZE >= Window.height
      @y_speed = -(@y_speed).abs
    end
  end

  def draw
    @obj.x = @x
    @obj.y = @y
  end

  def collides_with?(paddle)
    @x < paddle.x + Paddle::WIDTH &&
      @x + SIZE > paddle.x &&
      @y < paddle.y + Paddle::HEIGHT &&
      @y + SIZE > paddle.y
  end

  def bounce_x(paddle)
    # beep_paddle
    # Set speed to a faster speed after the first hit
    if paddle.side == :left
      @x_speed = 8
    else
      @x_speed = -8
    end
    # Change y speed based on distance from center of paddle
    diff = @y - paddle.y + SIZE/2
    @y_speed = (diff-(Paddle::HEIGHT/2)).to_f/(Paddle::HEIGHT).to_f*2*6
  end
end

class Score
  attr_reader :p1, :p2

  def initialize
    @obj = Text.new("foobar", x: Window.width / 2 - 30, y: 20, size: 30, color: $game_color_2)
    reset
  end

  def reset
    @p1 = 0
    @p2 = 0
    update
  end

  def p1_win
    @p1 += 1
    update
  end

  def p2_win
    @p2 += 1
    update
  end

  def update
    @obj.text = "#{@p1}   #{@p2}"
  end
end

# Game objects
p1 = Paddle.new(:left)   # Left player (W/S)
p2 = Paddle.new(:right)  # Right player / AI (Up/Down)
ball = Ball.new
score = Score.new


# Countdown trackers
scored = false
framesAfterScored = 0
countdown_speed = 30

# Keybind flags
ctrling = false
ming = false

# Game loop (60 FPS)
update do

  # --- AI Communication Block ---
  # Send state to Python PyTorch Server
  ai_client.send_state({
    ball_x: ball.x,
    ball_y: ball.y,
    ball_x_speed: ball.x_speed,
    ball_y_speed: ball.y_speed,
    paddle_y: p2.y,
    scored: scored
  })

  # Read decision from Python Server and steer p2
  if ($p2_cpu && action = ai_client.receive_action)
    case action
    when 'up'   then p2.direction = :up
    when 'down' then p2.direction = :down
    else             p2.direction = nil
    end
  end
  # ------------------------------

  # Move paddles
  # p1.move
  if $p1_cpu
    center = p1.y + Paddle::HEIGHT / 2

    if ball.y < center - 10 - Ball::SIZE
      p1.direction = :up
    elsif ball.y > center + 10 + Ball::SIZE
      p1.direction = :down
    else
      p1.direction = nil
    end
  end

  p1.move
  p2.move

  # TODO: Implement separate "paused" variable for countdown management
  # "scored" is used to report scoring events in the ai
  if scored
    # # Enact countdown
    # framesAfterScored += 1
    # if framesAfterScored >= countdown_speed*3
    #   ball.reset
    #   framesAfterScored = 0
    #   scored = false
    # elsif framesAfterScored >= countdown_speed*2
    #   Text.new('1', x: Window.width/2-15, y: Window.height/2-30, size: 60, color: $game_color_2)
    # elsif framesAfterScored >= countdown_speed
    #   Text.new('2', x: Window.width/2-15, y: Window.height/2-30, size: 60, color: $game_color_2)
    # else
    #   Text.new('3', x: Window.width/2-15, y: Window.height/2-30, size: 60, color: $game_color_2)
    # end
    scored = false
  else
    # Move ball
    ball.move
    
    # Paddle collisions
    if ball.collides_with?(p1)
      ball.bounce_x(p1)
    elsif ball.collides_with?(p2)
      if $p1_cpu # TODO: Isolate this to the "1-player" mode rather than $p1_cpu
        score.p2_win # count the number of times the ai bounced the ball
      end
      ball.bounce_x(p2)
    end
  
    # Scoring check
    if ball.x <= 0
      score.p2_win
      # scored = true
      ball.reset
    elsif ball.x >= Window.width-Ball::SIZE
      score.p1_win
      scored = true
      ball.reset
    end
  end

  # Draw entities
  ball.draw
  p1.draw
  p2.draw
end

# Key down handlers
on :key_down do |event|
  case event.key
  # Player 1 (Left) Controls
  when 'w'
    p1.direction = :up
  when 's'
    p1.direction = :down

  # AI / Player 2 (Right) Controls (Manual Override)
  when 'up'
    p2.direction = :up
  when 'down'
    p2.direction = :down

  # Other keybinds
  when 'p'
    $p1_cpu = !$p1_cpu
    p1.direction = nil
  when 'o'
    $p2_cpu = !$p2_cpu
    p2.direction = nil
  when 'left ctrl', 'right ctrl'
    ctrling = true
  when 'c'
    if ctrling
      close
    end
  end
end

# Key up handlers
on :key_up do |event|
  case event.key
  when 'w', 's'
    p1.direction = nil
  when 'up', 'down'
    p2.direction = nil
  when 'left ctrl', 'right ctrl'
    ctrling = false
  end
end

show