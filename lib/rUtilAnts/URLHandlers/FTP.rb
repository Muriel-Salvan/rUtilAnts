#--
# Copyright (c) 2009 - 2012 Muriel Salvan (muriel@x-aeon.com)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module RUtilAnts

  module URLAccess

    module URLHandlers

      # Handler of FTP URLs
      class FTP

        # Get a list of regexps matching the URL to get to this handler
        #
        # Return::
        # * <em>list<Regexp></em>: The list of regexps matching URLs from this handler
        def self.get_matching_regexps
          return [
            /^(ftp|ftps):\/\/.*$/
          ]
        end

        # Constructor
        #
        # Parameters::
        # * *iURL* (_String_): The URL that this handler will manage
        def initialize(iURL)
          @URL = iURL
          lURLMatch = iURL.match(/^(ftp|ftps):\/\/([^\/]*)\/(.*)$/)
          if (lURLMatch == nil)
            lURLMatch = iURL.match(/^(ftp|ftps):\/\/(.*)$/)
          end
          if (lURLMatch == nil)
            log_bug "URL #{iURL} was identified as an ftp like, but it appears to be false."
          else
            @URLProtocol, @URLServer, @URLPath = lURLMatch[1..3]
          end
        end

        # Get the server ID
        #
        # Return::
        # * _String_: The server ID
        def get_server_id
          return "#{@URLProtocol}://#{@URLServer}"
        end

        # Get the current CRC of the URL
        #
        # Return::
        # * _Integer_: The CRC
        def get_crc
          # We consider FTP URLs to be definitive: CRCs will never change.
          return 0
        end

        # Get a corresponding file base name.
        # This method has to make sure file extensions are respected, as it can be used for further processing.
        #
        # Return::
        # * _String_: The file name
        def get_corresponding_file_base_name
          lBase = File.basename(@URLPath)
          lExt = File.extname(@URLPath)
          lFileName = nil
          if (lExt.empty?)
            lFileName = lBase
          else
            # Check that extension has no characters following the URL (#, ? and ;)
            lBase = lBase[0..lBase.size-lExt.size-1]
            lFileName = "#{lBase}#{lExt.gsub(/^([^#\?;]*).*$/,'\1')}"
          end

          return get_valid_file_name(lFileName)
        end

        # Get the content of the URL
        #
        # Parameters::
        # * *iFollowRedirections* (_Boolean_): Do we follow redirections while accessing the content ?
        # Return::
        # * _Integer_: Type of content returned
        # * _Object_: The content, depending on the type previously returned:
        #   * _Exception_ if CONTENT_ERROR: The corresponding error
        #   * _String_ if CONTENT_REDIRECT: The new URL
        #   * _String_ if CONTENT_STRING: The real content
        #   * _String_ if CONTENT_LOCALFILENAME: The name of the local file name storing the content
        #   * _String_ if CONTENT_LOCALFILENAME_TEMPORARY: The name of the temporary local file name storing the content
        def get_content(iFollowRedirections)
          rContentFormat = nil
          rContent = nil

          begin
            require 'net/ftp'
            lFTPConnection = Net::FTP.new(@URLServer)
            lFTPConnection.login
            lFTPConnection.chdir(File.dirname(@URLPath))
            rContent = get_corresponding_file_base_name
            rContentFormat = CONTENT_LOCALFILENAME_TEMPORARY
            log_debug "URL #{@URL} => Temporary file #{rContent}"
            lFTPConnection.getbinaryfile(File.basename(@URLPath), rContent)
            lFTPConnection.close
          rescue Exception
            rContent = $!
            rContentFormat = CONTENT_ERROR
            log_debug "Error accessing #{@URL}: #{rContent}"
          end

          return rContentFormat, rContent
        end

      end

    end

  end

end