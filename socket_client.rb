require 'socket'
require 'json'

class AIClient
  def initialize(host = '127.0.0.1', port = 65432)
    @socket = UDPSocket.new
    @host = host
    @port = port
  end

  # Sends game state hash to Python server
  def send_state(state)
    @socket.send(state.to_json, 0, @host, @port)
  end

  # Non-blocking receive for current action
  def receive_action
    action, _ = @socket.recvfrom_nonblock(1024)
    action
  rescue IO::EAGAINWaitReadable, Errno::ECONNREFUSED
    nil # Returns nil if Python hasn't responded yet or is offline
  end
end