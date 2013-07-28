# I had some problems with Thread interactions with Sys::Proctable (which uses
# WMI) causing faults in the interpreter, with 'handle is invalid' type errors.
# Rewrote using the lower level ToolHelp32Snapshot style, and for FFI practice.
#
# Bear in mind that PROCESSENTRY32 contains much less information than you get
# from WMI, so this approach is not always going to be suitable, and it's
# pretty ugly if you need to use #each_pentry32 directly.
#
# Author: Ben Nagy
# Copyright: Copyright (c) Ben Nagy, 2006-2013.
# License: The MIT License
# (See http://www.opensource.org/licenses/mit-license.php for details.)

require 'ffi'
require_relative 'winerror'

module BM3
  module Win32
    module Toolhelp

      TH32CS_SNAPPROCESS = 0x00000002
      MAX_PATH           = 260
      INVALID_HANDLE     = 0

      extend FFI::Library
      ffi_lib 'kernel32'
      ffi_convention :stdcall

      # Pay no attention to the '32's all over this code, it works fine for 64 bit
      # as well, the naming is just legacy Windows stuff.
      class PROCESSENTRY32 < FFI::Struct
        layout :size, :ulong,
          :usage, :ulong,
          :process_id, :ulong,
          :default_heap_id, :pointer, # unused, but this P_ULONG serves as alignment
          :module_id, :ulong,
          :threads, :ulong,
          :parent_process_id, :ulong,
          :pri_class_base, :long,
          :flags, :ulong,
          :exe_file, [:char, MAX_PATH]
      end

      attach_function(
        :CreateToolhelp32Snapshot,
        [:ulong, :ulong],
        :ulong
      )
      attach_function :CloseHandle, [:ulong], :ulong
      attach_function :Process32First, [:ulong, :pointer], :int
      attach_function :Process32Next, [:ulong, :pointer], :bool

      module_function

      def each_pentry32
        begin
          pentry_ary = []
          snap       = CreateToolhelp32Snapshot TH32CS_SNAPPROCESS, 0
          if snap == INVALID_HANDLE
            raise "#{__method__}: Failed to create snapshot : #{WinError.get_last_error}"
          end
          pentry_32        = PROCESSENTRY32.new
          pentry_32[:size] = PROCESSENTRY32.size
          if Process32First snap, pentry_32
            pentry_ary.push pentry_32
            loop do
              pentry_32        = PROCESSENTRY32.new
              pentry_32[:size] = PROCESSENTRY32.size
              break unless Process32Next( snap, pentry_32 )
              pentry_ary.push pentry_32
            end
          else
            raise "#{__method__}: Failed while iterating: #{WinError.get_last_error}"
          end
        ensure
          CloseHandle( snap ) unless snap.zero?
        end
        if block_given?
          pentry_ary.each {|pe_32| yield pe_32}
        else
          return pentry_ary
        end
      end

      def pids_for_caption( caption )
        matches = []
        each_pentry32 {|pe_32|
          this_caption = pe_32[:exe_file].to_ptr.read_string
          matches.push pe_32[:process_id] if this_caption.upcase == caption.upcase
        }
        matches
      end

    end
  end
end
