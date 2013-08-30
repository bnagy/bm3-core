# Trivial base class to DRY up the GDI Window / Printer code
#
# Author: Ben Nagy
# Copyright: Copyright (c) Ben Nagy, 2006-2013.
# License: The MIT License
# (See http://www.opensource.org/licenses/mit-license.php for details.)

require_relative 'ffi_binding'
require_relative 'font'
require_relative 'text'
require_relative 'metafile'
require 'bm3-core/win32'
require 'bm3-core'

module BM3
  module Win32
    module GDI
      class Base

        include BM3::Win32::GDI::Font
        include BM3::Win32::GDI::Text
        include BM3::Win32::GDI::Metafile
        include BM3::Logger

        def poi(a); ::FFI::Pointer.new(a); end

        def make_pstr str
          return nil unless str
          FFI::MemoryPointer.from_string str
        end

        def raise_win32_error
          error = WinError.get_last_error
          debug_info "#{error} from #{caller[1]}"
          raise "[Win32 Exception]  #{WinError.get_last_error}"
        end
      end
    end
  end
end
