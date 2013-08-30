# Abstract out text drawing. Can be mixed into devices that support the
# methods #dc and #rect
#
# Author: Ben Nagy
# Copyright: Copyright (c) Ben Nagy, 2006-2013.
# License: The MIT License
# (See http://www.opensource.org/licenses/mit-license.php for details.)

module BM3
  module Win32
    module GDI
      module Text

        def set_alignment align
          # TODO: add sugar. Right now you need to specify alignment options as INTs
          res = GDI.SetTextAlign self.dc, align
          raise_win32_error if res == GDI::GDI_ERROR
          true
        end

        def draw_text str, opts={wide: true, raw: false}
          if opts[:wide]
            text_out_method    = :ExtTextOutW
            text_extent_method = :GetTextExtentPoint32W
          else
            text_out_method    = :ExtTextOutA
            text_extent_method = :GetTextExtentPoint32A
          end
          out       = ""
          guess     = nil
          sz        = GDI::SIZE.new
          this_line = GDI::RECT.new
          width     = self.rect[:right]
          until str.empty?
            if guess
              out << str.slice!( 0, guess )
            else
              # for the first line, build the string one glyph at a time until the
              # text extent is greater than our rect width
              until sz[:cx] > width || str.empty?
                out << str.slice!( 0, 1 )
                if GDI.send( text_extent_method, self.dc, out, out.size, sz )
                  guess = out.size
                else
                  # OK, GetTextExtentPoint failed for some reason. Try to draw the
                  # whole thing (may well be massively clipped)
                  out = str.clone
                  str.clear
                  break
                end
              end
            end
            # This next bit was designed to ensure that the line really is going to
            # fit horizontally, but it is stripped, for now, for speed. Some lines
            # will get clipped slightly, but it's not really a huge deal for fuzzing
            # purposes.
            #
            # until sz[:cx] < width
            if false
              # put one back
              before = out.size
              str.prepend out.slice!(-1,1)
              break if out.size == before # slice failed to shorten! jruby bug...
              raise_win32_error unless GDI.send text_extent_method, self.dc, out, out.size, sz
            end
            # Write what we have so far, which may be only part of the input string.
            # Wrap to top if we would pass the bottom of the window
            @current_y = 0 if @current_y + sz[:cy] > self.rect[:bottom]
            this_line[:left]   = 0
            this_line[:right]  = width
            this_line[:top]    = @current_y
            this_line[:bottom] = @current_y + sz[:cy]
            GDI.send(
              text_out_method,
              self.dc, # device context
              0, # X start
              @current_y, # Y start
              opts[:raw] ? GDI::ETO_GLYPH_INDEX : GDI::ETO_CLIPPED|GDI::ETO_OPAQUE,
              this_line, # RECT
              out, # str to draw
              out.size, # size
              nil # lpDx
            )
            @current_y += sz[:cy]
            out = ""
          end
          GDI.GdiFlush
        end
        alias :write :draw_text

      end
    end
  end
end
