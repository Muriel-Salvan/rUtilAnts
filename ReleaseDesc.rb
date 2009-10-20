#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

{
  # Author information
  :Author => 'Muriel Salvan',
  :EMail => 'murielsalvan@users.sourceforge.net',
  :AuthorURL => 'http://murielsalvan.users.sourceforge.net',
  :SFLogin => 'murielsalvan',

  # Project information
  :Name => 'rUtilAnts',
  :Homepage => 'http://rutilants.sourceforge.net/',
  :Summary => 'A collection of various utility libraries.',
  :Description => 'rUtilAnts is used by several projects. It includes common standard code.',
  :ImageURL => 'http://rutilants.sourceforge.net/wiki/images/c/c9/Logo.png',
  :FaviconURL => 'http://rutilants.sourceforge.net/wiki/images/2/26/Favicon.png',
  :SFUnixName => 'rutilants',
  :RubyForgeProjectName => 'rutilants',
  :SVNBrowseURL => 'http://rutilants.svn.sourceforge.net/viewvc/rutilants/',
  :DevStatus => 'Alpha',

  # Gem information
  :GemName => 'rUtilAnts',
  :GemPlatformClassName => 'Gem::Platform::RUBY',
  :Files => Dir.glob('{lib}/**/*').delete_if do |iFileName|
    ((iFileName == 'CVS') or
     (iFileName == '.svn'))
  end,
  :RequirePath => 'lib',
  :HasRDoc => true,
  :ExtraRDocFiles => [
    'README',
    'TODO',
    'ChangeLog',
    'LICENSE',
    'AUTHORS',
    'Credits'
  ]
}
