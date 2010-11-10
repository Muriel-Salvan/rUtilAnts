#--
# Copyright (c) 2009-2010 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module RUtilAnts

  module Platform

    # OS constants
    OS_WINDOWS = 0
    OS_LINUX = 1
    OS_CYGWIN = 2

    # Initialize the platform info
    def self.initializePlatform
      # Require the platform info
      begin
        require "rUtilAnts/Platforms/#{RUBY_PLATFORM}/PlatformInfo"
      rescue Exception
        if (!defined?(logBug))
          require 'rUtilAnts/Logging'
          RUtilAnts::Logging::initializeLogging(File.expand_path(File.dirname(__FILE__)), '')
        end
        logBug "Current platform #{RUBY_PLATFORM} is not supported (#{$!})."
        raise RuntimeError, "Current platform #{RUBY_PLATFORM} is not supported (#{$!})."
      end
      # Create the corresponding object
      $rUtilAnts_Platform_Info = PlatformInfo.new
      Object.module_eval('include RUtilAnts::Platform')
    end

  end

end