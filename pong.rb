require 'ruby2d'
require_relative 'socket_client' # Loads your socket client helper

class PongGame
  DEMOING = false

  # Nested Classes
  class Paddle
    HEIGHT = 100
    WIDTH = 20

    attr_reader :x, :y, :side
    attr_writer :direction, :y

    def initialize(side, color)
      @side = side
      @direction = nil
      @y = 165
      @movement_speed = 8

      if side == :left
        @x = 40
      else
        @x = 580
      end
      
      @obj = Rectangle.new(x: @x, y: @y, width: WIDTH, height: HEIGHT, color: color)
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

    def remove
      @obj.remove
    end

    private

    def max_y
      Window.height - HEIGHT
    end
  end

  class Ball
    SIZE = 15
    attr_reader :x, :y, :x_speed, :y_speed

    def initialize(color)
      reset
      @obj = Square.new(x: @x, y: @y, size: SIZE, color: color)
    end

    def reset
      @x = Window.width / 2
      @y = Window.height / 2
      @x_speed = [5, -5].sample
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

    def remove
      @obj.remove
    end

    def collides_with?(paddle)
      @x < paddle.x + Paddle::WIDTH &&
        @x + SIZE > paddle.x &&
        @y < paddle.y + Paddle::HEIGHT &&
        @y + SIZE > paddle.y
    end

    def bounce_x(paddle)
      # Set speed to a faster speed after the first hit
      if paddle.side == :left
        @x_speed = 8
      else
        @x_speed = -8
      end
      # Change y speed based on distance from center of paddle
      diff = @y - paddle.y + SIZE / 2
      @y_speed = (diff - (Paddle::HEIGHT / 2)).to_f / (Paddle::HEIGHT).to_f * 2 * 6
    end
  end

  class Score
    attr_reader :p1, :p2

    def initialize(color)
      @obj = Text.new("foobar", x: Window.width / 2 - 30, y: 20, size: 30, color: color)
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
      @obj.content = "#{@p1}   #{@p2}"
    end

    def remove
      @obj.remove
    end
  end

  class Epsilon
    def initialize(color)
      @EPSILON_START = 1.00
      @EPSILON_END = 0.05
      @EPSILON_DECAY = 0.9999
      @effective_epsilon = @EPSILON_START
      @obj = Text.new("ε", x: Window.width / 2 - 65, y: Window.height - 40, size: 30, color: color, font: '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf')
      update
    end

    def increment
      if @effective_epsilon > @EPSILON_END
        @effective_epsilon *= @EPSILON_DECAY
      end
      update
    end

    def update
      @obj.content = "ε: #{@effective_epsilon.round(5)}"
    end

    def hide
      @obj.remove
    end

    def show
      @obj.add
    end

    def remove
      @obj.remove
    end
  end

  # Main PongGame Controller Methods
  def initialize
    @game_color_1 = '#ff00ff'
    @game_color_2 = '#00ffff'
    $p1_cpu = true
    $p2_cpu = true

    # Initialize AI Socket Client
    @ai_client = AIClient.new

    # Game objects
    @p1 = Paddle.new(:left, @game_color_1)
    @p2 = Paddle.new(:right, @game_color_1)
    @ball = Ball.new(@game_color_2)
    @score = Score.new(@game_color_2)
    @epsilon = Epsilon.new(@game_color_2)
    @epsilon.hide if DEMOING

    @scored = false
    @ctrling = false
  end

  # Game loop (60 FPS)
  def update
    # --- AI Communication Block ---
    # Send state to Python PyTorch Server
    @ai_client.send_state({
      ball_x: @ball.x,
      ball_y: @ball.y,
      ball_x_speed: @ball.x_speed,
      ball_y_speed: @ball.y_speed,
      paddle_y: @p2.y,
      scored: @scored
    })

    # Read decision from Python Server and steer p2
    if ($p2_cpu && action = @ai_client.receive_action)
      case action
      when 'up'   then @p2.direction = :up
      when 'down' then @p2.direction = :down
      else             @p2.direction = nil
      end
    end
    # ------------------------------

    # Move paddles
    if $p1_cpu
      center = @p1.y + Paddle::HEIGHT / 2

      if @ball.y < center - 10 - Ball::SIZE
        @p1.direction = :up
      elsif @ball.y > center + 10 + Ball::SIZE
        @p1.direction = :down
      else
        @p1.direction = nil
      end
    end

    @p1.move
    @p2.move

    if @scored
      @scored = false
    else
      # Move ball
      @ball.move
      
      # Paddle collisions
      if @ball.collides_with?(@p1)
        @ball.bounce_x(@p1)
      elsif @ball.collides_with?(@p2)
        if $p1_cpu
          @score.p2_win # count the number of times the ai bounced the ball
        end
        @ball.bounce_x(@p2)
      end
    
      # Scoring check
      if @ball.x <= 0
        @score.p2_win
        @ball.reset
      elsif @ball.x >= Window.width - Ball::SIZE
        @score.p1_win
        @scored = true
        @ball.reset
      end
    end

    # Draw entities
    @ball.draw
    @p1.draw
    @p2.draw
    @epsilon.increment
  end

  # Key down handlers
  def handle_key_down(key)
    case key
    # Player 1 (Left) Controls
    when 'w'
      @p1.direction = :up
    when 's'
      @p1.direction = :down

    # AI / Player 2 (Right) Controls (Manual Override)
    when 'up'
      @p2.direction = :up
    when 'down'
      @p2.direction = :down

    # Other keybinds
    when 'p'
      $p1_cpu = !$p1_cpu
      @p1.direction = nil
    when 'o'
      $p2_cpu = !$p2_cpu
      @p2.direction = nil
    when 'e'
      $DEMOING = !$DEMOING
      if $DEMOING
        @epsilon.hide
      else
        @epsilon.show
      end
    end
  end

  # Key up handlers
  def handle_key_up(key)
    case key
    when 'w', 's'
      @p1.direction = nil
    when 'up', 'down'
      @p2.direction = nil
    end
  end

  # Clean up all shapes/text when leaving Pong to go back to Menu
  def cleanup
    @p1.remove
    @p2.remove
    @ball.remove
    @score.remove
    @epsilon.remove
  end
end