require 'test/unit'

require File.join(File.dirname(__FILE__), 'helper.rb')

class CreatorTest < Test::Unit::TestCase

  def setup    ; global_setup    ; end
  def teardown ; global_teardown ; end

  def test_create_site
    in_dir %w{ tmp } do
      Nanoc::Site.create('site')
    end

    assert(File.directory?('tmp/site'))

    assert(File.file?('tmp/site/config.yaml'))
    assert(File.file?('tmp/site/meta.yaml'))
    assert(File.file?('tmp/site/Rakefile'))

    assert(File.directory?('tmp/site/pages'))
    assert(!File.directory?('tmp/site/content'))
    assert(File.file?('tmp/site/pages/index.txt'))
    assert(File.file?('tmp/site/pages/meta.yaml'))

    assert(File.directory?('tmp/site/layouts'))
    assert(File.file?('tmp/site/layouts/default.erb'))

    assert(File.directory?('tmp/site/lib'))
    assert(File.file?('tmp/site/lib/default.rb'))

    assert(File.directory?('tmp/site/output'))

    assert(File.directory?('tmp/site/templates'))
    assert(File.directory?('tmp/site/templates/default'))
    assert(File.file?('tmp/site/templates/default/default.txt'))
    assert(File.file?('tmp/site/templates/default/default.yaml'))

    assert(File.directory?('tmp/site/tasks'))
    assert(File.file?('tmp/site/tasks/default.rake'))
  end

  def test_create_site_with_existing_name
    in_dir %w{ tmp } do
      assert_nothing_raised()   { Nanoc::Site.create('site') }
      assert_raise(SystemExit)  { Nanoc::Site.create('site') }
    end
  end

end
