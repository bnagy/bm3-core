# Test code for Messaging. Should work, whichever backend messaging layer is is
# use.
#
# Author: Ben Nagy
# Copyright: Copyright (c) Ben Nagy, 2006-2013.
# License: The MIT License
# (See http://www.opensource.org/licenses/mit-license.php for details.)

require 'bm3-core'

opts={
  'debug'=>true,
  'servers'=>['127.0.0.1'],
  'port'=>11300
}

include BM3

class RecvHook < Messaging::Hook

  include BM3::Logger

  def initialize *args
    debug_on
    super
  end

  def process( topic, msg )
    debug_info "#{topic}: #{msg.inspect}"
  end

end

# mandatory hook class for unicast, optional classes for topics
b = Messaging.new opts, RecvHook, "broadcast" => RecvHook

10.times do
  b.send b.id, "Hey anyone there?"
  b.send "broadcast", "Broadcast Message!"
  b.send "LOST IN SPACE", 'does_not_exist'
  b.send b.id, "Let's blow this joint."
  sleep 1
end

b.destroy
sleep 1
