#--
# Copyright (c) 2009 - 2012 Muriel Salvan (muriel@x-aeon.com)
# Licensed under the terms specified in LICENSE file. No warranty is provided.
#++

RubyPackager::ReleaseInfo.new.
  author(
    :name => 'Muriel Salvan',
    :email => 'muriel@x-aeon.com',
    :web_page_url => 'http://murielsalvan.users.sourceforge.net'
  ).
  project(
    :name => 'rUtilAnts',
    :web_page_url => 'http://rutilants.sourceforge.net/',
    :summary => 'A collection of various utility libraries.',
    :description => 'rUtilAnts is used by several projects. It includes common standard code.',
    :image_url => 'http://rutilants.sourceforge.net/wiki/images/c/c9/Logo.png',
    :favicon_url => 'http://rutilants.sourceforge.net/wiki/images/2/26/Favicon.png',
    :browse_source_url => 'http://rutilants.git.sourceforge.net/',
    :dev_status => 'Beta'
  ).
  add_core_files( [
    'lib/**/*'
  ] ).
  add_additional_files( [
    'README',
    'LICENSE',
    'AUTHORS',
    'Credits',
    'ChangeLog'
  ] ).
  gem(
    :gem_name => 'rUtilAnts',
    :gem_platform_class_name => 'Gem::Platform::RUBY',
    :require_path => 'lib',
    :has_rdoc => true
  ).
  source_forge(
    :login => 'murielsalvan',
    :project_unix_name => 'rutilants'
  ).
  ruby_forge(
    :project_unix_name => 'rutilants'
  )
