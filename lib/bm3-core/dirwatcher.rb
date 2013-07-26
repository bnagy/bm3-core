#
# Author: Ben Nagy
# Copyright: Copyright (c) Ben Nagy, 2006-2013.
# License: The MIT License
# (See http://www.opensource.org/licenses/mit-license.php for details.)

require 'rb-inotify'
require 'set'
require 'thread'

module BM3
  class Dirwatcher

    def initialize dirname
      @dirname   = File.expand_path dirname
      raise unless File.directory? @dirname
      @notify_q  = Queue.new
      @processed = Set.new
      @notifier  = INotify::Notifier.new
      start_watching
    end

    def start_watching
      @notify_thread = Thread.new do
        @notifier.watch( @dirname, :create ) {|event|
          @notify_q.push event.absolute_name
        }
        @notifier.run
      end
      # Do an initial glob
      @globfiles = []
      Dir.glob( "#{@dirname}/*" ) {|fname|
        @globfiles << fname
      }
    end

    def stop_watching
      @notifier.stop
    end

    def next # blocks
      # clear all globbed files first
      if fname = @globfiles.pop
        @processed << fname
        return fname
      else
        loop do
          fname = @notify_q.pop
          break fname unless @processed.include? fname
        end
      end

    end
  end
end
