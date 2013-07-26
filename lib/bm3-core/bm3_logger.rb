# Really trivial convenience class, I was just sick of inconsistent logging
# output, but can't be bothered adding an external dependency.
#
# Author: Ben Nagy
# Copyright: Copyright (c) Ben Nagy, 2006-2013.
# License: The MIT License
# (See http://www.opensource.org/licenses/mit-license.php for details.)

module BM3
  module Logger

    def debug_info str
      warn "[#{Time.now.strftime "%H:%M:%S.%L"} - #{@log_as || self.class}] #{str}" if @debug
    end

    def log_as str
      @log_as = str
    end

    def debug_on
      @debug = true
    end

  end
end
