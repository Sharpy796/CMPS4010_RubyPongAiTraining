require 'socket'
require 'json'

class AIClient
    attr_reader :epsilon

  def initialize(host = '127.0.0.1', port = 65432)
    @socket = UDPSocket.new
    @host = host
    @port = port
    @epsilon = nil
  end

  # Sends game state hash to Python server
  def send_state(state)
    @socket.send(state.to_json, 0, @host, @port)
  end

  # Non-blocking receive for current action
  def receive_action
    parse_reply(@socket.recvfrom_nonblock(1024).first)
  rescue IO::EAGAINWaitReadable, Errno::ECONNREFUSED
    nil
  end

  # Blocks until Python replies (or the timeout passes), for lockstep training
  def receive_action_blocking(timeout = 0.1)
    return nil unless IO.select([@socket], nil, nil, timeout)
    parse_reply(@socket.recvfrom(1024).first)
  rescue Errno::ECONNREFUSED
    nil
  end

  private

  def parse_reply(raw)
    data = JSON.parse(raw)
    @epsilon = data["epsilon"]
    data["action"]
  rescue JSON::ParserError
    nil
  end
end