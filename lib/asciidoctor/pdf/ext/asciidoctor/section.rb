# frozen_string_literal: true

class Asciidoctor::Section
  def numbered_title opts = {}
    @cached_numbered_title ||= nil
    unless @cached_numbered_title
      if @numbered && !@caption && (slevel = @level) <= (@document.attr 'sectnumlevels', 3).to_i
        @is_numbered = true
        if @document.doctype == 'book'
          case slevel
          when 0
            @cached_numbered_title = %(#{sectnum nil, ':'} #{title})
            signifier = @document.attributes['part-signifier'] || ((@document.attr_unspecified? 'part-signifier') ? 'Part' : '')
            @cached_formal_numbered_title = %(#{signifier} #{@cached_numbered_title}).lstrip
          when 1
            @cached_numbered_title = %(#{sectnum} #{title})
            signifier = @document.attributes['chapter-signifier'] || ((@document.attr_unspecified? 'chapter-signifier') ? 'Chapter' : '')
            @cached_formal_numbered_title = %(#{signifier} #{@cached_numbered_title}).lstrip
          else
            @cached_formal_numbered_title = @cached_numbered_title = %(#{sectnum} #{title})
          end
        else
          @cached_formal_numbered_title = @cached_numbered_title = %(#{sectnum} #{title})
        end
      elsif @level == 0
        @is_numbered = false
        @cached_numbered_title = @cached_formal_numbered_title = title
      else
        @is_numbered = false
        @cached_numbered_title = @cached_formal_numbered_title = captioned_title
      end
    end
    opts[:formal] ? @cached_formal_numbered_title : @cached_numbered_title
  end unless method_defined? :numbered_title

  def first_section_of_part?
    (par = @parent).context == :section && par.sectname == 'part' && self == par.blocks.find {|it| it.context == :section }
  end unless method_defined? :first_section_of_part?
end
