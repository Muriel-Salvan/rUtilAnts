#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

# This file declares modules that might be shared across several projects.

module RUtilAnts

  module Logging

    # The logger class singleton
    class Logger

      # Constants used for GUI dialogs selection
      GUI_WX = 0

      # Constructor
      #
      # Parameters:
      # * *iLibRootDir* (_String_): The library root directory that will not appear in the logged stack messages
      # * *iBugTrackerURL* (_String_): The application's bug tracker URL, used to report bugs
      # * *iSilentSTDOut* (_Boolean_): Do we silent normal output (nothing sent to $stdout) ? [optional = false]
      # * *iSilentSTDErr* (_Boolean_): Do we silent error output (nothing sent to $stderr) ? [optional = false]
      def initialize(iLibRootDir, iBugTrackerURL, iSilentSTDOut = false, iSilentSTDErr = false)
        @LibRootDir, @BugTrackerURL = iLibRootDir, iBugTrackerURL
        @DebugMode = false
        @LogFile = nil
        @ErrorsStack = nil
        @MessagesStack = nil
        @DialogsGUI = nil
        @ScreenOutput = (!iSilentSTDOut)
        @ScreenOutputErr = (!iSilentSTDErr)
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

      # Set the log file to use (can be nil to stop logging into a file)
      #
      # Parameters:
      # * *iFileName* (_String_): Log file name (can be nil)
      def setLogFile(iFileName)
        @LogFile = iFileName
      end

      # Get the log file used (can be nil)
      #
      # Return:
      # * _String_: Log file name (can be nil)
      def getLogFile
        return @LogFile
      end

      # Indicate which GUI to be used to display dialogs.
      #
      # Parameters:
      # * *iGUIToUse* (_Integer_): The GUI constant, or nil if no GUI is provided
      def setGUIForDialogs(iGUIToUse)
        @DialogsGUI = iGUIToUse
      end

      # Set the debug mode
      #
      # Parameters:
      # * *iDebugMode* (_Boolean_): Are we in debug mode ?
      def activateLogDebug(iDebugMode)
        @DebugMode = iDebugMode
        if (iDebugMode)
          logInfo 'Activated log debug'
        else
          logInfo 'Deactivated log debug'
        end
      end

      # Set the stack of the errors to fill.
      # If set to nil, errors will be displayed as they appear.
      # If set to a stack, errors will silently be added to the list.
      #
      # Parameters:
      # * *iErrorsStack* (<em>list<String></em>): The stack of errors, or nil to unset it
      def setLogErrorsStack(iErrorsStack)
        @ErrorsStack = iErrorsStack
      end

      # Set the stack of the messages to fill.
      # If set to nil, messages will be displayed as they appear.
      # If set to a stack, messages will silently be added to the list.
      #
      # Parameters:
      # * *iMessagesStack* (<em>list<String></em>): The stack of messages, or nil to unset it
      def setLogMessagesStack(iMessagesStack)
        @MessagesStack = iMessagesStack
      end

      # Log an exception
      # This is called when there is a bug due to an exception in the program. It has been set in many places to detect bugs.
      #
      # Parameters:
      # * *iException* (_Exception_): Exception
      # * *iMsg* (_String_): Message to log
      def logExc(iException, iMsg)
        logBug("#{iMsg}
Exception: #{iException}
Exception stack:
#{getSimpleCaller(iException.backtrace, caller).join("\n")}
...")
      end

      # Log a bug
      # This is called when there is a bug in the program. It has been set in many places to detect bugs.
      #
      # Parameters:
      # * *iMsg* (_String_): Message to log
      def logBug(iMsg)
        lCompleteMsg = "Bug: #{iMsg}
Stack:
#{getSimpleCaller(caller[0..-2]).join("\n")}"
        # Log into stderr
        if (@ScreenOutputErr)
          $stderr << "!!! BUG !!! #{lCompleteMsg}\n"
        end
        if (@LogFile != nil)
          logFile(lCompleteMsg)
        end
        # Display Bug dialog
        if (showModalWxAvailable?)
          # We require the file here, as we hope it will not be required often
          require 'RUtilAnts/GUI/BugReportDialog'
          showModal(GUI::BugReportDialog, nil, lCompleteMsg, @BugTrackerURL) do |iModalResult, iDialog|
            # Nothing to do
          end
        else
          # Use normal platform dependent message, if the platform has been initialized (otherwise, stick to $stderr)
          if (defined?($rUtilAnts_Platform_Info) != nil)
            $rUtilAnts_Platform_Info.sendMsg("A bug has just occurred.
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
      # Parameters:
      # * *iMsg* (_String_): Message to log
      def logErr(iMsg)
        lMsg = "!!! ERR !!! #{iMsg}"
        # Log into stderr
        if (@ScreenOutputErr)
          $stderr << "#{lMsg}\n"
        end
        if (@LogFile != nil)
          logFile(lMsg)
        end
        # Display dialog only if we are not redirecting messages to a stack
        if (@ErrorsStack == nil)
          if (showModalWxAvailable?)
            showModal(Wx::MessageDialog, nil,
              iMsg,
              :caption => 'Error',
              :style => Wx::OK|Wx::ICON_ERROR
            ) do |iModalResult, iDialog|
              # Nothing to do
            end
          elsif (defined?($rUtilAnts_Platform_Info) != nil)
            # Use normal platform dependent message, if the platform has been initialized (otherwise, stick to $stderr)
            $rUtilAnts_Platform_Info.sendMsg(iMsg)
          end
        else
          @ErrorsStack << iMsg
        end
      end

      # Log a normal message to the user
      # This is used to display a simple message to the user
      #
      # Parameters:
      # * *iMsg* (_String_): Message to log
      def logMsg(iMsg)
        # Log into stderr
        if (@ScreenOutput)
          $stdout << "#{iMsg}\n"
        end
        if (@LogFile != nil)
          logFile(iMsg)
        end
        # Display dialog only if we are not redirecting messages to a stack
        if (@MessagesStack == nil)
          # Display dialog only if showModal exists and that we are currently running the application
          if (showModalWxAvailable?)
            showModal(Wx::MessageDialog, nil,
              iMsg,
              :caption => 'Notification',
              :style => Wx::OK|Wx::ICON_INFORMATION
            ) do |iModalResult, iDialog|
              # Nothing to do
            end
          elsif (defined?($rUtilAnts_Platform_Info) != nil)
            # Use normal platform dependent message, if the platform has been initialized (otherwise, stick to $stderr)
            $rUtilAnts_Platform_Info.sendMsg(iMsg)
          end
        else
          @MessagesStack << iMsg
        end
      end

      # Log an info.
      # This is just common journal.
      #
      # Parameters:
      # * *iMsg* (_String_): Message to log
      def logInfo(iMsg)
        # Log into stdout
        if (@ScreenOutput)
          $stdout << "#{iMsg}\n"
        end
        if (@LogFile != nil)
          logFile(iMsg)
        end
      end

      # Log a warning.
      # Warnings are not errors but still should be highlighted.
      #
      # Parameters:
      # * *iMsg* (_String_): Message to log
      def logWarn(iMsg)
        # Log into stdout
        lMsg = "!!! WARNING !!! - #{iMsg}"
        if (@ScreenOutput)
          $stdout << "#{lMsg}\n"
        end
        if (@LogFile != nil)
          logFile(lMsg)
        end
      end

      # Log a debugging info.
      # This is used when debug is activated
      #
      # Parameters:
      # * *iMsg* (_String_): Message to log
      def logDebug(iMsg)
        # Log into stdout
        if ((@DebugMode) and
            (@ScreenOutput))
          $stdout << "#{iMsg}\n"
        end
        if (@LogFile != nil)
          logFile(iMsg)
        end
      end

      private

      # Check if Wx dialogs environment is set up
      #
      # Return:
      # * _Boolean_: Can we use showModal ?
      def showModalWxAvailable?
        return (
          (defined?(showModal) != nil) and
          (@DialogsGUI == GUI_WX)
        )
      end

      # Log a message in the log file
      #
      # Parameters:
      # * *iMsg* (_String_): The message to log
      def logFile(iMsg)
        File.open(@LogFile, 'a+') do |oFile|
          oFile << "#{Time.now.gmtime.strftime('%Y/%m/%d %H:%M:%S')} - #{iMsg}\n"
        end
      end

      # Get a stack trace in a simple format:
      # Remove @LibRootDir paths from it.
      #
      # Parameters:
      # * *iCaller* (<em>list<String></em>): The caller, or nil if no caller
      # * *iReferenceCaller* (<em>list<String></em>): The reference caller: we will not display lines from iCaller that also belong to iReferenceCaller [optional = nil]
      # Return:
      # * <em>list<String></em>): The simple stack
      def getSimpleCaller(iCaller, iReferenceCaller = nil)
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

        return rSimpleCaller
      end

    end

    # The following methods are meant to be included in a class to be easily useable.

    # Initialize the logging features
    #
    # Parameters:
    # * *iLibRootDir* (_String_): The library root directory that will not appear in the logged stack messages
    # * *iBugTrackerURL* (_String_): The application's bug tracker URL, used to report bugs
    # * *iSilentOutputs* (_Boolean_): Do we silent outputs (nothing sent to $stdout or $stderr) ? [optional = false]
    def self.initializeLogging(iLibRootDir, iBugTrackerURL, iSilentOutputs = false)
      $rUtilAnts_Logging_Logger = RUtilAnts::Logging::Logger.new(iLibRootDir, iBugTrackerURL, iSilentOutputs)
      # Add the module accessible from the Kernel
      Object.module_eval('include RUtilAnts::Logging')
    end

    # Set the log file to use (can be nil to stop logging into a file)
    #
    # Parameters:
    # * *iFileName* (_String_): Log file name (can be nil)
    def setLogFile(iFileName)
      $rUtilAnts_Logging_Logger.setLogFile(iFileName)
    end

    # Get the log file used (can be nil)
    #
    # Return:
    # * _String_: Log file name (can be nil)
    def getLogFile
      return $rUtilAnts_Logging_Logger.getLogFile
    end

    # Indicate which GUI to be used to display dialogs.
    #
    # Parameters:
    # * *iGUIToUse* (_Integer_): The GUI constant, or nil if no GUI is provided
    def setGUIForDialogs(iGUIToUse)
      $rUtilAnts_Logging_Logger.setGUIForDialogs(iGUIToUse)
    end

    # Set the debug mode
    #
    # Parameters:
    # * *iDebugMode* (_Boolean_): Are we in debug mode ?
    def activateLogDebug(iDebugMode)
      $rUtilAnts_Logging_Logger.activateLogDebug(iDebugMode)
    end

    # Set the stack of the errors to fill.
    # If set to nil, errors will be displayed as they appear.
    # If set to a stack, errors will silently be added to the list.
    #
    # Parameters:
    # * *iErrorsStack* (<em>list<String></em>): The stack of errors, or nil to unset it
    def setLogErrorsStack(iErrorsStack)
      $rUtilAnts_Logging_Logger.setLogErrorsStack(iErrorsStack)
    end

    # Set the stack of the messages to fill.
    # If set to nil, messages will be displayed as they appear.
    # If set to a stack, messages will silently be added to the list.
    #
    # Parameters:
    # * *iMessagesStack* (<em>list<String></em>): The stack of messages, or nil to unset it
    def setLogMessagesStack(iMessagesStack)
      $rUtilAnts_Logging_Logger.setLogMessagesStack(iMessagesStack)
    end

    # Log an exception
    # This is called when there is a bug due to an exception in the program. It has been set in many places to detect bugs.
    #
    # Parameters:
    # * *iException* (_Exception_): Exception
    # * *iMsg* (_String_): Message to log
    def logExc(iException, iMsg)
      $rUtilAnts_Logging_Logger.logExc(iException, iMsg)
    end

    # Log a bug
    # This is called when there is a bug in the program. It has been set in many places to detect bugs.
    #
    # Parameters:
    # * *iMsg* (_String_): Message to log
    def logBug(iMsg)
      $rUtilAnts_Logging_Logger.logBug(iMsg)
    end

    # Log an error.
    # Those errors can be normal, as they mainly depend on external factors (lost connection, invalid user file...)
    #
    # Parameters:
    # * *iMsg* (_String_): Message to log
    def logErr(iMsg)
      $rUtilAnts_Logging_Logger.logErr(iMsg)
    end

    # Log a normal message to the user
    # This is used to display a simple message to the user
    #
    # Parameters:
    # * *iMsg* (_String_): Message to log
    def logMsg(iMsg)
      $rUtilAnts_Logging_Logger.logMsg(iMsg)
    end

    # Log an info.
    # This is just common journal.
    #
    # Parameters:
    # * *iMsg* (_String_): Message to log
    def logInfo(iMsg)
      $rUtilAnts_Logging_Logger.logInfo(iMsg)
    end

    # Log a warning.
    # Warnings are not errors but still should be highlighted.
    #
    # Parameters:
    # * *iMsg* (_String_): Message to log
    def logWarn(iMsg)
      $rUtilAnts_Logging_Logger.logWarn(iMsg)
    end

    # Log a debugging info.
    # This is used when debug is activated
    #
    # Parameters:
    # * *iMsg* (_String_): Message to log
    def logDebug(iMsg)
      $rUtilAnts_Logging_Logger.logDebug(iMsg)
    end

  end

end