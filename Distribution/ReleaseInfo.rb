#--
# Copyright (c) 2009 Muriel Salvan (murielsalvan@users.sourceforge.net)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

$ReleaseInfo = RubyPackager::ReleaseInfo.new.
  author(
    :Name => 'Muriel Salvan',
    :EMail => 'murielsalvan@users.sourceforge.net',
    :WebPageURL => 'http://murielsalvan.users.sourceforge.net'
  ).
  project(
    :Name => 'rUtilAnts',
    :WebPageURL => 'http://rutilants.sourceforge.net/',
    :Summary => 'A collection of various utility libraries.',
    :Description => 'rUtilAnts is used by several projects. It includes common standard code.',
    :ImageURL => 'http://rutilants.sourceforge.net/wiki/images/c/c9/Logo.png',
    :FaviconURL => 'http://rutilants.sourceforge.net/wiki/images/2/26/Favicon.png',
    :SVNBrowseURL => 'http://rutilants.svn.sourceforge.net/viewvc/rutilants/',
    :DevStatus => 'Alpha'
  ).
  addCoreFiles( [
    'lib/**/*'
  ] ).
  addAdditionalFiles( [
    'README',
    'LICENSE',
    'AUTHORS',
    'Credits',
    'TODO',
    'ChangeLog'
  ] ).
  gem(
    :GemName => 'rUtilAnts',
    :GemPlatformClassName => 'Gem::Platform::RUBY',
    :RequirePath => 'lib',
    :HasRDoc => true
  ).
  sourceForge(
    :Login => 'murielsalvan',
    :ProjectUnixName => 'rutilants'
  ).
  rubyForge(
    :ProjectUnixName => 'rutilants'
  )
