# Monolithic class to handle windows, in ... uh... Windows. Horribly incomplete
# and quite likely wrong in many areas.
#
# Author: Ben Nagy
# Copyright: Copyright (c) Ben Nagy, 2006-2013.
# License: The MIT License
# (See http://www.opensource.org/licenses/mit-license.php for details.)

require_relative 'gdi/base'

module BM3
  module Win32
    class GDI::Window < GDI::Base

      DEFAULTS={
        width: 1024,
        height: 768,
        title: "FFI Window",
        font_size: 36,
        debug: true
      }

      def initialize opts={}
        @opts         = DEFAULTS.merge opts
        @current_y    = 0
        if @opts[:font_file]
          # Do this before creating the window, in case it doesn't load.
          load_font @opts[:font_file]
        end
        register_class
        create_window
        if @opts[:font_file]
          face = GDI.get_facename_for_file @opts[:font_file]
          set_font face, @opts[:font_size]
        end
        GDI.ShowWindow hwnd, GDI::SW_SHOWNORMAL
      end

      def close
        begin
          restore_font
          restore_cursor
        ensure
          #GDI.GdiFlush
          GDI.ReleaseDC @hwnd, dc
          GDI.DestroyWindow @hwnd
          # Because we created a new class, we MUST unregister it here, otherwise
          # the global atom table fills up with class names after ~16k. Good times.
          GDI.UnregisterClass poi(@atom), @hinst
        end
      end

      # ===
      # Cursor handling
      # ===

      def set_cursor cursor_file
        unless File.file? cursor_file
          raise ArgumentError, "Couldn't find cursor file #{cursor_file}"
        end
        hCursor = GDI.LoadCursorFromFile cursor_file
        raise_win32_error if hCursor.zero?
        @old_cursor = GDI.SetCursor hCursor
        debug_info "Set cursor #{cursor_file}, replacing old handle #{@old_cursor}"
        true
      end

      def restore_cursor
        if @old_cursor && @old_cursor.nonzero?
          # MSDN docs say we musn't destroy shared cursors, like those created by
          # LoadCursorFromFile. I do anyway. Leaks. Hate 'em.
          # SetCursor returns the cursor which was just replaced.
          GDI.DestroyCursor( GDI.SetCursor( @old_cursor ))
          debug_info "Restored #{@old_cursor}"
        else
          debug_info "No old cursor to restore, ignoring restore_cursor"
        end
      end

      def clip_cursor
        # This doesn't seem to move the cursor, but it does mean that our cursor
        # icon will display, wherever the physical cursor is onscreen. GDI! HOW THE
        # F*CK DOES IT WORK??
        @old_clip = GDI::RECT.new
        @clip     = GDI::RECT.new
        get_focus
        GDI.GetClipCursor @old_clip
        GDI.GetWindowRect @hwnd, @clip
        GDI.ClipCursor @clip
      end

      def unclip_cursor
        GDI.ClipCursor @old_clip
      end

      # ===
      # Utility
      # ===

      def get_focus
        # This can only work when the process that created the window is in the
        # foreground. See MSDN for more details. There are some approaches to steal
        # focus more reliably, but they're awful. I'll leave this here though
        # http://betterlogic.com/roger/2010/07/windows-forceforeground-
        # bringwindowtotop-brings-it-to-top-but-without-being-active/
        GDI.SetForegroundWindow @hwnd
      end

      def hwnd
        # Window handle
        return @hwnd if @hwnd && GDI.IsWindow( @hwnd )
        nil
      end

      def dc
        # Device context
        @dc ||= GDI.GetDC hwnd
        raise_win32_error if @dc.zero?
        @dc
      end

      def rect
        # Area owned by this window
        @r ||= GDI::RECT.new # reuse this struct
        raise_win32_error unless GDI.GetClientRect( hwnd, @r )
        @r
      end

      def hinst
        # Instance handle
        @hinst ||= GDI.GetModuleHandle( nil ) # handle to the .exe we're in
        raise_win32_error if @hinst.zero?
        @hinst
      end

      def create_window
        @hwnd ||= GDI.CreateWindowEx(
          GDI::WS_EX_LEFT, # extended style
          poi(@atom), # class name or atom
          @opts[:title], # window title
          GDI::WS_OVERLAPPEDWINDOW | GDI::WS_VISIBLE, # style
          GDI::CW_USEDEFAULT, # X pos
          GDI::CW_USEDEFAULT, # Y pos
          @opts[:width], # width
          @opts[:height], # height
          0, # parent
          0, # menu
          hinst, # instance
          nil  # lparam
        )
        raise_win32_error if @hwnd.zero?
      end

      def register_class

        window_class = GDI::WNDCLASSEX.new
        window_class[:lpfnWndProc]   = method(:window_proc)
        window_class[:hInstance]     = hinst
        window_class[:hbrBackground] = GDI::COLOR_WINDOW
        window_class[:lpszClassName] = make_pstr("#{rand(2**32)}")
        window_class[:hCursor]       = 0

        @atom = GDI.RegisterClassEx( window_class )
        if @atom.zero?
          debug_info "Failed RegisterClassEx"
          raise_win32_error
        end
        debug_info "Registered class."
      end

      def window_proc hwnd, umsg, wparam, lparam
        case umsg
        when GDI::WM_DESTROY
          GDI.PostQuitMessage 0
          return 0
        else
          # This handles all messages we don't explicitly process
          return GDI.DefWindowProc(hwnd, umsg, wparam, lparam)
        end
        0
      end

    end
  end
end
