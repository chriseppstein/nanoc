module Nanoc2::Filters
  class RDoc < Nanoc2::Filter

    identifiers :rdoc

    def run(content)
      begin
        # new RDoc
        require 'rdoc/markup'
        require 'rdoc/markup/to_html'
        
        ::RDoc::Markup.new.convert(content, ::RDoc::Markup::ToHtml.new)
      rescue LoadError
        # old RDoc
        require 'rdoc/markup/simple_markup'
        require 'rdoc/markup/simple_markup/to_html'

        ::SM::SimpleMarkup.new.convert(content, ::SM::ToHtml.new)
      end
    end

  end
end