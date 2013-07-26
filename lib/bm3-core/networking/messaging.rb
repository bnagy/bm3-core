# An all in one interface to the way we use messaging for BM3.
# - sync send (publish via a broker) topic, message
# - install default or custom recv hooks for messages
# - Identifies itself with a UUID (for unicast)
#
# This is possibly a bit of a weird mix between sync and async patterns...
#
# Author: Ben Nagy
# Copyright: Copyright (c) Ben Nagy, 2006-2013.
# License: The MIT License
# (See http://www.opensource.org/licenses/mit-license.php for details.)

require 'msgpack'
require 'bm3-core/bm3_logger'
require_relative 'uuid' if RbConfig::CONFIG['host_os'] =~ /mswin|mingw/
require_relative 'hot_bunnies_messaging'

module BM3
  class Messaging

    # The MessageLayer mixin needs to implement:
    # PUBLIC:
    # - heartbeat delay, &blk
    # - send topic, msg
    # - destroy
    # PRIVATE:
    # - connect opts
    # - add_subscription topic, hook_instance
    #
    # This class does no error handling. You should handle reconnect logic and
    # such in the MessageLayer mixin.
    include MessageLayer::HotBunnies

    include BM3::Logger

    class Hook

      attr_reader :granularity

      def initialize messaging_instance, granularity
        @messaging   = messaging_instance
        @granularity = granularity || 1000
      end

      def send topic, msg
        @messaging.send topic, msg
      end

    end

    ##
    # Predefined message hooks which might be enough to do what the app needs.
    ##

    # if you don't care about the incoming stream
    class Discard < Hook

      def process topic, msg
        nil
      end

    end

    # If all you want is access to the raw messages
    class Enqueue < Hook
      attr_reader :messages

      def initialize zmq_ear, granularity
        @messages = Queue.new
        super
      end

      def process topic, msg
        @messages.push [topic, msg]
      end
    end

    # Allow introspection, in case the user hooks have methods that should be
    # exposed
    attr_reader :recv_hook, :opts

    def initialize opts, recv_hook_klass = Discard, topics = {}
      debug_info "setting up"
      @opts      = opts
      @debug     = opts['debug']
      @recv_hook = recv_hook_klass.new self, opts['message_hook_granularity']
      connect opts
      debug_info "Connected."
      # Subscribe to the unicast topic, always
      add_subscription id, @recv_hook
      debug_info "Subscribed to unicast on #{id}"
      # Subscribe to any extra topics, each with their own handler class
      topics.each {|topic, hook_klass|
        hook_instance = hook_klass.new self, opts['message_hook_granularity']
        add_subscription topic, hook_instance
        debug_info "Subscribed to #{topic} with #{hook_klass}"
      }
    end

    def id
      @id ||= create_uuid
    end

    def id= new_id
      @id = new_id
    end

    private

      def create_uuid
        if RbConfig::CONFIG['host_os'] =~ /mswin|mingw/
          UUID.create
        else
          # OSX and linux should have uuidgen...
          `uuidgen`.chomp.upcase
        end
      end

  end
end
