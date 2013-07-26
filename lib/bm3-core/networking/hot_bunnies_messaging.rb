# Messaging layer for HotBunnies
#
# Author: Ben Nagy
# Copyright: Copyright (c) Ben Nagy, 2006-2013.
# License: The MIT License
# (See http://www.opensource.org/licenses/mit-license.php for details.)

require 'msgpack'
require 'hot_bunnies'

module BM3
  module MessageLayer
    module HotBunnies

      SLEEPTIME = 5

      def heartbeat delay, &blk
        raise ArgumentError, "#{__meth__}: No heartbeat block given." unless block_given?
        @heartbeat_thread = Thread.new do
          debug_info "Starting heartbeat thread."
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
        @subscriptions.values.map( &:shutdown! )
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
            @connection       = ::HotBunnies.connect host: rabbitmq_server
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
          @subscriptions.values.map( &:shutdown! )
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
          current_subscription = topic_queue.subscribe ack: true
          @subscriptions[ [topic, hook_instance] ] = current_subscription
          # Start the nonblocking handler
          current_subscription.each( blocking: false ) {|headers, msg|
            headers.ack
            hook_instance.process topic, (MessagePack.unpack( msg ) rescue msg)
          }
          debug_info "Subscribed to #{topic_queue}"
        end

    end
  end
end
