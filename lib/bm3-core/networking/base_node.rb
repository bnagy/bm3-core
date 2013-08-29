# Abstraction for Actor pattern. Essentially, you can create various 'nodes' in
# your code that let you push or pull to 'tubes'. Those tubes are worked on my
# one or more other Actors.
#
# For BM3 the PDUs are Hashes that are serialized with MessagePack, but that's
# not coupled to this stuff.
#
# This is the base class, check nodes.rb
#
# Author: Ben Nagy
# Copyright: Copyright (c) Ben Nagy, 2006-2013.
# License: The MIT License
# (See http://www.opensource.org/licenses/mit-license.php for details.)

require 'msgpack'
require 'zlib'
require 'beanstalk-client'
require 'bm3-core/bm3_logger'

module BM3
  class BaseNode
    # Base class for all nodes
    SNOOZE_TIME = 5
    MAX_BACKOFF = 5

    include BM3::Logger

    class BadChecksum < StandardError; end

    attr_reader :count, :id, :in_tube, :out_tube

    def initialize in_tube, out_tube, opts={}
      @debug       = opts['debug']
      @queue_limit = opts['queue_limit'] || Float::INFINITY
      @port        = opts['port'] || 11300
      servers      = opts['servers'] || ['127.0.0.1']
      @servers     = servers.map {|srv_str| "#{srv_str}:#{@port}" }
      @count       = 0
      @id          = 'NOT_SET'
      debug_info "Setting up"
      beanstalk_connect
      debug_info "Connected"
    end

    def id= new_id
      @id = new_id
      debug_info "Set id to #{new_id}"
    end

    def pull &blk

      begin
        # Stay in this block until we get a usable message
        debug_info "Waiting for a job..."
        job = @beanstalk.reserve
        debug_info "Got a job!"
        pdu = MessagePack.unpack job.body
        raise BadChecksum, "Bad Checksum!" unless checksum_ok? pdu
      rescue Beanstalk::UnexpectedResponse, IOError
        debug_info "Beanstalk Error - #{$!}, reconnecting."
        beanstalk_connect
        set_watch @in_tube, reconnect: true
        sleep SNOOZE_TIME and retry
      rescue
        # Checksum errors and MessagePack errors are unrecoverable
        debug_info "Unrecoverable problem with message contents - #{$!}, skipping"
        job.delete rescue nil
        sleep 5
        retry
      end

      begin
        if block_given?
          result = yield( pdu )
        else
          result = pdu
        end
        job.delete rescue nil
        return result
      rescue
        # If the user block raises, release the job back to the queue
        debug_info "Error from user block: #{$!}"
        $@.first(5).each {|frame| debug_info frame}
        job.release rescue nil
        nil
      end

    end
    alias :next :pull # backwards API compatability

    def push pdu, opts={}
      @defaults ||= {originate: true, priority: 32768, ttr: 60, delay: 0}
      opts = @defaults.update opts
      if opts[:originate]
        originate pdu
      else
        update pdu
      end
      unless checksum_ok? pdu
        # What we're worried about is someone inserting a pdu in update mode,
        # which keeps the producer_hash in the tag, but changes the pdu['data']
        # because they didn't know they shouldn't.
        raise(
          ArgumentError,
          "#{self}:#{__method__}: Attempted to insert message with bad checksum"
        )
      end
      pdu['tag'].update( 'last_hop'=>@id )
      packed = MessagePack.pack pdu
      #debug_info "Inserting new pdu, size #{packed.size/1024}KB"
      begin
        backoff = 0.1
        loop do
          break if stats['current-jobs-ready'] <= @queue_limit
          sleep backoff
          if backoff >= MAX_BACKOFF
            backoff = MAX_BACKOFF
          else
            backoff *= 2
          end
        end
        @beanstalk.put packed, opts[:priority], opts[:delay], opts[:ttr]
      rescue Beanstalk::UnexpectedResponse
        debug_info "UnexpectedResponse: #{$!}"
        beanstalk_connect
        set_use @out_tube
        sleep SNOOZE_TIME and retry
        debug_info "Reconnected. Retrying."
      rescue
        debug_info $!
        debug_info "\n" << $@.join("\n")
        raise $!
      end
    end
    alias :insert :push # backwards API compatability

    def finished?
      @finished
    end

    def finish
      @finished = true
    end

    def stats
      begin
        @beanstalk.stats_tube @out_tube
      rescue Beanstalk::UnexpectedResponse
        debug_info "error in stats: #{$!}"
        beanstalk_connect
        set_watch @in_tube, reconnect: true
        sleep SNOOZE_TIME and retry
      end
    end

    def set_watch tube, opts={reconnect: false}
      begin
        if @in_tube == tube
          return unless opts[:reconnect]
        end
        debug_info "Watching #{tube}"
        @in_tube = tube
        @beanstalk.watch tube
      rescue Beanstalk::UnexpectedResponse
        beanstalk_connect
        sleep SNOOZE_TIME and retry
      rescue
        debug_info "in #{__method__}: Error: #{$!}"
      end
    end

    def set_use tube
      begin
        return if @out_tube == tube
        debug_info "Using #{tube}"
        @out_tube = tube
        @beanstalk.use tube
      rescue Beanstalk::UnexpectedResponse
        beanstalk_connect
        sleep SNOOZE_TIME and retry
      rescue
        debug_info "in #{__method__}: Error: #{$!}"
      end
    end

    private

    def originate pdu
      # This is a little non-obvious. The delivery bot sends the unicast messaging
      # response to the 'producer_id' in the tag. If an inserter 'steals' the
      # message by using originate when they didn't actually originate the message
      # then they should make sure they forward the result to the original
      # producer, who might be waiting for it.
      extra = {
        'producer_iteration' => @count += 1,
        'producer_timestamp' => "#{Time.now}",
        'producer_hash'      => Zlib.adler32( [*pdu['data']].join ),
        'producer_id'        => @id
      }
      ( pdu['tag'] ||= {} ).update extra
    end

    def update pdu
      # This is for inserters that didn't originate the message (brokers,
      # delivery bots etc) but we always add the timestamp and CRC to the
      # tag's "chain of custody"
      extra = {
        "#{@id}_timestamp" => "#{Time.now}",
        "#{@id}_iteration" => @count+=1
      }
      ( pdu['tag'] ||= {} ).update extra
    end

    def checksum_ok? pdu
      return true unless pdu.has_key? 'data'
      if pdu['tag']['producer_crc32']
        # Backwards compatability
        "#{"%x" % Zlib.crc32( pdu['data'] ).to_s}" == pdu['tag']['producer_crc32']
      elsif pdu['tag']['producer_hash']
        Zlib.adler32( [*pdu['data']].join ) == pdu['tag']['producer_hash']
      else
        true
      end
    end

    def beanstalk_connect
      begin
        debug_info "Connecting to Beanstalk: #{@servers}"
        @beanstalk = Beanstalk::Pool.new @servers
      rescue
        debug_info "in #{__method__}: Error: #{$!}"
        sleep SNOOZE_TIME and retry
      end
    end

  end
end
