# Messaging layer for MarchHare, which seems to be a newer version of
# hot_bunnies gem with a drop-in compatible API.
#
# Author: Ben Nagy
# Copyright: Copyright (c) Ben Nagy, 2006-2013.
# License: The MIT License
# (See http://www.opensource.org/licenses/mit-license.php for details.)

require 'msgpack'
require 'march_hare'

module BM3
  module MessageLayer
    module MarchHare

      SLEEPTIME = 5

      def heartbeat delay, &blk
        raise ArgumentError, "#{__meth__}: No heartbeat block given." unless block_given?
        @heartbeat_thread = Thread.new do
          debug_info "Starting heartbeat thread, #{delay} second loop."
          loop do
            topic, msg = yield
            send topic, msg
            sleep delay
          end
        end
      end

      def send topic, msg
        begin
          @exchange.publish MessagePack.pack( msg ), routing_key: topic
        rescue
          debug_info "Error in send: #{$!}"
          reconnect
          sleep SLEEPTIME and retry
        end
      end

      def destroy
        @subscriptions.values.map( &:cancel )
        debug_info "Shutdown subscribtions..."
        # These will raise if they're already closed. Ignore.
        @channel.close rescue nil
        @connection.close rescue nil
        @heartbeat_thread.kill if @heartbeat_thread
        debug_info "Shutdown done."
      end

      private

        def connect opts
          begin
            rabbitmq_server   = opts['servers'].first rescue 'localhost'
            @connection       = ::MarchHare.connect host: rabbitmq_server
            @channel          = @connection.create_channel
            @channel.prefetch = 10
            @exchange         = @channel.exchange 'BM3', type: :direct
            debug_info "Connected"
          rescue
            debug_info "Error in connect: #{$!}"
            sleep SLEEPTIME and retry
          end
        end

        def reconnect
          debug_info "Attempting to reconnect..."
          @subscriptions.values.map( &:cancel )
          debug_info "Shutdown subscribtions..."
          # These will raise if they're already closed. Ignore.
          @channel.close rescue nil
          @connection.close rescue nil
          connect opts
          @subscriptions.each {|(topic, hook_instance), subscription|
            add_subscription topic, hook_instance
          }
        end

        def add_subscription topic, hook_instance
          @subscriptions ||= {}
          topic_queue = @channel.queue "#{id}-#{topic}"
          topic_queue.bind @exchange, routing_key: topic
          topic_queue.purge
          current_subscription = topic_queue.subscribe(:ack => true, :blocking => false) {|headers, msg|
            headers.ack
            hook_instance.process topic, ( MessagePack.unpack(msg) rescue msg )
          }
          @subscriptions[[topic, hook_instance]] = current_subscription
          debug_info "Subscribed to #{topic} with #{hook_instance.class}"
        end

    end
  end
end
