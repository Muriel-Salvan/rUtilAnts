#--
# Copyright (c) 2012 Muriel Salvan (muriel@x-aeon.com)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

module RUtilAnts

  # Make public methods from a module accessible in another module, using a singleton as proxy
  #
  # Parameters::
  # * *iSrcModule* (_Module_): Module to get public methods from
  # * *oDstModule* (_Module_): Module that will encapsulate the singleton and route all public methods through that singleton
  def self.make_singleton_proxy(iSrcModule, oDstModule)
    lSrcModuleConstName = iSrcModule.name.gsub(/\W/,'_')
    # Create the singleton class
    if !oDstModule.const_defined?("SingletonClassForModule__#{lSrcModuleConstName}")
      lSingletonClass = oDstModule.const_set("SingletonClassForModule__#{lSrcModuleConstName}", Class.new)
      lSingletonClass.class_eval("include #{iSrcModule}")
      # Instantiate it in the module
      lSymSingletonVarName = "@@__SingletonForModule__#{lSrcModuleConstName}".to_sym
      oDstModule.send(:class_variable_set, lSymSingletonVarName, lSingletonClass.new)
      # Create public methods from iSrcModule to oDstModule, using the singleton as a proxy
      iSrcModule.instance_methods.map { |iMethodName| iMethodName.to_sym }.each do |iSymMethodName|
        oDstModule.send(:define_method, iSymMethodName) do |*iArgs, &iBlock|
          oDstModule.send(:class_variable_get, lSymSingletonVarName).send(iSymMethodName, *iArgs, &iBlock)
        end
      end
    end
  end

end
