module RUtilAnts

  module Logging

    # Constants used for GUI dialogs selection
    GUI_WX = 0

    # The logger interface, can be used to decorate any class willing to have de
    module LoggerInterface

      # Initializer of the logger variables
      #
      # Parameters::
      # * *iOptions* (<em>map<Symbol,Object></em>): Options [optional = {}]
      #   * *:lib_root_dir* (_String_): The library root directory that will not appear in the logged stack messages [optional = nil]
      #   * *:bug_tracker_url* (_String_): The application's bug tracker URL, used to report bugs [optional = nil]
      #   * *:mute_stdout* (_Boolean_): Do we silent normal output (nothing sent to $stdout) ? [optional = false]
      #   * *:mute_stderr* (_Boolean_): Do we silent error output (nothing sent to $stderr) ? [optional = false]
      #   * *:no_dialogs* (_Boolean_): Do we forbid dialogs usage ? [optional = false]
      #   * *:debug_mode* (_Boolean_): Do we activate debug mode ? [optional = false]
      #   * *:log_file* (_String_): Specify a log file [optional = nil]
      #   * *:errors_stack* (<em>list<String></em>): Specify an errors stack [optional = nil]
      #   * *:messages_stack* (<em>list<String></em>): Specify a messages stack [optional = nil]
      #   * *:gui_for_dialogs* (_Integer_): Specify a GUI constant for dialogs [optional = nil]
      def init_logger(iOptions = {})
        @LibRootDir = iOptions[:lib_root_dir]
        @BugTrackerURL = iOptions[:bug_tracker_url]
        @DebugMode = (iOptions[:debug_mode] == nil) ? false : iOptions[:debug_mode]
        @LogFile = iOptions[:log_file]
        @ErrorsStack = iOptions[:errors_stack]
        @MessagesStack = iOptions[:messages_stack]
        @DialogsGUI = iOptions[:gui_for_dialogs]
        @ScreenOutput = (iOptions[:mute_stdout] == nil) ? true : (!iOptions[:mute_stdout])
        @ScreenOutputErr = (iOptions[:mute_stderr] == nil) ? true : (!iOptions[:mute_stderr])
        @NoDialogs = (iOptions[:no_dialogs] == nil) ? false : iOptions[:no_dialogs]
        if (!@ScreenOutput)
          # Test if we can write to stdout
          begin
            $stdout << "Launch Logging - stdout\n"
          rescue Exception
            # Redirect to a file if possible
            begin
              lFile = File.open('./stdout', 'w')
              $stdout.reopen(lFile)
              $stdout << "Launch Logging - stdout\n"
            rescue Exception
              # Disable
              @ScreenOutput = false
            end
          end
        end
        if (!@ScreenOutputErr)
          # Test if we can write to stderr
          begin
            $stderr << "Launch Logging - stderr\n"
          rescue Exception
            # Redirect to a file if possible
            begin
              lFile = File.open('./stderr', 'w')
              $stderr.reopen(lFile)
              $stderr << "Launch Logging - stderr\n"
            rescue Exception
              # Disable
              @ScreenOutputErr = false
            end
          end
        end
      end

      # Mute or unmute standard output
      #
      # Parameters::
      # * *iMute* (_Boolean_): Do we mute standard output ? [optional = true]
      def mute_stdout(iMute = true)
        @ScreenOutput = (!iMute)
      end

      # Mute or unmute error output
      #
      # Parameters::
      # * *iMute* (_Boolean_): Do we mute error output ? [optional = true]
      def mute_stderr(iMute = true)
        @ScreenOutputErr = (!iMute)
      end

      # Set the log file to use (can be nil to stop logging into a file)
      #
      # Parameters::
      # * *iFileName* (_String_): Log file name (can be nil)
      def set_log_file(iFileName)
        @LogFile = iFileName
      end

      # Get the log file used (can be nil)
      #
      # Return::
      # * _String_: Log file name (can be nil)
      def get_log_file
        return @LogFile
      end

      # Get the library root dir
      #
      # Return::
      # * _String_: The library root dir, as defined when initialized
      def get_lib_root_dir
        return @LibRootDir
      end

      # Get the bug tracker URL
      #
      # Return::
      # * _String_: The bug tracker URL, as defined when initialized
      def get_bug_tracker_url
        return @BugTrackerURL
      end

      # Indicate which GUI to be used to display dialogs.
      #
      # Parameters::
      # * *iGUIToUse* (_Integer_): The GUI constant, or nil if no GUI is provided
      def set_gui_for_dialogs(iGUIToUse)
        @DialogsGUI = iGUIToUse
      end

      # Set the debug mode
      #
      # Parameters::
      # * *iDebugMode* (_Boolean_): Are we in debug mode ?
      def activate_log_debug(iDebugMode)
        if (@DebugMode != iDebugMode)
          @DebugMode = iDebugMode
          if (iDebugMode)
            log_info 'Activated log debug'
          else
            log_info 'Deactivated log debug'
          end
        end
      end

      # Is debug mode activated ?
      #
      # Return::
      # * _Boolean_: Are we in debug mode ?
      def debug_activated?
        return @DebugMode
      end

      # Set the stack of the errors to fill.
      # If set to nil, errors will be displayed as they appear.
      # If set to a stack, errors will silently be added to the list.
      #
      # Parameters::
      # * *iErrorsStack* (<em>list<String></em>): The stack of errors, or nil to unset it
      def set_log_errors_stack(iErrorsStack)
        @ErrorsStack = iErrorsStack
      end

      # Set the stack of the messages to fill.
      # If set to nil, messages will be displayed as they appear.
      # If set to a stack, messages will silently be added to the list.
      #
      # Parameters::
      # * *iMessagesStack* (<em>list<String></em>): The stack of messages, or nil to unset it
      def set_log_messages_stack(iMessagesStack)
        @MessagesStack = iMessagesStack
      end

      # Log an exception
      # This is called when there is a bug due to an exception in the program. It has been set in many places to detect bugs.
      #
      # Parameters::
      # * *iException* (_Exception_): Exception
      # * *iMsg* (_String_): Message to log
      def log_exc(iException, iMsg)
        log_bug("#{iMsg}
Exception: #{iException}
Exception stack:
#{get_simple_caller(iException.backtrace, caller).join("\n")}
...")
      end

      # Log a bug
      # This is called when there is a bug in the program. It has been set in many places to detect bugs.
      #
      # Parameters::
      # * *iMsg* (_String_): Message to log
      def log_bug(iMsg)
        lCompleteMsg = "Bug: #{iMsg}
Stack:
#{get_simple_caller(caller[0..-2]).join("\n")}"
        # Log into stderr
        if (@ScreenOutputErr)
          $stderr << "!!! BUG !!! #{lCompleteMsg}\n"
        end
        if (@LogFile != nil)
          log_file(lCompleteMsg)
        end
        # Display Bug dialog
        if (show_modal_wx_available?)
          # We require the file here, as we hope it will not be required often
          require 'rUtilAnts/GUI/BugReportDialog'
          showModal(GUI::BugReportDialog, nil, lCompleteMsg, @BugTrackerURL) do |iModalResult, iDialog|
            # Nothing to do
          end
        else
          # Use normal platform dependent message, if the platform has been initialized (otherwise, stick to $stderr)
          if ((defined?(display_msg) != nil) and
              (!@NoDialogs))
            display_msg("A bug has just occurred.
Normally you should never see this message, but this application is not bug-less.
We are sorry for the inconvenience caused.
If you want to help improving this application, please inform us of this bug:
take the time to open a ticket at the bugs tracker.
We will always try our best to correct bugs.
Thanks.

Details:
#{lCompleteMsg}
")
          end
        end
      end

      # Log an error.
      # Those errors can be normal, as they mainly depend on external factors (lost connection, invalid user file...)
      #
      # Parameters::
      # * *iMsg* (_String_): Message to log
      def log_err(iMsg)
        lMsg = "!!! ERR !!! #{iMsg}"
        # Log into stderr
        if (@ScreenOutputErr)
          $stderr << "#{lMsg}\n"
        end
        if (@LogFile != nil)
          log_file(lMsg)
        end
        # Display dialog only if we are not redirecting messages to a stack
        if (@ErrorsStack == nil)
          if (show_modal_wx_available?)
            showModal(Wx::MessageDialog, nil,
              iMsg,
              :caption => 'Error',
              :style => Wx::OK|Wx::ICON_ERROR
            ) do |iModalResult, iDialog|
              # Nothing to do
            end
          elsif ((defined?(display_msg) != nil) and
                 (!@NoDialogs))
            # Use normal platform dependent message, if the platform has been initialized (otherwise, stick to $stderr)
            display_msg(iMsg)
          end
        else
          @ErrorsStack << iMsg
        end
      end

      # Log a normal message to the user
      # This is used to display a simple message to the user
      #
      # Parameters::
      # * *iMsg* (_String_): Message to log
      def log_msg(iMsg)
        # Log into stderr
        if (@ScreenOutput)
          $stdout << "#{iMsg}\n"
        end
        if (@LogFile != nil)
          log_file(iMsg)
        end
        # Display dialog only if we are not redirecting messages to a stack
        if (@MessagesStack == nil)
          # Display dialog only if showModal exists and that we are currently running the application
          if (show_modal_wx_available?)
            showModal(Wx::MessageDialog, nil,
              iMsg,
              :caption => 'Notification',
              :style => Wx::OK|Wx::ICON_INFORMATION
            ) do |iModalResult, iDialog|
              # Nothing to do
            end
          elsif ((defined?(display_msg) != nil) and
                 (!@NoDialogs))
            # Use normal platform dependent message, if the platform has been initialized (otherwise, stick to $stderr)
            display_msg(iMsg)
          end
        else
          @MessagesStack << iMsg
        end
      end

      # Log an info.
      # This is just common journal.
      #
      # Parameters::
      # * *iMsg* (_String_): Message to log
      def log_info(iMsg)
        # Log into stdout
        if (@ScreenOutput)
          $stdout << "#{iMsg}\n"
        end
        if (@LogFile != nil)
          log_file(iMsg)
        end
      end

      # Log a warning.
      # Warnings are not errors but still should be highlighted.
      #
      # Parameters::
      # * *iMsg* (_String_): Message to log
      def log_warn(iMsg)
        # Log into stdout
        lMsg = "!!! WARNING !!! - #{iMsg}"
        if (@ScreenOutput)
          $stdout << "#{lMsg}\n"
        end
        if (@LogFile != nil)
          log_file(lMsg)
        end
      end

      # Log a debugging info.
      # This is used when debug is activated
      #
      # Parameters::
      # * *iMsg* (_String_): Message to log
      def log_debug(iMsg)
        # Log into stdout
        if (@DebugMode)
          if (@ScreenOutput)
            $stdout << "#{iMsg}\n"
          end
          if (@LogFile != nil)
            log_file(iMsg)
          end
        end
      end

      private

      # Check if Wx dialogs environment is set up
      #
      # Return::
      # * _Boolean_: Can we use showModal ?
      def show_modal_wx_available?
        return (
          (defined?(showModal) != nil) and
          (@DialogsGUI == GUI_WX)
        )
      end

      # Log a message in the log file
      #
      # Parameters::
      # * *iMsg* (_String_): The message to log
      def log_file(iMsg)
        File.open(@LogFile, 'a+') do |oFile|
          oFile << "#{Time.now.gmtime.strftime('%Y/%m/%d %H:%M:%S')} - #{iMsg}\n"
        end
      end

      # Get a stack trace in a simple format:
      # Remove @LibRootDir paths from it.
      #
      # Parameters::
      # * *iCaller* (<em>list<String></em>): The caller, or nil if no caller
      # * *iReferenceCaller* (<em>list<String></em>): The reference caller: we will not display lines from iCaller that also belong to iReferenceCaller [optional = nil]
      # Return::
      # * <em>list<String></em>): The simple stack
      def get_simple_caller(iCaller, iReferenceCaller = nil)
        rSimpleCaller = []

        if (iCaller != nil)
          lCaller = nil
          # If there is a reference caller, remove the lines from lCaller that are also in iReferenceCaller
          if (iReferenceCaller == nil)
            lCaller = iCaller
          else
            lIdxCaller = iCaller.size - 1
            lIdxRef = iReferenceCaller.size - 1
            while ((lIdxCaller >= 0) and
                   (lIdxRef >= 0) and
                   (iCaller[lIdxCaller] == iReferenceCaller[lIdxRef]))
              lIdxCaller -= 1
              lIdxRef -= 1
            end
            # Here we have either one of the indexes that is -1, or the indexes point to different lines between the caller and its reference.
            lCaller = iCaller[0..lIdxCaller+1]
          end
          if (@LibRootDir == nil)
            rSimpleCaller = lCaller
          else
            # Remove @LibRootDir from each entry
            lCaller.each do |iCallerLine|
              lMatch = iCallerLine.match(/^(.*):([[:digit:]]*):in (.*)$/)
              if (lMatch == nil)
                # Did not get which format. Just add it blindly.
                rSimpleCaller << iCallerLine
              else
                rSimpleCaller << "#{File.expand_path(lMatch[1]).gsub(@LibRootDir, '')}:#{lMatch[2]}:in #{lMatch[3]}"
              end
            end
          end
        end

        return rSimpleCaller
      end

    end

    # A stand-alone logger
    class Logger

      include RUtilAnts::Logging::LoggerInterface

      # Constructor
      #
      # Parameters::
      # * *iOptions* (<em>map<Symbol,Object></em>): Options (see LoggerInterface for details) [optional = {}]
      def initialize(iOptions = {})
        init_logger(iOptions)
      end

    end

    # Set Object as a logger.
    #
    # Parameters::
    # * *iOptions* (<em>map<Symbol,Object></em>): Options (see RUtilAnts::Logging::Logger::initialize documentation for options) [optional = {}]
    def self.install_logger_on_object(iOptions = {})
      require 'rUtilAnts/SingletonProxy'
      RUtilAnts::make_singleton_proxy(RUtilAnts::Logging::LoggerInterface, Object)
      init_logger(iOptions)
    end

  end

end
