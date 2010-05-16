# encoding: utf-8

require 'test/helper'

class Nanoc3::CompilerTest < MiniTest::Unit::TestCase

  include Nanoc3::TestHelpers

  def test_compilation_rule_for
    # Mock rules
    rules = [ mock, mock, mock ]
    rules[0].expects(:applicable_to?).returns(false)
    rules[1].expects(:applicable_to?).returns(true)
    rules[1].expects(:rep_name).returns('wrong')
    rules[2].expects(:applicable_to?).returns(true)
    rules[2].expects(:rep_name).returns('right')

    # Create compiler
    compiler = Nanoc3::Compiler.new(nil)
    compiler.instance_eval { @item_compilation_rules = rules }

    # Mock rep
    rep = mock
    rep.stubs(:name).returns('right')
    item = mock
    rep.stubs(:item).returns(item)

    # Test
    assert_equal rules[2], compiler.compilation_rule_for(rep)
  end

  def test_routing_rule_for
    # Mock rules
    rules = [ mock, mock, mock ]
    rules[0].expects(:applicable_to?).returns(false)
    rules[1].expects(:applicable_to?).returns(true)
    rules[1].expects(:rep_name).returns('wrong')
    rules[2].expects(:applicable_to?).returns(true)
    rules[2].expects(:rep_name).returns('right')

    # Create compiler
    compiler = Nanoc3::Compiler.new(nil)
    compiler.instance_eval { @item_routing_rules = rules }

    # Mock rep
    rep = mock
    rep.stubs(:name).returns('right')
    item = mock
    rep.stubs(:item).returns(item)

    # Test
    assert_equal rules[2], compiler.routing_rule_for(rep)
  end

  def test_filter_for_layout_with_existant_layout
    # Mock site
    site = mock

    # Create compiler
    compiler = Nanoc3::Compiler.new(site)
    compiler.layout_filter_mapping[/.*/] = [ :erb, { :foo => 'bar' } ]

    # Mock layout
    layout = MiniTest::Mock.new
    layout.expect(:identifier, '/some_layout/')

    # Check
    assert_equal([ :erb, { :foo => 'bar' } ], compiler.filter_for_layout(layout))
  end

  def test_filter_for_layout_with_existant_layout_and_unknown_filter
    # Mock site
    site = mock

    # Create compiler
    compiler = Nanoc3::Compiler.new(site)
    compiler.layout_filter_mapping[/.*/] = [ :some_unknown_filter, { :foo => 'bar' } ]

    # Mock layout
    layout = MiniTest::Mock.new
    layout.expect(:identifier, '/some_layout/')

    # Check
    assert_equal([ :some_unknown_filter, { :foo => 'bar' } ], compiler.filter_for_layout(layout))
  end

  def test_filter_for_layout_with_nonexistant_layout
    # Mock site
    site = mock

    # Create compiler
    compiler = Nanoc3::Compiler.new(site)
    compiler.layout_filter_mapping[%r{^/foo/$}] = [ :erb, { :foo => 'bar' } ]

    # Mock layout
    layout = MiniTest::Mock.new
    layout.expect(:identifier, '/bar/')

    # Check
    assert_equal(nil, compiler.filter_for_layout(layout))
  end

  def test_filter_for_layout_with_many_layouts
    # Mock site
    site = mock

    # Create compiler
    compiler = Nanoc3::Compiler.new(site)
    compiler.layout_filter_mapping[%r{^/a/b/c/.*/$}] = [ :erb, { :char => 'd' } ]
    compiler.layout_filter_mapping[%r{^/a/.*/$}]     = [ :erb, { :char => 'b' } ]
    compiler.layout_filter_mapping[%r{^/a/b/.*/$}]   = [ :erb, { :char => 'c' } ] # never used!
    compiler.layout_filter_mapping[%r{^/.*/$}]       = [ :erb, { :char => 'a' } ]

    # Mock layout
    layouts = [ mock, mock, mock, mock ]
    layouts[0].stubs(:identifier).returns('/a/b/c/d/')
    layouts[1].stubs(:identifier).returns('/a/b/c/')
    layouts[2].stubs(:identifier).returns('/a/b/')
    layouts[3].stubs(:identifier).returns('/a/')

    # Get expectations
    expectations = {
      0 => 'd',
      1 => 'b', # never used! not c, because b takes priority
      2 => 'b',
      3 => 'a'
    }

    # Check
    expectations.each_pair do |num, char|
      filter_and_args = compiler.filter_for_layout(layouts[num])
      refute_nil(filter_and_args)
      assert_equal(char, filter_and_args[1][:char])
    end
  end

  def test_compile_rep
    # Mock rep
    item = Nanoc3::Item.new('content', {}, '/moo/')
    rep = Nanoc3::ItemRep.new(item, :blah)

    # Create compiler
    compiler = Nanoc3::Compiler.new(nil)
    compilation_rule = mock
    compilation_rule.expects(:apply_to).with(rep)
    compiler.expects(:compilation_rule_for).returns(compilation_rule)

    # Compile
    compiler.send :compile_rep, rep
    assert rep.compiled?
  end

  def test_compile_rep_with_unmet_dependency
    # Mock rep
    item = Nanoc3::Item.new('content', {}, '/moo/')
    rep = Nanoc3::ItemRep.new(item, :blah)
    rep.expects(:forget_progress)

    # Create compiler
    compiler = Nanoc3::Compiler.new(nil)
    compilation_rule = mock
    compilation_rule.expects(:apply_to).with(rep).raises(Nanoc3::Errors::UnmetDependency, rep)
    compiler.expects(:compilation_rule_for).returns(compilation_rule)

    # Compile
    assert_raises Nanoc3::Errors::UnmetDependency do
      compiler.send :compile_rep, rep
    end
  end

  def test_compile_rep_should_write_proper_snapshots
    # Mock rep
    item = Nanoc3::Item.new('<%= 1 %> <%%= 2 %> <%%%= 3 %>', {}, '/moo/')
    rep  = Nanoc3::ItemRep.new(item, :blah)

    # Set snapshot filenames
    rep.raw_paths = {
      :raw  => 'raw.txt',
      :pre  => 'pre.txt',
      :post => 'post.txt',
      :last => 'last.txt'
    }

    # Create rule
    rule_block = lambda do
      filter :erb
      filter :erb
      layout '/blah/'
      filter :erb
    end
    rule = Nanoc3::Rule.new(/blah/, :meh, rule_block)

    # Create layout
    layout = Nanoc3::Layout.new('head <%= yield %> foot', {}, '/')
    rep.expects(:layout_with_identifier).returns(layout)
    filter = Nanoc3::PluginRegistry.instance.find(Nanoc3::Filter, :erb)
    rep.expects(:filter_for_layout).with(layout).returns(filter.new({ :content => 'middle' }))

    # Create site
    site = mock
    site.stubs(:config).returns({})
    site.stubs(:items).returns([])
    site.stubs(:layouts).returns([])
    item.site = site

    # Create compiler
    compiler = Nanoc3::Compiler.new(site)
    compiler.expects(:compilation_rule_for).with(rep).returns(rule)
    site.stubs(:compiler).returns(compiler)

    # Compile
    compiler.send(:compile_rep, rep)

    # Test
    assert File.file?('raw.txt')
    assert File.file?('pre.txt')
    assert File.file?('post.txt')
    assert File.file?('last.txt')
    assert_equal '<%= 1 %> <%%= 2 %> <%%%= 3 %>', File.read('raw.txt')
    assert_equal '1 2 <%= 3 %>',                  File.read('pre.txt')
    assert_equal 'head middle foot',              File.read('post.txt')
    assert_equal 'head middle foot',              File.read('last.txt')
  end

  def test_compile_reps_with_no_reps
    # Create compiler
    compiler = Nanoc3::Compiler.new(nil)
    compiler.expects(:compile_rep).never

    # Compile
    compiler.send :compile_reps, []
  end

  def test_compile_reps_with_one_rep
    # Mock reps
    item = Nanoc3::Item.new("content1", {}, '/one/')
    rep  = Nanoc3::ItemRep.new(item, :moo)

    # Create compiler
    compiler = Nanoc3::Compiler.new(nil)
    compiler.expects(:compile_rep).with(rep)

    # Compile
    compiler.send :compile_reps, [ rep ]
  end

  def test_compile_reps_with_two_independent_reps
    # Mock reps
    items = [ Nanoc3::Item.new("content1", {}, '/one/'), Nanoc3::Item.new("content2", {}, '/two/') ]
    reps  = [ Nanoc3::ItemRep.new(items[0], :moo), Nanoc3::ItemRep.new(items[1], :blah) ]

    # Create compiler
    compiler = Nanoc3::Compiler.new(nil)
    compiler.expects(:compile_rep).times(2)

    # Compile
    compiler.send :compile_reps, reps

    # Check size of reps array
    assert_equal 2, reps.size
  end

  def test_compile_reps_with_two_dependent_reps
    # Mock reps
    items = [ Nanoc3::Item.new("content1", {}, '/one/'), Nanoc3::Item.new("content2", {}, '/two/') ]
    reps  = [ Nanoc3::ItemRep.new(items[0], :moo), Nanoc3::ItemRep.new(items[1], :blah) ]

    # Create compiler
    compiler = Nanoc3::Compiler.new(nil)
    compiler.instance_eval { @_reps = reps }
    def compiler.compile_rep(rep)
      @_invocation_id ||= 0
      @_called_reps   ||= []

      case @_invocation_id
      when 0
        @_invocation_id = 1
        @_called_reps[0] = rep
        raise Nanoc3::Errors::UnmetDependency.new(@_reps[1])
      when 1
        @_invocation_id = 2
        @_called_reps[1] = rep
      when 2
        @_invocation_id = 3
        @_called_reps[2] = rep
      end
    end

    # Compile
    compiler.send :compile_reps, reps

    # Check
    assert_equal reps[0], compiler.instance_eval { @_called_reps[0] }
    assert_equal reps[1], compiler.instance_eval { @_called_reps[1] }
    assert_equal reps[0], compiler.instance_eval { @_called_reps[2] }
  end

  def test_compile_reps_with_two_mutually_dependent_reps
    # Mock reps
    items = [ Nanoc3::Item.new("content1", {}, '/one/'), Nanoc3::Item.new("content2", {}, '/two/') ]
    reps  = [ Nanoc3::ItemRep.new(items[0], :moo), Nanoc3::ItemRep.new(items[1], :blah) ]

    # Create compiler
    compiler = Nanoc3::Compiler.new(nil)
    compiler.instance_eval { @_reps = reps }
    def compiler.compile_rep(rep)
      if rep == @_reps[0]
        raise Nanoc3::Errors::UnmetDependency.new(@_reps[1])
      elsif rep == @_reps[1]
        raise Nanoc3::Errors::UnmetDependency.new(@_reps[0])
      else
        raise RuntimeError, 'this shouldn not have happened'
      end
    end

    # Compile
    assert_raises Nanoc3::Errors::RecursiveCompilation do
      compiler.send :compile_reps, reps
    end
  end

  def test_not_outdated
    # Mock code snippets
    code_snippets = [ Nanoc3::CodeSnippet.new('def moo ; end', 'lib/cow.rb') ]

    # Mock site
    site = Nanoc3::Site.new({})
    site.stubs(:code_snippets).returns(code_snippets)

    # Mock item
    item = Nanoc3::Item.new('blah blah blah', {}, '/')

    # Create rep
    rep = Nanoc3::ItemRep.new(item, 'blah')
    rep.raw_path = 'moo.html'

    # Write output file
    File.open(rep.raw_path, 'w') { |io| io.write("o hai how r u") }

    # Mock checksums
    require 'pstore'
    FileUtils.mkdir_p('tmp')
    store = PStore.new('tmp/checksums')
    store.transaction do
      store[:version] = 1
      store[:data] = {
        item.reference             => Nanoc3::ChecksumStore.new.new_checksum_for(item),
        code_snippets[0].reference => Nanoc3::ChecksumStore.new.new_checksum_for(code_snippets[0]),
        :config                    => Nanoc3::ChecksumStore.new.new_checksum_for(site.config),
        :rules                     => Nanoc3::ChecksumStore.new.new_checksum_for(site.rules_with_reference)
      }
    end

    # Check
    compiler = Nanoc3::Compiler.new(site)
    compiler.send(:checksum_store).load
    assert_nil compiler.outdatedness_reason_for(rep)
  end

  def test_outdated_if_item_checksum_nil
    # Mock code snippets
    code_snippets = [ mock ]
    code_snippets[0].stubs(:outdated?).returns(false)

    # Mock site
    site = Nanoc3::Site.new({})
    site.stubs(:code_snippets).returns(code_snippets)

    # Mock item
    item = Nanoc3::Item.new('blah blah blah', {}, '/')

    # Create rep
    rep = Nanoc3::ItemRep.new(item, 'blah')
    rep.raw_path = 'moo.html'

    # Write output file
    File.open(rep.raw_path, 'w') { |io| io.write("o hai how r u") }

    # Check
    compiler = Nanoc3::Compiler.new(site)
    compiler.send(:checksum_store).load
    assert_equal ::Nanoc3::OutdatednessReasons::NotEnoughData, compiler.outdatedness_reason_for(rep)
  end

  def test_outdated_if_compiled_file_doesnt_exist
    # Mock code snippets
    code_snippets = [ mock ]
    code_snippets[0].stubs(:outdated?).returns(false)

    # Mock site
    site = Nanoc3::Site.new({})
    site.stubs(:code_snippets).returns(code_snippets)

    # Mock item
    item = Nanoc3::Item.new('blah blah blah', {}, '/')

    # Create rep
    rep = Nanoc3::ItemRep.new(item, 'blah')
    rep.raw_path = 'moo.html'

    # Mock checksums
    require 'pstore'
    FileUtils.mkdir_p('tmp')
    store = PStore.new('tmp/checksums')
    store.transaction do
      store[:version] = 1
      store[:data] = {
        item.reference => Nanoc3::ChecksumStore.new.new_checksum_for(item)
      }
    end

    # Check
    compiler = Nanoc3::Compiler.new(site)
    compiler.send(:checksum_store).load
    assert !File.file?('moo.html')
    assert_equal ::Nanoc3::OutdatednessReasons::NotWritten, compiler.outdatedness_reason_for(rep)
  end

  def test_outdated_if_item_checksum_is_different
    # Mock code snippets
    code_snippets = [ mock ]
    code_snippets[0].stubs(:outdated?).returns(false)

    # Mock site
    site = Nanoc3::Site.new({})
    site.stubs(:code_snippets).returns(code_snippets)

    # Mock item
    item = Nanoc3::Item.new('blah blah blah', {}, '/')

    # Create rep
    rep = Nanoc3::ItemRep.new(item, 'blah')
    rep.raw_path = 'moo.html'

    # Write output file
    File.open(rep.raw_path, 'w') { |io| io.write("o hai how r u") }

    # Mock checksums
    require 'pstore'
    FileUtils.mkdir_p('tmp')
    store = PStore.new('tmp/checksums')
    store.transaction do
      store[:version] = 1
      store[:data] = {
        item.reference             => 'OMG! DIFFERENT!',
        :config                    => Nanoc3::ChecksumStore.new.new_checksum_for(site.config),
        :rules                     => Nanoc3::ChecksumStore.new.new_checksum_for(site.rules_with_reference)
      }
    end

    # Check
    compiler = Nanoc3::Compiler.new(site)
    compiler.send(:checksum_store).load
    assert_equal ::Nanoc3::OutdatednessReasons::SourceModified, compiler.outdatedness_reason_for(rep)
  end

  def test_not_outdated_if_layouts_outdated
    # Item-layout dependencies, as well as item-item dependencies, are
    # handled elsewhere

    # Mock layouts
    layouts = [ mock ]
    layouts[0].stubs(:outdated?).returns(true)

    # Mock code snippets
    code_snippets = [ Nanoc3::CodeSnippet.new('def moo ; end', 'lib/cow.rb') ]

    # Mock site
    site = Nanoc3::Site.new({})
    site.stubs(:layouts).returns(layouts)
    site.stubs(:code_snippets).returns(code_snippets)

    # Mock item
    item = Nanoc3::Item.new('blah blah blah', {}, '/')
    item.stubs(:site).returns(site)

    # Create rep
    rep = Nanoc3::ItemRep.new(item, 'blah')
    rep.raw_path = 'moo.html'

    # Write output file
    File.open(rep.raw_path, 'w') { |io| io.write("o hai how r u") }

    # Mock checksums
    require 'pstore'
    FileUtils.mkdir_p('tmp')
    store = PStore.new('tmp/checksums')
    store.transaction do
      store[:version] = 1
      store[:data] = {
        item.reference             => Nanoc3::ChecksumStore.new.new_checksum_for(item),
        code_snippets[0].reference => Nanoc3::ChecksumStore.new.new_checksum_for(code_snippets[0]),
        :config                    => Nanoc3::ChecksumStore.new.new_checksum_for(site.config),
        :rules                     => Nanoc3::ChecksumStore.new.new_checksum_for(site.rules_with_reference)
      }
    end

    # Check
    compiler = Nanoc3::Compiler.new(site)
    compiler.send(:checksum_store).load
    assert_equal nil, compiler.outdatedness_reason_for(rep)
  end

  def test_outdated_if_code_snippets_outdated
    # Mock code snippets
    code_snippets = [ Nanoc3::CodeSnippet.new('def moo ; end', 'lib/cow.rb') ]

    # Mock site
    site = Nanoc3::Site.new({})
    site.stubs(:code_snippets).returns(code_snippets)

    # Mock item
    item = Nanoc3::Item.new('blah blah blah', {}, '/')
    item.stubs(:site).returns(site)

    # Create rep
    rep = Nanoc3::ItemRep.new(item, 'blah')
    rep.raw_path = 'moo.html'

    # Write output file
    File.open(rep.raw_path, 'w') { |io| io.write("o hai how r u") }

    # Mock checksums
    require 'pstore'
    FileUtils.mkdir_p('tmp')
    store = PStore.new('tmp/checksums')
    store.transaction do
      store[:version] = 1
      store[:data] = {
        item.reference             => Nanoc3::ChecksumStore.new.new_checksum_for(item),
        code_snippets[0].reference => 'OMG! DIFFERENT!',
        :config                    => Nanoc3::ChecksumStore.new.new_checksum_for(site.config),
        :rules                     => Nanoc3::ChecksumStore.new.new_checksum_for(site.rules_with_reference)
      }
    end

    # Check
    compiler = Nanoc3::Compiler.new(site)
    compiler.send(:checksum_store).load
    assert_equal ::Nanoc3::OutdatednessReasons::CodeSnippetsModified, compiler.outdatedness_reason_for(rep)
  end

  def test_outdated_if_config_outdated
    # Mock code snippets
    code_snippets = [ Nanoc3::CodeSnippet.new('def moo ; end', 'lib/cow.rb') ]

    # Mock site
    site = Nanoc3::Site.new({})
    site.stubs(:code_snippets).returns(code_snippets)

    # Mock item
    item = Nanoc3::Item.new('blah blah blah', {}, '/')

    # Create rep
    rep = Nanoc3::ItemRep.new(item, 'blah')
    rep.raw_path = 'moo.html'

    # Write output file
    File.open(rep.raw_path, 'w') { |io| io.write("o hai how r u") }

    # Mock checksums
    require 'pstore'
    FileUtils.mkdir_p('tmp')
    store = PStore.new('tmp/checksums')
    store.transaction do
      store[:version] = 1
      store[:data] = {
        item.reference             => Nanoc3::ChecksumStore.new.new_checksum_for(item),
        code_snippets[0].reference => Nanoc3::ChecksumStore.new.new_checksum_for(code_snippets[0]),
        :config                    => 'OMG! DIFFERENT'
      }
    end

    # Check
    compiler = Nanoc3::Compiler.new(site)
    compiler.send(:checksum_store).load
    assert_equal ::Nanoc3::OutdatednessReasons::ConfigurationModified, compiler.outdatedness_reason_for(rep)
  end

  def test_outdated_if_rules_outdated
    # Mock code snippets
    code_snippets = [ Nanoc3::CodeSnippet.new('def moo ; end', 'lib/cow.rb') ]

    # Mock site
    site = Nanoc3::Site.new({ :foo => 'bar' })
    site.stubs(:code_snippets).returns(code_snippets)

    # Mock item
    item = Nanoc3::Item.new('blah blah blah', {}, '/')

    # Create rep
    rep = Nanoc3::ItemRep.new(item, 'blah')
    rep.raw_path = 'moo.html'

    # Write output file
    File.open(rep.raw_path, 'w') { |io| io.write("o hai how r u") }

    # Mock checksums
    require 'pstore'
    FileUtils.mkdir_p('tmp')
    store = PStore.new('tmp/checksums')
    store.transaction do
      store[:version] = 1
      store[:data] = {
        item.reference             => Nanoc3::ChecksumStore.new.new_checksum_for(item),
        code_snippets[0].reference => Nanoc3::ChecksumStore.new.new_checksum_for(code_snippets[0]),
        :config                    => Nanoc3::ChecksumStore.new.new_checksum_for(site.config),
        :rules                     => 'OMG! DIFFERENT'
      }
    end

    # Check
    compiler = Nanoc3::Compiler.new(site)
    compiler.send(:checksum_store).load
    assert_equal ::Nanoc3::OutdatednessReasons::RulesModified, compiler.outdatedness_reason_for(rep)
  end

  def test_forget_dependencies_if_outdated
    # Mock items
    items = (0..3).map { |i| mock("item #{i}") }
    reps  = (0..3).map { |i| mock("rep #{i}") }
    (0..4).each { |i| items[i].stubs(:reps).returns([ reps[i] ]) }
    items.each { |i| i.stubs(:type).returns(:item) }
    reps.each  { |i| i.stubs(:type).returns(:item_rep) }

    # Mock dependency tracker
    dependency_tracker = Object.new
    dependency_tracker.expects(:forget_dependencies_for).times(3)
    dependency_tracker.instance_eval do
      @objs = [ items[0], items[1], items[2], items[3] ]
    end
    def dependency_tracker.outdated_due_to_dependencies?(obj)
      case obj
      when @objs[0], @objs[1]
        false
      when @objs[2], @objs[3]
        true
      else
        raise RuntimeError, "The dependency tracker did not expect #{obj.inspect}"
      end
    end

    # Create compiler
    compiler = Nanoc3::Compiler.new(nil)
    compiler.instance_eval do
      @objs = [ reps[0], reps[1], reps[2], reps[3] ]
    end
    def compiler.outdated?(obj)
      case obj
      when @objs[0], @objs[2]
        false
      when @objs[1], @objs[3]
        true
      else
        raise RuntimeError, "The compiler did not expect #{obj.inspect}"
      end
    end
    compiler.stubs(:dependency_tracker).returns(dependency_tracker)
    compiler.send :forget_dependencies_if_outdated, items
  end

end
