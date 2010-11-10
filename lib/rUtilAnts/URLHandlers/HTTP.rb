#--
# Copyright (c) 2009-2010 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module RUtilAnts

  module URLCache

    module URLHandlers

      # Handler of HTTP URLs
      class HTTP

        # Get a list of regexps matching the URL to get to this handler
        #
        # Return:
        # * <em>list<Regexp></em>: The list of regexps matching URLs from this handler
        def self.getMatchingRegexps
          return [
            /^(http|https):\/\/.*$/
          ]
        end

        # Constructor
        #
        # Parameters:
        # * *iURL* (_String_): The URL that this handler will manage
        def initialize(iURL)
          @URL = iURL
          lURLMatch = iURL.match(/^(http|https):\/\/([^\/]*)\/(.*)$/)
          if (lURLMatch == nil)
            lURLMatch = iURL.match(/^(http|https):\/\/(.*)$/)
          end
          if (lURLMatch == nil)
            logBug "URL #{iURL} was identified as an http like, but it appears to be false."
          else
            @URLProtocol, @URLServer, @URLPath = lURLMatch[1..3]
          end
        end

        # Get the server ID
        #
        # Return:
        # * _String_: The server ID
        def getServerID
          return "#{@URLProtocol}://#{@URLServer}"
        end

        # Get the current CRC of the URL
        #
        # Return:
        # * _Integer_: The CRC
        def getCRC
          # We consider HTTP URLs to be definitive: CRCs will never change.
          return 0
        end

        # Get a corresponding file base name.
        # This method has to make sure file extensions are respected, as it can be used for further processing.
        #
        # Return:
        # * _String_: The file name
        def getCorrespondingFileBaseName
          # Check that extension has no characters following the URL (#, ? and ;)
          return getValidFileName(File.basename(@URLPath.gsub(/^([^#\?;]*).*$/,'\1')))
        end

        # Get the content of the URL
        #
        # Parameters:
        # * *iFollowRedirections* (_Boolean_): Do we follow redirections while accessing the content ?
        # Return:
        # * _Integer_: Type of content returned
        # * _Object_: The content, depending on the type previously returned:
        # ** _Exception_ if CONTENT_ERROR: The corresponding error
        # ** _String_ if CONTENT_REDIRECT: The new URL
        # ** _String_ if CONTENT_STRING: The real content
        # ** _String_ if CONTENT_LOCALFILENAME: The name of the local file name storing the content
        # ** _String_ if CONTENT_LOCALFILENAME_TEMPORARY: The name of the temporary local file name storing the content
        def getContent(iFollowRedirections)
          rContentFormat = nil
          rContent = nil

          begin
            require 'net/http'
            Net::HTTP.start(@URLServer) do |iHTTPConnection|
              # Some websites filter out the default user agent (commons.mediawiki.org for example). Set another one.
              lResponse = iHTTPConnection.request_get("/#{@URLPath}", {'User-Agent' => 'RUtilAnts'})
              if ((iFollowRedirections) and
                  (lResponse.is_a?(Net::HTTPRedirection)))
                # We access the file through a new URL
                rContent = lResponse['location']
                lNewURLMatch = rContent.match(/^(ftp|ftps|http|https):\/\/(.*)$/)
                if (lNewURLMatch == nil)
                  if (rContent[0..0] == '/')
                    rContent = "#{@URLProtocol}://#{@URLServer}#{rContent}"
                  else
                    rContent = "#{@URLProtocol}://#{@URLServer}/#{File.dirname(@URLPath)}/#{rContent}"
                  end
                end
                rContentFormat = CONTENT_REDIRECT
              elsif (lResponse.is_a?(Net::HTTPOK))
                # We have the web page
                rContent = lResponse.body
                rContentFormat = CONTENT_STRING
              else
                # An error occurred
                rContent = RuntimeError.new("Access error to #{@URL}: #{lResponse.code}.")
                rContentFormat = CONTENT_ERROR
              end
            end
          rescue Exception
            rContent = $!
            rContentFormat = CONTENT_ERROR
          end

          return rContentFormat, rContent
        end

      end

    end

  end

end