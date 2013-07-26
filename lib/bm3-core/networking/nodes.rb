# Abstraction for Actor pattern. Essentially, you can create various 'nodes' in
# your code that let you push or pull to 'tubes'. Those tubes are worked on my
# one or more other Actors.
#
# For BM3 the PDUs are Hashes that are serialized with MessagePack, but that's
# not coupled to this stuff.
#
# This is the higher level API, check base_node.rb for the current
# implementation, based on beanstalkd.
#
# Author: Ben Nagy
# Copyright: Copyright (c) Ben Nagy, 2006-2013.
# License: The MIT License
# (See http://www.opensource.org/licenses/mit-license.php for details.)

require_relative 'base_node'

module BM3

  class PushNode < BaseNode

    def initialize out_tube, opts={}
      super nil, out_tube, opts
      set_use out_tube
    end

    def map collection
      # push all elements to the queue, get results via 0mq unicast
      raise NotImplementedError
    end

    def pull &blk
      # Push nodes have no upstream
      raise NotImplementedError
    end

  end

  class PullNode < BaseNode

    def initialize in_tube, opts={}
      super in_tube, nil, opts
      set_watch in_tube
    end

    def push pdu
      # Pull nodes have no downstream
      raise NotImplementedError
    end

  end

  class WorkNode < BaseNode

    def initialize in_tube, out_tube, opts={}
      super
      set_watch in_tube
      set_use out_tube
    end

    # Your block should look like:
    #
    #    my_worker.process {|pdu|
    #     # do processing
    #     onward_pdu # anything truthy is pushed automatically
    #    }
    #
    # Alternatively, you can return anything falsey from the block, and nothing
    # will be pushed, but the job will still be treated as correctly processed,
    # and deleted from the input queue. Finally, you can raise in your block, and
    # the job will be treated as incorrectly processed, and released back to the
    # queue
    def process &blk
      result=pull( &blk )
      if result
        push result, originate: false
      end
    end

  end
end
