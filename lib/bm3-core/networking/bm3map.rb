# Convenience class to perform a map style operation across BM3 workers.
#
# Author: Ben Nagy
# Copyright: Copyright (c) Ben Nagy, 2006-2013.
# License: The MIT License
# (See http://www.opensource.org/licenses/mit-license.php for details.)

module BM3
  class BM3Map

    def initialize inserter, messaging
      @inserter  = inserter
      @messaging = messaging
    end

    def parallel_map pdus, &blk
      # get all results. If we miss any results this will hang.
      results = []
      results_thread = Thread.new do
        pdus.size.times do # one result per pdu
          _, pdu = @messaging.recv_hook.messages.pop
          results << blk.yield( pdu )
        end
      end
      pdus.each {|pdu|
        @inserter.insert pdu
      }
      results_thread.join
      results
    end

  end
end
