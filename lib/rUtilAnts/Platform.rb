#--
# Copyright (c) 2009 - 2012 Muriel Salvan (muriel@x-aeon.com)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module RUtilAnts

  module Platform

    module PlatformInterface

      # Initialize the module
      def self.includePlatformSpecificModule
        # Require the platform info
        begin
          require "rUtilAnts/Platforms/#{RUBY_PLATFORM}/PlatformInfo"
        rescue Exception
          if (!defined?(log_bug))
            require 'rUtilAnts/Logging'
            RUtilAnts::Logging::install_logger_on_object
          end
          log_bug "Current platform #{RUBY_PLATFORM} is not supported (#{$!})."
          raise RuntimeError, "Current platform #{RUBY_PLATFORM} is not supported (#{$!})."
        end
        # Include the platform specific module
        PlatformInterface.module_eval('include RUtilAnts::Platform::PlatformInfo')
      end

      includePlatformSpecificModule

    end

    class Manager

      include PlatformInterface

    end

    # OS constants
    OS_WINDOWS = 0
    OS_LINUX = 1
    OS_CYGWIN = 2

    # Initialize the platform info
    def self.install_platform_on_object
      require 'rUtilAnts/SingletonProxy'
      RUtilAnts::make_singleton_proxy(RUtilAnts::Platform::PlatformInterface, Object)
    end

  end

end