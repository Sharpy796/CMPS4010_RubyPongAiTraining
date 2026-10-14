require 'ruby2d'

# Window setup
set title: "Pong"
set background: '#000000'
set width: 640
set height: 480
$game_color_1 = '#ff00ff'
$game_color_2 = '#00ffff'

class Paddle
  HEIGHT = 100
  WIDTH = 20

  attr_reader :x, :y
  attr_writer :direction

  def initialize(side)
    @direction = nil
    @y = 165
    @movement_speed = 8

    if side == :left
      @x = 40
    else
      @x = 580
    end
  end

  def move
    if @direction == :up
      @y = [@y - @movement_speed, 0].max
    elsif @direction == :down
      @y = [@y + @movement_speed, max_y].min
    end
  end

  def draw
    Rectangle.new(x: @x, y: @y, width: WIDTH, height: HEIGHT, color: $game_color_1)
  end

  private

  def max_y
    Window.height - HEIGHT
  end
end

class Ball
  SIZE = 15
  BEEP_PADDLE = Sound.new('audio/retro-pong-hit-sfx.wav')
  BEEP_WALL = Sound.new('audio/retro-buzzer-hit-sfx.wav')
  attr_reader :x, :y, :x_speed, :y_speed

  def initialize
    reset
  end

  def reset
    @x = Window.width / 2
    @y = Window.height / 2
    @x_speed = [5,-5].sample
    @y_speed = rand(-4..4)
    @y_speed = 3 if @y_speed.zero?
  end

  def beep_wall
    if !$muted
      Ball::BEEP_WALL.play
    end
  end

  def beep_paddle
    if !$muted
      Ball::BEEP_PADDLE.play
    end
  end

  def move
    @x += @x_speed
    @y += @y_speed

    # Bounce off top and bottom walls
    if @y <= 0
      @y_speed = (@y_speed).abs
      beep_wall
    elsif @y + SIZE >= Window.height
      @y_speed = -(@y_speed).abs
      beep_wall
    end
  end

  def draw
    Square.new(x: @x, y: @y, size: SIZE, color: $game_color_2)
  end

  def collides_with?(paddle)
    @x < paddle.x + Paddle::WIDTH &&
      @x + SIZE > paddle.x &&
      @y < paddle.y + Paddle::HEIGHT &&
      @y + SIZE > paddle.y
  end

  def bounce_x(paddle)
    beep_paddle
    # Set speed to a faster speed after the first hit
    @x_speed = -8*(@x_speed<=>0)
    # Change y speed based on distance from center of paddle
    diff = @y - paddle.y + Ball::SIZE/2
    @y_speed = (diff-(Paddle::HEIGHT/2)).to_f/(Paddle::HEIGHT).to_f*2*6
  end
end

# Game objects
p1 = Paddle.new(:left)   # Left player (W/S)
p2 = Paddle.new(:right)  # Right player / AI (Up/Down)
ball = Ball.new

# Score trackers
p1_score = 0
p2_score = 0

# Countdown trackers
scored = false
framesAfterScored = 0
countdown_speed = 30

# Audio
$muted = true

# Keybind flags
shifting = false
ming = false

# Game loop (60 FPS)
update do
  clear

  # Move paddles
  p1.move
  p2.move

  if scored
    # Enact countdown
    framesAfterScored += 1
    if framesAfterScored >= countdown_speed*3
      ball.reset
      framesAfterScored = 0
      scored = false
    elsif framesAfterScored >= countdown_speed*2
      Text.new('1', x: Window.width/2-15, y: Window.height/2-30, size: 60, color: $game_color_2)
    elsif framesAfterScored >= countdown_speed
      Text.new('2', x: Window.width/2-15, y: Window.height/2-30, size: 60, color: $game_color_2)
    else
      Text.new('3', x: Window.width/2-15, y: Window.height/2-30, size: 60, color: $game_color_2)
    end
  else
    # Move ball
    ball.move
    
    # Paddle collisions
    if ball.collides_with?(p1)
      ball.bounce_x(p1)
    elsif ball.collides_with?(p2)
      ball.bounce_x(p2)
    end
  
    # Scoring check
    if ball.x <= 0
      p2_score += 1
      ball.beep_wall
      scored = true
    elsif ball.x >= Window.width-Ball::SIZE
      p1_score += 1
      ball.beep_wall
      scored = true
    end
  end

  # Draw entities
  ball.draw
  p1.draw
  p2.draw

  # Display score
  Text.new("#{p1_score}   #{p2_score}", x: Window.width / 2 - 30, y: 20, size: 30, color: $game_color_2)
end

# Key down handlers
on :key_down do |event|
  case event.key
  # Player 1 (Left) Controls
  when 'w'
    p1.direction = :up
  when 's'
    p1.direction = :down

  # AI / Player 2 (Right) Controls
  when 'up'
    p2.direction = :up
  when 'down'
    p2.direction = :down

  # Other keybinds
  when 'left shift', 'right shift'
    shifting = true
  when 'c'
    if shifting
      close
    end
  when 'm'
    if !ming
      $muted = !$muted
      if $muted
        puts 'Muted!'
      else
        puts 'Unmuted!'
      end
    end
    ming = true
  end
end

# Key up handlers
on :key_up do |event|
  case event.key
  when 'w', 's'
    p1.direction = nil
  when 'up', 'down'
    p2.direction = nil
  when 'left shift', 'right shift'
    shifting = false
  when 'm'
    ming = false
  end
end

show