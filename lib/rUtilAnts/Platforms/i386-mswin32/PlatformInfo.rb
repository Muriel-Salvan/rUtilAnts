#--
# Copyright (c) 2009-2010 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module RUtilAnts

  module Platform

    class PlatformInfo

      # Return the ID of the OS
      # Applications may adapt their behavior based on it.
      #
      # Return:
      # * _Integer_: OS ID
      def os
        return OS_WINDOWS
      end

      # Return the list of directories where we look for executables
      #
      # Return:
      # * <em>list<String></em>: List of directories
      def getSystemExePath
        return ENV['PATH'].split(';')
      end

      # Set the list of directories where we look for executables
      #
      # Parameters:
      # * *iNewDirsList* (<em>list<String></em>): List of directories
      def setSystemExePath(iNewDirsList)
        ENV['PATH'] = iNewDirsList.join(';')
      end

      # Return the list of file extensions that might be discretely happened to executable files.
      # This is the optional extensions that can be happened when invoked from a terminal.
      #
      # Return:
      # * <em>list<String></em>: List of extensions (including .)
      def getDiscreteExeExtensions
        rExtList = []

        ENV['PATHEXT'].split(';').each do |iExt|
          rExtList << iExt.downcase
        end

        return rExtList
      end

      # Return the list of directories where we look for libraries
      #
      # Return:
      # * <em>list<String></em>: List of directories
      def getSystemLibsPath
        return ENV['PATH'].split(';')
      end

      # Set the list of directories where we look for libraries
      #
      # Parameters:
      # * *iNewDirsList* (<em>list<String></em>): List of directories
      def setSystemLibsPath(iNewDirsList)
        ENV['PATH'] = iNewDirsList.join(';')
      end

      # This method sends a message (platform dependent) to the user, without the use of wxruby
      #
      # Parameters:
      # * *iMsg* (_String_): The message to display
      def sendMsg(iMsg)
        # iMsg must not be longer than 255 characters
        # \n must be escaped.
        if (iMsg.size > 255)
          system("msg \"#{ENV['USERNAME']}\" /W \"#{iMsg[0..254]}\"")
        else
          system("msg \"#{ENV['USERNAME']}\" /W \"#{iMsg}\"")
        end
      end

      # Execute a Shell command.
      # Do not wait for its termination.
      #
      # Parameters:
      # * *iCmd* (_String_): The command to execute
      # * *iInTerminal* (_Boolean_): Do we execute this command in a separate terminal ?
      # Return:
      # * _Exception_: Error, or nil if success
      def execShellCmdNoWait(iCmd, iInTerminal)
        rException = nil

        if (iInTerminal)
          if (!system("start cmd /c #{iCmd}"))
            rException = RuntimeError.new
          end
        else
          begin
            IO.popen(iCmd)
          rescue Exception
            rException = $!
          end
        end

        return rException
      end

      # Execute a given URL to be launched in a browser
      #
      # Parameters:
      # * *iURL* (_String_): The URL to launch
      # Return:
      # * _String_: Error message, or nil if success
      def launchURL(iURL)
        rError = nil

        # We must put " around the URL after the http:// prefix, as otherwise & symbol will not be recognized
        lMatch = iURL.match(/^(http|https|ftp|ftps):\/\/(.*)$/)
        if (lMatch == nil)
          rError = "URL #{iURL} is not one of http://, https://, ftp:// or ftps://. Can't invoke it."
        else
          IO.popen("start #{lMatch[1]}://\"#{lMatch[2]}\"")
        end

        return rError
      end

      # Get file extensions specifics to executable files
      #
      # Return:
      # * <em>list<String></em>: List of extensions (including . character). It can be empty.
      def getExecutableExtensions
        return [ '.exe', '.com', '.bat' ]
      end

      # Get prohibited characters from file names
      #
      # Return:
      # * _String_: String of prohibited characters in file names
      def getProhibitedFileNamesCharacters
        return '\\/:*?"<>|'
      end

    end

  end

end
