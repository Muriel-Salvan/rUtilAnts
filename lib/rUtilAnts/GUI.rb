#--
# Copyright (c) 2009 - 2012 Muriel Salvan (muriel@x-aeon.com)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

# WxRuby has to be loaded correctly in the environment before requiring this file

module RUtilAnts

  module GUI

    # The class that assigns dynamically images to a given TreeCtrl items
    class ImageListManager

      # Constructor
      #
      # Parameters::
      # * *ioImageList* (<em>Wx::ImageList</em>): The image list this manager will handle
      # * *iWidth* (_Integer_): The images width
      # * *iHeight* (_Integer_): The images height
      def initialize(ioImageList, iWidth, iHeight)
        @ImageList = ioImageList
        # TODO (WxRuby): Get the size directly from ioImageList (get_size does not work)
        @Width = iWidth
        @Height = iHeight
        # The internal map of image IDs => indexes
        # map< Object, Integer >
        @Id2Idx = {}
      end

      # Get the image index for a given image ID
      #
      # Parameters::
      # * *iID* (_Object_): Id of the image
      # * *CodeBlock*: The code that will be called if the image ID is unknown. This code has to return a Wx::Bitmap object, representing the bitmap for the given image ID.
      def getImageIndex(iID)
        if (@Id2Idx[iID] == nil)
          # Bitmap unknown.
          # First create it.
          lBitmap = yield
          # Then check if we need to resize it
          lBitmap = getResizedBitmap(lBitmap, @Width, @Height)
          # Then add it to the image list, and register it
          @Id2Idx[iID] = @ImageList.add(lBitmap)
        end

        return @Id2Idx[iID]
      end

    end

    # Generic progress dialog, meant to be overriden to customize behaviour
    class ProgressDialog < Wx::Dialog

      # Value for the undetermined range
      DEFAULT_UNDETERMINED_RANGE = 10

      # Is the current dialog in determined mode ?
      #   Boolean
      attr_reader :Determined

      # Has the current dialog been cancelled ?
      #   Boolean
      attr_reader :Cancelled

      # Constructor
      #
      # Parameters::
      # * *iParentWindow* (<em>Wx::Window</em>): Parent window
      # * *iCodeToExecute* (_Proc_): The code to execute that will update the progression
      # * *iParameters* (<em>map<Symbol,Object></em>): Additional parameters:
      #   * *:cancellable* (_Boolean_): Can we cancel this dialog ? [optional = false]
      #   * *:title* (_String_): Caption of the progress dialog [optional = '']
      #   * *:icon* (<em>Wx::Bitmap</em>): Icon of the progress dialog [optional = nil]
      def initialize(iParentWindow, iCodeToExecute, iParameters = {})
        lCancellable = iParameters[:cancellable]
        if (lCancellable == nil)
          lCancellable = false
        end
        lTitle = iParameters[:Title]
        if (lTitle == nil)
          lTitle = ''
        end
        lIcon = iParameters[:Icon]
        super(iParentWindow,
          :title => lTitle,
          :style => Wx::THICK_FRAME|Wx::CAPTION
        )
        if (lIcon != nil)
          lRealIcon = Wx::Icon.new
          lRealIcon.copy_from_bitmap(lIcon)
          set_icon(lRealIcon)
        end

        @CodeToExecute = iCodeToExecute

        # Has the transaction been cancelled ?
        @Cancelled = false

        # Create components
        @GProgress = Wx::Gauge.new(self, Wx::ID_ANY, 0)
        @GProgress.set_size_hints(-1,12,-1,12)
        lBCancel = nil
        if (lCancellable)
          lBCancel = Wx::Button.new(self, Wx::CANCEL, 'Cancel')
        end
        lPTitle = getTitlePanel

        # Put them into sizers
        lMainSizer = Wx::BoxSizer.new(Wx::VERTICAL)
        lMainSizer.add_item(lPTitle, :flag => Wx::GROW|Wx::ALL, :proportion => 1, :border => 8)
        if (lCancellable)
          lBottomSizer = Wx::BoxSizer.new(Wx::HORIZONTAL)
          lBottomSizer.add_item(@GProgress, :flag => Wx::ALIGN_CENTER|Wx::ALL, :proportion => 1, :border => 4)
          lBottomSizer.add_item(lBCancel, :flag => Wx::ALIGN_CENTER, :proportion => 0)
          lMainSizer.add_item(lBottomSizer, :flag => Wx::GROW|Wx::ALL, :proportion => 0, :border => 8)
        else
          lMainSizer.add_item(@GProgress, :flag => Wx::GROW|Wx::ALL, :proportion => 0, :border => 4)
        end
        self.sizer = lMainSizer

        # Set events
        if (lCancellable)
          evt_button(lBCancel) do |iEvent|
            @Cancelled = true
            lBCancel.enable(false)
            lBCancel.label = 'Cancelling ...'
            self.fit
          end
        end
        lExecCompleted = false
        evt_idle do |iEvent|
          # Execute the code once
          if (!lExecCompleted)
            lExecCompleted = true
            @CodeToExecute.call(self)
          end
          self.end_modal(Wx::ID_OK)
        end

        # By default, consider that we don't know the range of progression
        # That's why we set a default range (undetermined progression needs a range > 0 to have visual effects)
        @GProgress.range = DEFAULT_UNDETERMINED_RANGE
        @Determined = false

        self.fit

        refreshState
      end

      # Called to refresh our dialog
      def refreshState
        self.refresh
        self.update
        # Process eventual user request to stop transaction
        Wx.get_app.yield
      end

      # Set the progress range
      #
      # Parameters::
      # * *iRange* (_Integer_): The progress range
      def setRange(iRange)
        @GProgress.range = iRange
        if (!@Determined)
          @Determined = true
          @GProgress.value = 0
        end
        refreshState
      end

      # Set the progress value
      #
      # Parameters::
      # * *iValue* (_Integer_): The progress value
      def setValue(iValue)
        @GProgress.value = iValue
        refreshState
      end

      # Increment the progress value
      #
      # Parameters::
      # * *iIncrement* (_Integer_): Value to increment [optional = 1]
      def incValue(iIncrement = 1)
        @GProgress.value += iIncrement
        refreshState
      end

      # Increment the progress range
      #
      # Parameters::
      # * *iIncrement* (_Integer_): Value to increment [optional = 1]
      def incRange(iIncrement = 1)
        if (@Determined)
          @GProgress.range += iIncrement
        else
          @Determined = true
          @GProgress.range = iIncrement
          @GProgress.value = 0
        end
        refreshState
      end

      # Pulse the progression (to be used when we don't know the range)
      def pulse
        if (@Determined)
          @Determined = false
          @GProgress.range = DEFAULT_UNDETERMINED_RANGE
        end
        @GProgress.pulse
        refreshState
      end

    end

    # Text progress dialog
    class TextProgressDialog < ProgressDialog

      # Constructor
      #
      # Parameters::
      # * *iParentWindow* (<em>Wx::Window</em>): Parent window
      # * *iCodeToExecute* (_Proc_): The code to execute that will update the progression
      # * *iText* (_String_): The text to display
      # * *iParameters* (<em>map<Symbol,Object></em>): Additional parameters (check RUtilAnts::GUI::ProgressDialog#initialize documentation):
      def initialize(iParentWindow, iCodeToExecute, iText, iParameters = {})
        @Text = iText
        super(iParentWindow, iCodeToExecute, iParameters)
      end

      # Get the panel to display as title
      #
      # Return::
      # * <em>Wx::Panel</em>: The panel to use as a title
      def getTitlePanel
        rPanel = Wx::Panel.new(self)

        # Create components
        @STText = Wx::StaticText.new(rPanel, Wx::ID_ANY, @Text, :style => Wx::ALIGN_CENTRE)

        # Put them into sizers
        lMainSizer = Wx::BoxSizer.new(Wx::VERTICAL)
        lMainSizer.add_item(@STText, :flag => Wx::GROW, :proportion => 1)
        rPanel.sizer = lMainSizer

        return rPanel
      end

      # Set the text
      #
      # Parameters::
      # * *iText* (_String_): The text
      def setText(iText)
        @STText.label = iText
        self.fit
        refreshState
      end

    end

    # Bitmap progress dialog
    class BitmapProgressDialog < ProgressDialog

      # Constructor
      #
      # Parameters::
      # * *iParentWindow* (<em>Wx::Window</em>): Parent window
      # * *iCodeToExecute* (_Proc_): The code to execute that will update the progression
      # * *iBitmap* (<em>Wx::Bitmap</em>): The bitmap to display (can be nil)
      # * *iParameters* (<em>map<Symbol,Object></em>): Additional parameters (check RUtilAnts::GUI::ProgressDialog#initialize documentation):
      def initialize(iParentWindow, iCodeToExecute, iBitmap, iParameters = {})
        @Bitmap = iBitmap
        super(iParentWindow, iCodeToExecute, iParameters)
      end

      # Get the panel to display as title
      #
      # Return::
      # * <em>Wx::Panel</em>: The panel to use as a title
      def getTitlePanel
        rPanel = Wx::Panel.new(self)

        # Create components
        if (@Bitmap == nil)
          @SBBitmap = Wx::StaticBitmap.new(rPanel, Wx::ID_ANY, Wx::Bitmap.new)
        else
          @SBBitmap = Wx::StaticBitmap.new(rPanel, Wx::ID_ANY, @Bitmap)
        end

        # Put them into sizers
        lMainSizer = Wx::BoxSizer.new(Wx::VERTICAL)
        lMainSizer.add_item(@SBBitmap, :flag => Wx::GROW, :proportion => 1)
        rPanel.sizer = lMainSizer

        return rPanel
      end

      # Set the bitmap
      #
      # Parameters::
      # * *iBitmap* (<em>Wx::Bitmap</em>): The bitmap
      def setBitmap(iBitmap)
        @SBBitmap.bitmap = iBitmap
        self.fit
        refreshState
      end

    end

    # Manager that handles normal Wx::Timer, integrating a mechanism that can kill it and wait until it has been safely killed.
    # Very handy for timers processing data that might be destroyed.
    # To be used with safeTimerAfter and safeTimerEvery.
    class SafeTimersManager
      
      # Constructor
      def initialize
        # List of registered timers
        # list< Wx::Timer >
        @Timers = []
      end

      # Register a given timer
      #
      # Parameters::
      # * *iTimer* (<em>Wx::Timer</em>): The timer to register
      def registerTimer(iTimer)
        @Timers << iTimer
      end

      # Unregister a given timer
      #
      # Parameters::
      # * *iTimer* (<em>Wx::Timer</em>): The timer to unregister
      # Return::
      # * _Boolean_: Was the Timer registered ?
      def unregisterTimer(iTimer)
        rFound = false

        @Timers.delete_if do |iRegisteredTimer|
          if (iRegisteredTimer == iTimer)
            rFound = true
            next true
          else
            next false
          end
        end

        return rFound
      end

      # Kill all registered Timers and wait for their completion.
      # Does not return unless they are stopped.
      def killTimers
        # Notify each Timer that it has to stop
        @Timers.each do |ioTimer|
          ioTimer.stop
        end
        # Wait for each one to be stopped
        lTimersToStop = []
        # Try first time, to not enter the loop if they were already stopped
        @Timers.each do |iTimer|
          if (iTimer.is_running)
            lTimersToStop << iTimer
          end
        end
        while (!lTimersToStop.empty?)
          lTimersToStop.delete_if do |iTimer|
            next (!iTimer.is_running)
          end
          # Give time to the application to effectively stop its timers
          Wx.get_app.yield
          # Little sleep
          sleep(0.1)
        end
      end

    end

    # Initialize the GUI methods in the Object namespace
    def self.initializeGUI
      Object.module_eval('include RUtilAnts::GUI')
    end

    # Get a bitmap resized to a given size if it differs from it
    #
    # Parameters::
    # * *iBitmap* (<em>Wx::Bitmap</em>): The original bitmap
    # * *iWidth* (_Integer_): The width of the resized bitmap
    # * *iHeight* (_Integer_): The height of the resized bitmap
    # Return::
    # * <em>Wx::Bitmap</em>: The resized bitmap (can be the same object as iBitmap)
    def getResizedBitmap(iBitmap, iWidth, iHeight)
      rResizedBitmap = iBitmap

      if ((iBitmap.width != iWidth) or
          (iBitmap.height != iHeight))
        rResizedBitmap = Wx::Bitmap.new(iBitmap.convert_to_image.scale(iWidth, iHeight))
      end

      return rResizedBitmap
    end

    # Display a dialog in modal mode, ensuring it is destroyed afterwards.
    #
    # Parameters::
    # * *iDialogClass* (_class_): Class of the dialog to display
    # * *iParentWindow* (<em>Wx::Window</em>): Parent window (can be nil)
    # * *iParameters* (...): List of parameters to give the constructor
    # * *CodeBlock*: The code called once the dialog has been displayed and modally closed
    #   * *iModalResult* (_Integer_): Modal result
    #   * *iDialog* (<em>Wx::Dialog</em>): The dialog
    def showModal(iDialogClass, iParentWindow, *iParameters)
      # If the parent is nil, we fall into a buggy behaviour in the case of GC enabled:
      # * If we destroy the window after show_modal, random core dumps occur in the application
      # * If not, the application can't exit normally
      # Therefore, in case of nil, we assign the top window as the parent.
      # Sometimes, there is no top_window. So we'll stick with nil.
      lParentWindow = iParentWindow
      if (lParentWindow == nil)
        lParentWindow = Wx.get_app.get_top_window
      end
      lDialog = iDialogClass.new(lParentWindow, *iParameters)
      lDialog.centre(Wx::CENTRE_ON_SCREEN|Wx::BOTH)
      lModalResult = lDialog.show_modal
      yield(lModalResult, lDialog)
      # If we destroy windows having parents, we get SegFaults during execution when mouse hovers some toolbar icons and moves (except if we disable GC: in this case it works perfectly fine, but consumes tons of memory).
      # If we don't destroy, we got ObjectPreviouslyDeleted exceptions on exit with wxRuby 2.0.0 (seems to have disappeared in 2.0.1).
      # TODO (wxRuby): Correct bug on Tray before enabling GC and find the good solution for modal destruction.
      if (lParentWindow == nil)
        lDialog.destroy
      end
    end

    # Get a bitmap/icon from a URL.
    # If no type has been provided, it detects the type of icon based on the file extension.
    # Use URL caching.
    #
    # Parameters::
    # * *iFileName* (_String_): The file name
    # * *iIconIndex* (_Integer_): Specify the icon index (used by Windows for EXE/DLL/ICO...) [optional = nil]
    # * *iBitmapTypes* (_Integer_ or <em>list<Integer></em>): Bitmap/Icon type. Can be nil for autodetection. Can be the list of types to try. [optional = nil]
    # Return::
    # * <em>Wx::Bitmap</em>: The bitmap, or nil in case of failure
    # * _Exception_: The exception containing details about the error, or nil in case of success
    def getBitmapFromURL(iFileName, iIconIndex = nil, iBitmapTypes = nil)
      rReadBitmap = nil
      rReadError = nil

      rReadBitmap, rReadError = get_url_content(iFileName, :local_file_access => true) do |iRealFileName|
        rBitmap = nil
        rError = nil

        lBitmapTypesToTry = iBitmapTypes
        if (iBitmapTypes == nil)
          # Autodetect
          lBitmapTypesToTry = [ Wx::Bitmap::BITMAP_TYPE_GUESS[File.extname(iRealFileName).downcase[1..-1]] ]
          if (lBitmapTypesToTry == [ nil ])
            # Here we handle extensions that wxruby is not aware of
            case File.extname(iRealFileName).upcase
            when '.CUR', '.ANI', '.EXE', '.DLL'
              lBitmapTypesToTry = [ Wx::BITMAP_TYPE_ICO ]
            else
              log_err "Unable to determine the bitmap type corresponding to extension #{File.extname(iRealFileName).upcase}. Assuming ICO."
              lBitmapTypesToTry = [ Wx::BITMAP_TYPE_ICO ]
            end
          end
        elsif (!iBitmapTypes.is_a?(Array))
          lBitmapTypesToTry = [ iBitmapTypes ]
        end
        # Try each type
        lBitmapTypesToTry.each do |iBitmapType|
          # Special case for the ICO type
          if (iBitmapType == Wx::BITMAP_TYPE_ICO)
            lIconID = iRealFileName
            if ((iIconIndex != nil) and
                (iIconIndex != 0))
              # TODO: Currently this implementation does not work. Uncomment when ok.
              #lIconID += ";#{iIconIndex}"
            end
            rBitmap = Wx::Bitmap.new
            begin
              rBitmap.copy_from_icon(Wx::Icon.new(lIconID, Wx::BITMAP_TYPE_ICO))
            rescue Exception
              rError = $!
              rBitmap = nil
            end
          else
            rBitmap = Wx::Bitmap.new(iRealFileName, iBitmapType)
          end
          if (rBitmap != nil)
            if (rBitmap.is_ok)
              break
            else
              # File seems to be corrupted
              rError = RuntimeError.new("Bitmap #{iFileName} is corrupted.")
              rBitmap = nil
            end
          else
            rBitmap = nil
          end
        end

        return rBitmap, rError
      end
      
      # Check if it is ok and the error set correctly
      if ((rReadBitmap == nil) and
          (rReadError == nil))
        rError = RuntimeError.new("Unable to get bitmap from #{iFileName}")
      end

      return rReadBitmap, rReadError
    end

    # Setup a progress bar with some text in it and call code around it
    #
    # Parameters::
    # * *iParentWindow* (<em>Wx::Window</em>): The parent window
    # * *iText* (_String_): The text to display
    # * *iParameters* (<em>map<Symbol,Object></em>): Additional parameters (check RUtilAnts::GUI::ProgressDialog#initialize documentation):
    # * _CodeBlock_: The code called with the progress bar created:
    #   * *ioProgressDlg* (<em>RUtilAnts::GUI::ProgressDialog</em>): The progress dialog
    def setupTextProgress(iParentWindow, iText, iParameters = {}, &iCodeToExecute)
      showModal(TextProgressDialog, iParentWindow, iCodeToExecute, iText, iParameters) do |iModalResult, iDialog|
        # Nothing to do
      end
    end

    # Setup a progress bar with some bitmap in it and call code around it
    #
    # Parameters::
    # * *iParentWindow* (<em>Wx::Window</em>): The parent window
    # * *iBitmap* (<em>Wx::Bitmap</em>): The bitmap to display
    # * *iParameters* (<em>map<Symbol,Object></em>): Additional parameters (check RUtilAnts::GUI::ProgressDialog#initialize documentation):
    # * _CodeBlock_: The code called with the progress bar created:
    #   * *ioProgressDlg* (<em>RUtilAnts::GUI::ProgressDialog</em>): The progress dialog
    def setupBitmapProgress(iParentWindow, iBitmap, iParameters = {}, &iCodeToExecute)
      showModal(BitmapProgressDialog, iParentWindow, iCodeToExecute, iBitmap, iParameters) do |iModalResult, iDialog|
        # Nothing to do
      end
    end

    # Execute some code after some elapsed time.
    #
    # Parameters::
    # * *ioSafeTimersManager* (_SafeTimersManager_): The manager that handles this SafeTimer
    # * *iElapsedTime* (_Integer_): The elapsed time to wait before running the code
    # * _CodeBlock_: The code to execute
    def safeTimerAfter(ioSafeTimersManager, iElapsedTime)
      # Create the Timer and register it
      lTimer = nil
      lTimer = Wx::Timer.after(iElapsedTime) do
        yield
        # Now the Timer can be safely destroyed.
        ioSafeTimersManager.unregisterTimer(lTimer)
      end
      ioSafeTimersManager.registerTimer(lTimer)
    end

    # Execute some code every some elapsed time.
    #
    # Parameters::
    # * *ioSafeTimersManager* (_SafeTimersManager_): The manager that handles this SafeTimer
    # * *iElapsedTime* (_Integer_): The elapsed time to wait before running the code
    # * _CodeBlock_: The code to execute
    def safeTimerEvery(ioSafeTimersManager, iElapsedTime)
      # Create the Timer and register it
      lTimer = Wx::Timer.every(iElapsedTime) do
        yield
      end
      ioSafeTimersManager.registerTimer(lTimer)
    end

  end

end
