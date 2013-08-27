#--
# Copyright (c) 2009 - 2012 Muriel Salvan (muriel@x-aeon.com)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module RUtilAnts

  module Platform

    module PlatformInfo

      # Return the ID of the OS
      # Applications may adapt their behavior based on it.
      #
      # Return::
      # * _Integer_: OS ID
      def os
        return OS_WINDOWS
      end

      # Return the list of directories where we look for executables
      #
      # Return::
      # * <em>list<String></em>: List of directories
      def system_exe_paths
        return ENV['PATH'].split(';')
      end

      # Set the list of directories where we look for executables
      #
      # Parameters::
      # * *iNewDirsList* (<em>list<String></em>): List of directories
      def set_system_exe_paths(iNewDirsList)
        ENV['PATH'] = iNewDirsList.join(';')
      end

      # Return the list of file extensions that might be discretely happened to executable files.
      # This is the optional extensions that can be happened when invoked from a terminal.
      #
      # Return::
      # * <em>list<String></em>: List of extensions (including .)
      def discrete_exe_extensions
        rExtList = []

        ENV['PATHEXT'].split(';').each do |iExt|
          rExtList << iExt.downcase
        end

        return rExtList
      end

      # Return the list of directories where we look for libraries
      #
      # Return::
      # * <em>list<String></em>: List of directories
      def system_lib_paths
        return ENV['PATH'].split(';')
      end

      # Set the list of directories where we look for libraries
      #
      # Parameters::
      # * *iNewDirsList* (<em>list<String></em>): List of directories
      def set_system_lib_paths(iNewDirsList)
        ENV['PATH'] = iNewDirsList.join(';')
      end

      # This method sends a message (platform dependent) to the user, without the use of wxruby
      #
      # Parameters::
      # * *iMsg* (_String_): The message to display
      def display_msg(iMsg)
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
      # Parameters::
      # * *iCmd* (_String_): The command to execute
      # * *iInTerminal* (_Boolean_): Do we execute this command in a separate terminal ?
      def exec_cmd_async(iCmd, iInTerminal)
        if (iInTerminal)
          raise "Error while executing \"start cmd /c #{iCmd}\": exit status #{$?.exitstatus}" if (!system("start cmd /c #{iCmd}"))
        else
          IO.popen(iCmd)
        end
      end

      # Execute a given URL to be launched in a browser
      #
      # Parameters::
      # * *iURL* (_String_): The URL to launch
      def os_open_url(iURL)
        # We must put " around the URL after the http:// prefix, as otherwise & symbol will not be recognized
        lMatch = iURL.match(/^([^:]+):\/\/(.*)$/)
        raise "URL \"#{iURL}\" is not valid. Can't invoke it." if (lMatch == nil)
        IO.popen("start #{lMatch[1]}://\"#{lMatch[2]}\"")
      end

      # Open a given file with the default OS application
      #
      # Parameters::
      # * *file_name* (_String_): The file to open
      def os_open_file(file_name)
        IO.popen("start \"\" \"#{file_name}\"")
      end

      # Get file extensions specifics to executable files
      #
      # Return::
      # * <em>list<String></em>: List of extensions (including . character). It can be empty.
      def executables_ext
        rLstExt = [ '.exe', '.com', '.bat' ]

        # Use PATHEXT environment variable if possible
        if (ENV['PATHEXT'] != nil)
          rLstExt.concat(ENV['PATHEXT'].split(';').map { |iExt| iExt.downcase })
          rLstExt.uniq!
        end

        return rLstExt
      end

      # Get prohibited characters from file names
      #
      # Return::
      # * _String_: String of prohibited characters in file names
      def prohibited_file_names_chars
        return '\\/:*?"<>|'
      end

      # Create a shortcut (ln -s on Cygwin/Unix systems, a .lnk file on Windows systems)
      #
      # Parameters::
      # * *iSrc* (_String_): The source file
      # * *iDst* (_String_): The destination file
      def create_shortcut(iSrc, iDst)
        require 'win32/shortcut'
        Win32::Shortcut.new(get_shortcut_file_name(iDst)) do |oShortcut|
          oShortcut.path = File.expand_path(iSrc)
        end
      end

      # Get the name of a real file name, pointed by a shortcut.
      # On Windows systems, it will be the target of the lnk file.
      #
      # Parameters::
      # * *iShortcutName* (_String_): Name of the shortcut (same name used by create_shortcut). Don't use OS specific extensions in this name (no .lnk).
      # Return::
      # * _String_: The real file name pointed by this shortcut
      def get_shortcut_target(iShortcutName)
        require 'win32/shortcut'
        return Win32::Shortcut.open(get_shortcut_file_name(iShortcutName)).path
      end

      # Get the real file name of a shortcut
      #
      # Parameters::
      # * *iDst* (_String_): The destination file that will host the shortcut
      # Return::
      # * _String_: The real shortcut file name
      def get_shortcut_file_name(iDst)
        return "#{iDst}.lnk"
      end

    end

  end

end
