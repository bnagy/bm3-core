# Monolithic class to handle printers. Horribly incomplete and quite likely
# wrong in many areas.
#
# Author: Ben Nagy
# Copyright: Copyright (c) Ben Nagy, 2006-2013.
# License: The MIT License
# (See http://www.opensource.org/licenses/mit-license.php for details.)

require_relative 'gdi/base'

module BM3
  module Win32
    module GDI

      # Add extra constants for printers

      # Not going to put ALL the DEVMODE constants in.
      # http://source.winehq.org/source/include/wingdi.h has them, if you need.

      DM_COPY         = 2
      DM_MODIFY       = 8
      DM_PROMPT       = 4
      DM_SPECVERSION  = 0x401
      DM_UPDATE       = 1

      DM_IN_BUFFER      = DM_MODIFY
      DM_IN_PROMPT      = DM_PROMPT
      DM_OUT_BUFFER     = DM_COPY
      DM_OUT_DEFAULT    = DM_UPDATE

      DM_BITSPERPEL          = 0x00040000
      DM_COLLATE             = 0x00008000
      DM_COLOR               = 0x00000800
      DM_COPIES              = 0x00000100
      DM_DEFAULTSOURCE       = 0x00000200
      DM_DISPLAYFLAGS        = 0x00200000
      DM_DISPLAYFREQUENCY    = 0x00400000
      DM_DISPLAYORIENTATION  = 0x00000080
      DM_DITHERTYPE          = 0x04000000
      DM_DUPLEX              = 0x00001000
      DM_FORMNAME            = 0x00010000
      DM_ICMINTENT           = 0x01000000
      DM_ICMMETHOD           = 0x00800000
      DM_LOGPIXELS           = 0x00020000
      DM_MEDIATYPE           = 0x02000000
      DM_NUP                 = 0x00000040
      DM_ORIENTATION         = 0x00000001
      DM_PANNINGHEIGHT       = 0x10000000
      DM_PANNINGWIDTH        = 0x08000000
      DM_PAPERLENGTH         = 0x00000004
      DM_PAPERSIZE           = 0x00000002
      DM_PAPERWIDTH          = 0x00000008
      DM_PELSHEIGHT          = 0x00100000
      DM_PELSWIDTH           = 0x00080000
      DM_POSITION            = 0x00000020
      DM_PRINTQUALITY        = 0x00000400
      DM_SCALE               = 0x00000010
      DM_TTOPTION            = 0x00004000
      DM_YRESOLUTION         = 0x00002000

      # Constants for GetDeviceCaps

      ASPECTX           = 40
      ASPECTXY          = 44
      ASPECTY           = 42
      BITSPIXEL         = 12
      BLTALIGNMENT      = 119
      CAPS1             = 94
      CLIPCAPS          = 36
      COLORMGMTCAPS     = 121
      COLORRES          = 108
      CURVECAPS         = 28
      DESKTOPHORZRES    = 118
      DESKTOPVERTRES    = 117
      DRIVERVERSION     = 0
      HORZRES           = 8
      HORZSIZE          = 4
      LINECAPS          = 30
      LOGPIXELSX        = 88
      LOGPIXELSY        = 90
      NUMBRUSHES        = 16
      NUMCOLORS         = 24
      NUMFONTS          = 22
      NUMMARKERS        = 20
      NUMPENS           = 18
      NUMRESERVED       = 106
      PDEVICESIZE       = 26
      PHYSICALHEIGHT    = 111
      PHYSICALOFFSETX   = 112
      PHYSICALOFFSETY   = 113
      PHYSICALWIDTH     = 110
      PLANES            = 14
      POLYGONALCAPS     = 32
      RASTERCAPS        = 38
      SCALINGFACTORX    = 114
      SCALINGFACTORY    = 115
      SHADEBLENDCAPS    = 120
      SIZEPALETTE       = 104
      TECHNOLOGY        = 2
      TEXTCAPS          = 34
      VERTRES           = 10
      VERTSIZE          = 6
      VREFRESH          = 116

      # Constants for GDI Escapes
      # These are from the WINE wingdi.h here:
      # http://source.winehq.org/source/include/wingdi.h#L275
      # They do not completely match MSDN, here:
      # http://msdn.microsoft.com/en-us/library/windows/desktop/dd162843(v=vs.85).aspx
      # I love my job. :(

      ABORTDOC                = 2
      BANDINFO                = 24
      BEGIN_PATH              = 4096
      CHECKJPEGFORMAT         = 4119
      CHECKPNGFORMAT          = 4120
      CLIP_TO_PATH            = 4097
      CLOSECHANNEL            = 4112
      DEVICEDATA              = 19
      DOWNLOADFACE            = 514
      DOWNLOADHEADER          = 4111
      DRAFTMODE               = 7
      DRAWPATTERNRECT         = 25
      ENABLEDUPLEX            = 28
      ENABLEPAIRKERNING       = 769
      ENABLERELATIVEWIDTHS    = 768
      ENCAPSULATED_POSTSCRIPT = 4116
      END_PATH                = 4098
      ENDDOC                  = 11
      ENUMPAPERBINS           = 31
      ENUMPAPERMETRICS        = 34
      EPSPRINTING             = 33
      EXT_DEVICE_CAPS         = 4099
      EXTTEXTOUT              = 512
      FLUSHOUTPUT             = 6
      GDIPLUS_TS_QUERYVER     = 4122
      GDIPLUS_TS_RECORD       = 4123
      GET_PS_FEATURESETTING   = 4121
      GETCOLORTABLE           = 5
      GETDEVICEUNITS          = 42
      GETEXTENDEDTEXTMETRICS  = 256
      GETEXTENTTABLE          = 257
      GETFACENAME             = 513
      GETPAIRKERNTABLE        = 258
      GETPENWIDTH             = 16
      GETPHYSPAGESIZE         = 12
      GETPRINTINGOFFSET       = 13
      GETSCALINGFACTOR        = 14
      GETSETPAPERBINS         = 29
      GETSETPAPERMETRICS      = 35
      GETSETPRINTORIENT       = 30
      GETSETSCREENPARAMS      = 3072
      GETTECHNOLGY            = 20
      GETTECHNOLOGY           = 20
      GETTRACKKERNTABLE       = 259
      GETVECTORBRUSHSIZE      = 27
      GETVECTORPENSIZE        = 26
      MFCOMMENT               = 15
      MOUSETRAILS             = 39
      NEWFRAME                = 1
      NEXTBAND                = 3
      OPENCHANNEL             = 4110
      PASSTHROUGH             = 19
      POSTSCRIPT_DATA         = 37
      POSTSCRIPT_IDENTIFY     = 4117
      POSTSCRIPT_IGNORE       = 38
      POSTSCRIPT_INJECTION    = 4118
      POSTSCRIPT_PASSTHROUGH  = 4115
      PSIDENT_GDICENTRIC      = 0
      PSIDENT_PSCENTRIC       = 1
      QDI_DIBTOSCREEN         = 4
      QDI_GETDIBITS           = 2
      QDI_SETDIBITS           = 1
      QDI_STRETCHDIB          = 8
      QUERYDIBSUPPORT         = 3073
      QUERYESCSUPPORT         = 8
      RESTORE_CTM             = 4100
      SAVE_CTM                = 4101
      SELECTPAPERSOURCE       = 18
      SET_ARC_DIRECTION       = 4102
      SET_BACKGROUND_COLOR    = 4103
      SET_BOUNDS              = 4109
      SET_CLIP_BOX            = 4108
      SET_MIRROR_MODE         = 4110
      SET_POLY_MODE           = 4104
      SET_SCREEN_ANGLE        = 4105
      SET_SPREAD              = 4106
      SETABORTPROC            = 9
      SETALLJUSTVALUES        = 771
      SETCHARSET              = 772
      SETCOLORTABLE           = 4
      SETCOPYCOUNT            = 17
      SETDIBSCALING           = 32
      SETKERNTRACK            = 770
      SETLINECAP              = 21
      SETLINEJOIN             = 22
      SETMITERLIMIT           = 23
      STARTDOC                = 10
      STRETCHBLT              = 2048
      TRANSFORM_CTM           = 4107

    end

    class GDI::Printer < GDI::Base

      DEFAULTS = {
        font_size: 36,
        debug: true
      }

      attr_reader :dc
      attr_accessor :debug

      def initialize opts={}
        @opts         = DEFAULTS.merge opts
        @current_y    = 0
        if @opts[:font_file]
          # Do this before creating the DC, in case it doesn't load.
          load_font @opts[:font_file]
        end
        lpszDevice = make_pstr( opts[:printer] || default_printer )
        @dc = GDI.CreateDC nil, lpszDevice, nil, nil
        raise "Unable to connect to #{lpszDevice.read_string}" if @dc.zero?
        @printer_name = lpszDevice.read_string
        debug_info "OK, connected to #{@printer_name}"
        if @opts[:font_file]
          face = GDI.get_facename_for_file @opts[:font_file]
          ydpi = GDI.GetDeviceCaps dc, GDI::LOGPIXELSY
          # Screen res for fonts is 72dpi, so scale the font up to try and WYSIWYG.
          set_font face, (@opts[:font_size] * ( ydpi / 72.0 )).round
        end
      end

      def close
        begin
          restore_font
        ensure
          GDI.DeleteDC dc
          debug_info "DC destroyed."
        end
      end

      def set_di_bits img_data, opts
        unless opts[:width] && opts[:height]
          raise ArgumentError, "No source image width / height provided!"
        end

        case opts[:type]
        when :jpg
          bi_type = GDI::BI_JPEG
        when :png
          # WARNING!! - As of Windows 7, PNG does not seem to be actually
          # implemented in the kernel
          bi_type = GDI::BI_PNG
        else
          raise ArgumentError, "Unknown image type #{img_type}"
        end
        unless check_support opts[:type], make_pstr( img_data )
          raise ArgumentError, "#{opts[:type]} unsupported by device!"
        else
          debug_info "#{opts[:type]} is supported by device..."
        end
        opts[:dest_height] ||= opts[:height]
        opts[:dest_width]  ||= opts[:width]

        bmi_header=GDI::BITMAPINFOHEADER.new
        bmi_header[:biSize]        = GDI::BITMAPINFOHEADER.size
        bmi_header[:biWidth]       = opts[:width]
        bmi_header[:biHeight]      = opts[:height] # top down image
        bmi_header[:biPlanes]      = 1
        bmi_header[:biBitCount]    = 0
        bmi_header[:biCompression] = bi_type
        bmi_header[:biSizeImage]   = img_data.bytesize

        retval=GDI.SetDIBitsToDevice(
          dc,
          0, # dest X
          0, # dest Y
          opts[:width], # width
          opts[:height], # height
          0, # src X
          opts[:height], # src Y
          0, # Starting scanline
          opts[:height], # total scanlines
          make_pstr( img_data ),
          bmi_header,
          GDI::DIB_RGB_COLORS
        )
        raise_win32_error if retval==GDI::GDI_ERROR || retval.zero?
        debug_info "#{retval} scan lines copied"
        retval
      end

      def stretch_di_bits img_data, opts={}
        # This is NOT a general purpose implementation of this function, it is for
        # fuzzing purposes only. Basically, all I want to do is be able to force
        # win32k.sys to rasterize PNG / JPEG images.
        # Options:
        #   :width - width of original image
        #   :height - height of original image
        #   :dest_width - width of stretched image
        #   :dest_height - height of stretched image
        #   :type - image type - currently :jpg or :png

        unless opts[:width] && opts[:height]
          raise ArgumentError, "No source image width / height provided!"
        end

        case opts[:type]
        when :jpg
          bi_type = GDI::BI_JPEG
        when :png
          # WARNING!! - As of Windows 7, PNG does not seem to be actually
          # implemented in the kernel
          bi_type = GDI::BI_PNG
        else
          raise ArgumentError, "Unknown image type #{img_type}"
        end
        unless check_support opts[:type], make_pstr( img_data )
          raise ArgumentError, "#{opts[:type]} unsupported by device!"
        else
          debug_info "#{opts[:type]} is supported by device..."
        end
        opts[:dest_height] ||= opts[:height]
        opts[:dest_width] ||= opts[:width]

        bmi_header=GDI::BITMAPINFOHEADER.new
        bmi_header[:biSize]        = GDI::BITMAPINFOHEADER.size
        bmi_header[:biWidth]       = opts[:width]
        bmi_header[:biHeight]      = opts[:height]
        bmi_header[:biPlanes]      = 1
        bmi_header[:biBitCount]    = 0
        bmi_header[:biCompression] = bi_type
        bmi_header[:biSizeImage]   = img_data.bytesize

        debug_info(
          "Original: #{opts[:type]} #{opts[:width]} x #{opts[:height]}" <<
          " - Destination X:#{opts[:dest_width]} Y:#{opts[:dest_height]}"
        )

        retval = GDI.StretchDIBits(
          dc,
          0, # dest X
          0, # dest Y
          opts[:dest_width], # width
          opts[:dest_height], # height
          0, # src X
          0, # src Y
          opts[:width],
          opts[:height],
          make_pstr( img_data ),
          bmi_header,
          GDI::DIB_RGB_COLORS,
          GDI::SRCCOPY
        )
        raise_win32_error if retval == GDI::GDI_ERROR || retval.zero?
        debug_info "#{retval} scan lines copied"
        retval
      end

      def start_doc opts={output: "C:\\bm3\\blah.xps"}
        docinfo               = GDI::DOCINFO.new
        docname               = opts[:docname] || "PRINT"
        docinfo[:lpszDocName] = make_pstr docname
        docinfo[:lpszOutput]  = make_pstr opts[:output]
        GDI.StartDoc dc, docinfo
      end

      def start_page
        GDI.StartPage dc
      end

      def end_page
        GDI.EndPage dc
      end

      def end_doc
        GDI.EndDoc dc
      end

      def rect
        xres       = GDI.GetDeviceCaps dc, GDI::HORZRES
        yres       = GDI.GetDeviceCaps dc, GDI::VERTRES
        r          = GDI::RECT.new
        r[:left]   = 0
        r[:right]  = xres - 1
        r[:top]    = 0
        r[:bottom] = yres - 1
        r
      end

      def get_document_properties
        # http://msdn.microsoft.com/en-us/library/windows/desktop/dd183576(v=vs.85).aspx
        hPrinter = FFI::MemoryPointer.new WinTypes::HANDLE
        if GDI.OpenPrinter make_pstr( @printer_name), hPrinter, nil
          devmode_sz = GDI.DocumentProperties(
            0,    # hWND, but seems to work anyway
            hPrinter.send( "read_array_of_" + WinTypes::HANDLE.to_sym.to_s, 1 ).first, # BARF!
            make_pstr( @printer_name ),
            nil,  # output buffer
            nil,  # input buffer
            0     # mode - 0 to get the full size of the DEVMODE inc special driver options
          )
          devmode = make_pstr "\x00" * devmode_sz
          res = GDI.DocumentProperties(
            0,
            hPrinter.send( "read_array_of_" + WinTypes::HANDLE.to_sym.to_s, 1 ).first, # BARF!
            make_pstr( @printer_name ),
            devmode,
            nil,
            GDI::DM_OUT_BUFFER
          )
          raise_win32_error if res.zero?
          GDI::DEVMODE.new devmode
        else
          raise_win32_error
        end
      end

      def ext_escape escape_code, p_input, p_output=nil
        sz_input  = p_input.size rescue 0
        sz_output = p_output.size rescue 0
        res = GDI.ExtEscape(
          dc,
          escape_code,
          sz_input,
          p_input,
          sz_output,
          p_output
        )
        raise_win32_error if res < 0
        res
      end

      def enumerate_escapes
        (0..5000).each {|escape|
          escape_code = FFI::MemoryPointer.new :ulong
          escape_code.write_ulong escape
          res = GDI.ExtEscape(
            dc,
            GDI::QUERYESCSUPPORT,
            escape_code.size,
            escape_code,
            0,
            nil
          )
          puts "Supports #{escape}" if res > 0
        }
      end

      private

        def default_printer
          buf    = make_pstr( "\x00" * 260 )
          buf_sz = FFI::MemoryPointer.new( :ulong )
          buf_sz.write_ulong buf.size
          if GDI.GetDefaultPrinter buf, buf_sz
            buf.read_string
          else
            raise_win32_error
          end
        end

        def check_support img_type, p_img_data
          escape_code = FFI::MemoryPointer.new :ulong
          case img_type
          when :jpg
            img_escape = GDI::CHECKJPEGFORMAT
          when :png
            img_escape = GDI::CHECKPNGFORMAT
          else
          end
          escape_code.write_ulong img_escape
          # Check if CHECKXXXFORMAT exists
          res = GDI.ExtEscape(
            dc,
            GDI::QUERYESCSUPPORT,
            escape_code.size,
            escape_code,
            0,
            nil
          )
          if res > 0
            status = FFI::MemoryPointer.new :ulong
            res = GDI.ExtEscape(
              dc,
              img_escape,
              p_img_data.size,
              p_img_data,
              status.size,
              status
            )
            return true if status.read_ulong == 1 && res > 0
          end
          false
        end

    end
  end
end
