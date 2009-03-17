require 'test/helper'

class Nanoc3::Helpers::TextTest < MiniTest::Unit::TestCase

  def setup    ; global_setup    ; end
  def teardown ; global_teardown ; end

  include Nanoc3::Helpers::Text

  def test_excerpt_length
    assert_equal('...',                         excerptize('Foo bar baz quux meow woof', :length => 3))
    assert_equal('Foo ...',                     excerptize('Foo bar baz quux meow woof', :length => 7))
    assert_equal('Foo bar baz quux meow woof',  excerptize('Foo bar baz quux meow woof', :length => 26))
    assert_equal('Foo bar baz quux meow woof',  excerptize('Foo bar baz quux meow woof', :length => 8623785))
  end

  def test_excerpt_omission
    assert_equal('Foo [continued]',             excerptize('Foo bar baz quux meow woof', :length => 15, :omission => '[continued]'))
  end

  def test_strip_html
    # TODO implement
  end

end
