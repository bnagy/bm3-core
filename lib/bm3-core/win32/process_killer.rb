# A Module to store code I frequently use for killing stuff, either by pid or
# by caption.
#
# Author: Ben Nagy
# Copyright: Copyright (c) Ben Nagy, 2006-2013.
# License: The MIT License
# (See http://www.opensource.org/licenses/mit-license.php for details.)

require_relative 'toolhelp'
require 'ffi'

module BM3
  module Win32
    module Window

      WM_CLOSE = 0x0010

      extend FFI::Library
      ffi_lib 'user32'
      ffi_convention :stdcall

      callback :enum_callback, [:ulong, :ulong], :bool
      attach_function :EnumDesktopWindows, [:pointer, :enum_callback, :ulong], :bool
      attach_function :PostMessageA, [:ulong, :int, :ulong, :ulong], :bool
      attach_function :GetWindowThreadProcessId, [:ulong, :pointer], :ulong

      module_function

      def kill_window pid
        @send_close ||= Proc.new {|hProcess, target_pid|
          pid = FFI::MemoryPointer.new :ulong
          GetWindowThreadProcessId hProcess, pid
          if pid.read_ulong == target_pid
            PostMessageA hProcess, WM_CLOSE, 0, 0
          end
          true # keep enumerating
        }
        EnumDesktopWindows( nil, @send_close, pid )
      end

    end

    module ProcessKiller

      extend FFI::Library
      ffi_lib 'kernel32'
      ffi_convention :stdcall

      PROCESS_TERMINATE = 0x0001
      SYNCHRONIZE       = 0x00100000
      WAIT_OBJECT_0     = 0x000000
      INFINITE          = 0xFFFFFFFF
      WAIT_FAILED       = 0xFFFFFFFF

      PROCESS_CREATE_THREAD     = 0x0002
      PROCESS_QUERY_INFORMATION = 0x0400
      PROCESS_VM_OPERATION      = 0x0008
      PROCESS_VM_WRITE          = 0x0020
      PROCESS_VM_READ           = 0x0010

      # Not using PROCESS_ALL_ACCESS because it's bigger on Win7 and later,
      # which can cause errors.
      CREATE_THREAD_RIGHTS=
        PROCESS_CREATE_THREAD|
      PROCESS_QUERY_INFORMATION|
      PROCESS_VM_OPERATION|
      PROCESS_VM_WRITE|
      PROCESS_VM_READ

      RETRY_COUNT = 5

      # kernel32
      attach_function :OpenProcess, [:ulong, :int, :ulong], :ulong
      attach_function :TerminateProcess, [:ulong, :uint], :ulong
      attach_function :WaitForSingleObject, [:ulong, :ulong], :ulong
      attach_function :CloseHandle, [:ulong], :ulong
      attach_function(
        :CreateRemoteThread,
        [:ulong, :ulong, :ulong,:ulong, :ulong, :ulong, :pointer],
        :ulong
      )

      module_function

      def pids caption
        Toolhelp.pids_for_caption caption
      end

      # Attempt to kill pids by sending a WM_CLOSE. Might not work on console
      # apps, and won't work on apps that are hung on dialog boxes, Dr Watson
      # etc. Least invasive, though.
      def wm_close pid_ary, opts={}
        if opts[:timeout]
          timeout = opts[:timeout] * 1000 # ms
        else
          timeout = INFINITE # DANGEROUS!
        end
        pid_ary.map {|pid|
          begin
            hProcess = OpenProcess SYNCHRONIZE|PROCESS_TERMINATE, 0, pid
            next nil if hProcess.zero? # invalid handle
            Window.kill_window pid
            # Not entirely sure if this works at all, or only sometimes....
            result = WaitForSingleObject hProcess, timeout
            next nil if result == WAIT_FAILED
            result == WAIT_OBJECT_0 ? pid : nil
          ensure
            unless hProcess.zero?
              CloseHandle hProcess
            end
          end
        }
      end

      # Attempt to kill pids by CreateRemoteThread( ExitProcess ). Some processes
      # may AV when you do this. I love Windows. o_0
      def create_exit_thread pid_ary, opts={}
        if opts[:timeout]
          timeout = opts[:timeout] * 1000 # ms
        else
          timeout = INFINITE # DANGEROUS, can hang.
        end
        @exit_process_address ||= ffi_lib('kernel32').first.find_function('ExitProcess').address
        pid_ary.map {|pid|
          begin
            hProcess = OpenProcess CREATE_THREAD_RIGHTS, 0, pid
            next if hProcess.zero? # invalid handle
            tid = FFI::MemoryPointer.new :ulong
            hThread = CreateRemoteThread(
              hProcess,
              0,
              0,
              @exit_process_address,
              0,
              0,
              tid
            )
            next nil if hThread.zero?
            result = WaitForSingleObject hThread, timeout
            next nil if result == WAIT_FAILED
            result == WAIT_OBJECT_0 ? pid : nil
          ensure
            CloseHandle hProcess unless hProcess.zero?
            CloseHandle hThread unless hThread.zero?
          end
        }
      end

      # Terminate pids with TerminateProcess, kernel32's nuclear option.
      def terminate pid_ary, opts={}
        if opts[:timeout]
          timeout = opts[:timeout] * 1000 # ms
        else
          timeout = INFINITE
        end
        pid_ary.map {|pid|
          begin
            hProcess = OpenProcess PROCESS_TERMINATE|SYNCHRONIZE, 0, pid
            next nil if hProcess.zero?
            retval = TerminateProcess hProcess, 1
            next nil if retval.zero?
            result = WaitForSingleObject hProcess, timeout
            next nil if result == WAIT_FAILED
            result == WAIT_OBJECT_0 ? pid : nil
          ensure
            CloseHandle hProcess unless hProcess.zero?
          end
        }
      end

      def slay caption, timeout=1
        return false if ( pids=pids(caption) ).empty? # Nothing to kill
        killed = terminate pids, timeout: timeout
        return true if killed.all?
        # eg chrome.exe - you kill the head process, the children (with the
        # same caption) die as well, so the call to kill them will return nil,
        # but the method worked overall.
        return true if pids(caption).empty?
        raise "#{__method__} Failed. Immortal processes. Run!"
      end

      def nicely_kill caption, opts
        timeout = opts[:timeout] || 1
        return false if ( pids=pids( caption ) ).empty? # Nothing to kill
        if opts[:try_wmclose]
          # Extremely polite and clean, may fail if the app doesn't have a window
          # yet (or at all).
          killed = wm_close pids, timeout: timeout
          mark = Time.now
          loop do
            # WaitForSingleObject doesn't always actually wait :(
            return true if killed.all?
            return true if pids(caption).empty?
            break if Time.now - mark > opts[:timeout]
          end
        end
        # OK, slightly rapey, but still gentle as these things go.
        killed = create_exit_thread( pids, timeout: timeout )
        mark   = Time.now
        loop do
          return true if killed.all?
          return true if pids(caption).empty?
          break if Time.now - mark > opts[:timeout]
        end
        raise "#{__method__} Couldn't kill #{caption} nicely, try sterner measures"
      end

    end
  end
end
