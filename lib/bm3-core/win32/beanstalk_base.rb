# DRYing up some common code used by my various windows bots
#
# Author: Ben Nagy
# Copyright: Copyright (c) Ben Nagy, 2006-2013.
# License: The MIT License
# (See http://www.opensource.org/licenses/mit-license.php for details.)

require 'bm3-core'
require 'bm3-core/win32'
require 'zlib'
require 'fileutils'

module BM3
  module Win32
    class BeanstalkBase

      HEARTBEAT_SECS  = 10
      RETRIES         = 10
      CHECKPOINT_FILE = "#{ENV["SystemDrive"]}\\bm3_checkpoint\\checkpoint"

      include BM3
      include BM3::Logger

      class << self
        def sequential_testfiles bool
          @sequential_testfiles = !!(bool) # just a hacky way to "cast" to a Boolean
        end

        def sequential_testfiles?
          @sequential_testfiles
        end

        def bsod_checkpoints bool
          @bsod_checkpoints = !!(bool)
        end

        def bsod_checkpoints?
          @bsod_checkpoints
        end

      end

      class ControlHook < Messaging::Hook

        def process topic, msg
          system msg
        end

      end

      attr_reader :opts, :debug

      def initialize( opts )
        @work_dir    = opts['work_dir']
        @debug       = opts['debug']
        @agent_name  = opts['agent_name'] || 'fuzzbot'
        @opts        = opts
        @config_hsh  = opts.each_with_object({}) {|(k,v),hsh| hsh["#{@agent_name}_#{k}"]=v}
        @messaging   = Messaging.new opts, ControlHook
        @incoming    = PullNode.new opts['input_tube'], opts
        # output_tube is set in the PDU, this is just a default
        @outgoing    = PushNode.new 'results', opts
        # so we can put transient errors back in the queue they came from
        @put_back    = PushNode.new opts['input_tube'], opts
        @outgoing.id = @messaging.id
        @counter=0
        # This is a bit crap, should probably do natively.
        raw       = IO.popen 'ipconfig /all'
        @mac_addr = raw.read.match(/Physical.*: (.*)$/)[1].downcase.split('-').join(':')
        @messaging.heartbeat( HEARTBEAT_SECS ) {
          ["heartbeat", {'id'=>@messaging.id, 'agent'=>"#{@agent_name}", 'mac_addr'=>@mac_addr}]
        }
        # Check if we're recovering from a BSOD
        if self.class.bsod_checkpoints?
          do_bsod_recovery
          # make sure the checkpoint directory exists
          FileUtils.mkdir_p(File.dirname CHECKPOINT_FILE)
        end
      end

      def perform_delivery fname, request
        # Should return [ (Hash) messaging_response, (Hash) beanstalkd_response ]
        #
        # This allows fuzzers to only send beanstalkd responses when there are
        # exceptions, etc.
        #
        # You MUST return a messaging_response, at minimum:
        #     { 'result' => 'meh' }
        #
        # If you like, you can return nil for the beanstalkd_response, or not even
        # return an Array.
        #
        # NB: this is designed to allow you to not send a beanstalkd response in
        # some cases, EVEN THOUGH the PDU lists a tube. For processes where you
        # NEVER want one, set the 'output_tube' key to an empty string or nil in
        # your producer config file, or just don't include that key.
        raise NotImplementedError, "No delivery method defined!"
      end

      def add_crashtag tag, pdu, details
        tag.update(
          'fuzzbot_crash_md5'          => "#{Digest::MD5.hexdigest( [*pdu['data']].join )}",
          'fuzzbot_exception_info_md5' => "#{Digest::MD5.hexdigest( details )}",
          'fuzzbot_crash_uuid'         => "#{BM3::Win32::UUID.create rescue "UUIDFAIL-#{rand(2**32)}"}",
        )
      end

      def agent_cleanup
        # Agents can overload this to add extra agent cleanup logic here - closing
        # agents, freeing resources, blah blah blah
        true
      end

      def background_remove fname
        return true unless fname && File.exists?( fname )
        # No point worrying about leaking Threads, if we can't remove the files our
        # disk will fill up.
        Thread.new {
          loop do
            begin
              FileUtils.rm_rf fname
            rescue
              debug_info "Failed to background remove #{fname} - #{$!}"
            end
            break unless File.exists? fname
            debug_info "Retrying background remove of #{fname}"
            sleep 1
          end
        }
        true
      end

      def blocking_remove fname
        return true unless fname && File.exists?( fname )
        loop do
          begin
            FileUtils.rm_rf fname
          rescue
            debug_info "Failed to blocking remove #{fname} - #{$!}"
          end
          break unless File.exists? fname
          debug_info "Retrying blocking remove..."
          sleep 1
        end
        true
      end

      def send_responses request, delivery_time, zmq_response, beanstalkd_response
        response_tag = request['tag']
        output_tube  = request['output_tube']
        producer     = response_tag['producer_id']
        response_tag.update(
          "#{@agent_name}_delivery_options" => request['delivery_options'],
          "#{@agent_name}_extension"        => request['extension'],
          "#{@agent_name}_command"          => request['command'],
          "#{@agent_name}_delivery_time"    => "#{delivery_time}"
        )
        response_tag.update @config_hsh
        if output_tube and not output_tube.empty?
          if beanstalkd_response
            debug_info "Sending beanstalkd response to tube #{output_tube}"
            response = {
              'tag' => response_tag
            }.merge beanstalkd_response
            @outgoing.set_use( output_tube ) if output_tube
            @outgoing.push response, originate: false
          else
            debug_info "No beanstalkd response to send"
          end
        else
          debug_info "No output tube, skipping beanstalk response..."
        end
        debug_info "Sending 0MQ response (result #{zmq_response['result']})"
        result_msg = {
          'tag' => response_tag
        }.merge zmq_response
        @messaging.send 'results', result_msg
        unless producer == 'NOT_SET'
          @messaging.send producer, result_msg
        end
      end

      def deliver_with_checkpoint
        debug_info "Waiting for next delivery (checkpoints enabled)"
        request = @incoming.pull # this deletes the job
        begin
          debug_info(
            "New delivery, len #{request['data'].size/1024}KB check " <<
            "#{request['tag']['producer_adler32']}"
          )
          begin
            # This will establish a checkpoint, if that class option is set
            delivery_fname = prepare_file request
            mark           = Time.now
            # This might not be immediately obvious - the subclass that provides
            # perform_delivery can directly modify keys and values within the
            # request - for example messing with the tag - and so I'm not providing
            # a more overt way to access the tag here.
            zmq_response, beanstalkd_response = perform_delivery delivery_fname, request
          ensure
            clear_checkpoint
          end
          delivery_time = Time.now - mark
          send_responses request, delivery_time, zmq_response, beanstalkd_response
        rescue
          # something went wrong with this job but the next delivery might work.
          debug_info "Error #{$!} - putting job back onto the queue"
          debug_info( "\n" << $@.first( 5 ).join("\n") )
          @put_back.push request, originate: false
          request.delete( 'data' ) rescue nil
          debug_info request.inspect
        ensure
          background_remove delivery_fname
          agent_cleanup
        end
      end

      def deliver_next
        if self.class.bsod_checkpoints?
          deliver_with_checkpoint
          return
        end
        debug_info "Waiting for next delivery"
        @incoming.pull do |request|
          begin
            debug_info(
              "New delivery, len #{request['data'].size/1024}KB check " <<
              "#{request['tag']['producer_adler32']}"
            )
            delivery_fname = prepare_file request
            # ===
            # Do the actual delivery - subclasses should override perform_delivery
            # ===
            mark = Time.now
            zmq_response, beanstalkd_response = perform_delivery delivery_fname, request
            delivery_time = Time.now - mark
            send_responses request, delivery_time, zmq_response, beanstalkd_response
          ensure
            background_remove delivery_fname
            agent_cleanup
          end
        end
      end

      private

      def clear_checkpoint
        blocking_remove CHECKPOINT_FILE
      end

      def do_bsod_recovery
        # see if there is an uncleared checkpoint or a dump Presently this fails
        # 'open' in that a BSOD is not the only way to get an uncleared
        # checkpoint ( all kinds of reboot races will do it ), so just because
        # you get checkpoints in your bsod triage doesn't mean they're real.
        # Seems better to do it that way than rely on a .dmp file ALWAYS being
        # created
        if File.file? CHECKPOINT_FILE || Dir["#{ENV["SystemDrive"]}/bm3_checkpoint/*.dmp"].any?
          debug_info "Found data in checkpoint directory. Recovering..."
          # Dir[] only works with Ruby style forward slashes :/
          dump_fname = Dir["#{ENV["SystemDrive"]}/bm3_checkpoint/*.dmp"].first
          # There might be some chance a remove could fail which would lead to
          # the wrong dump being sent? However, we don't want to block here,
          # because the vital thing is to send the checkpoint file. I figure
          # worst case you will have the bug and be able to repro.
          if dump_fname
            begin
              debug_info "Dump filename #{dump_fname}"
              dump_contents = File.binread dump_fname
              background_remove dump_fname
            rescue Errno::EACCES
              dump_contents = "No perms to read .dmp files - try running via an Administrator command prompt."
              debug_info dump_contents
            end
          else
            debug_info "No dumpfile found"
          end
          if File.file? CHECKPOINT_FILE
            debug_info "Reading checkpoint"
            checkpoint_contents = File.binread CHECKPOINT_FILE
          else
            debug_info "No checkpoint file??"
            checkpoint_contents = MessagePack.pack({})
          end
          pdu = {
            'dump'       => dump_contents,
            'checkpoint' => checkpoint_contents,
            'uuid'       => "#{BM3::Win32::UUID.create rescue "UUIDFAIL-#{rand(2**32)}"}"
          }
          @outgoing.set_use 'bsod' # FIXME: get from config?
          @outgoing.push pdu
          blocking_remove CHECKPOINT_FILE
        else
          debug_info "No checkpoints, starting normally..."
        end
      end

      def establish_checkpoint request
        if File.file? CHECKPOINT_FILE
          warn "Uncleared checkpoint found. Exploding."
          @messaging.destroy
          exit!
        end
        File.binwrite CHECKPOINT_FILE, MessagePack.pack(request)
      end

      def prepare_file request
        retries = RETRIES
        begin
          if self.class.sequential_testfiles?
            filename = "datum-#{@counter+=1}.#{request['extension']}"
          else
            filename = "datum.#{request['extension']}"
          end
          establish_checkpoint( request ) if self.class.bsod_checkpoints?
          return request['url'] if request['url'] # for HTTP delivery
          path = File.join( File.expand_path(@work_dir), filename )
          File.binwrite path, request['data']
          path
        rescue
          debug_info "Couldn't create test file #{filename} : #{$!}"
          sleep 1 and retry unless ((retries-=1) <= 0)
          debug_info "Can't create file. Giving up."
          exit
        end
      end

    end
  end
end
