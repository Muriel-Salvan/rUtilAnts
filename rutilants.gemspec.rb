# rUtilAnts Gem specification
#
#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

require 'rubygems'

# Return the Gem specification
#
# Return:
# * <em>Gem::Specification</em>: The Gem specification
Gem::Specification.new do |iSpec|
  iSpec.name = 'rUtilAnts'
  iSpec.version = '0.0.1.20090910'
  iSpec.author = 'Muriel Salvan'
  iSpec.email = 'murielsalvan@users.sourceforge.net'
  iSpec.homepage = 'http://rutilants.sourceforge.net/'
  iSpec.platform = Gem::Platform::RUBY
  iSpec.summary = 'A collection of various utility libraries.'
  iSpec.description = 'rUtilAnts is used by several projects. It includes common standard code.'
  iSpec.files = Dir.glob('{lib}/**/*').delete_if do |iFileName|
    ((iFileName == 'CVS') or
     (iFileName == '.svn'))
  end
  iSpec.require_path = 'lib'
  iSpec.has_rdoc = true
  iSpec.extra_rdoc_files = ['README',
                            'TODO',
                            'ChangeLog',
                            'LICENSE',
                            'AUTHORS',
                            'Credits']
end
