require "uuidtools"

module IsoDoc
  class Convert
    def in_footnote
      @in_footnote
    end

    def in_comment
      @in_comment
    end

    def footnotes(div)
      return if @footnotes.empty?
      @footnotes.each { |fn| div.parent << fn }
    end

    def make_table_footnote_link(out, fnid, fnref)
      attrs = { href: "##{fnid}", class: "TableFootnoteRef" }
      out.a **attrs do |a|
        a << fnref
      end
    end

    def make_table_footnote_target(out, fnid, fnref)
      attrs = { id: fnid, class: "TableFootnoteRef" }
      out.a **attrs do |a|
        a << fnref
        insert_tab(a, 1)
      end
    end

    def make_table_footnote_text(node, fnid, fnref)
      attrs = { id: "ftn#{fnid}" }
      noko do |xml|
        xml.div **attr_code(attrs) do |div|
          make_table_footnote_target(div, fnid, fnref)
          node.children.each { |n| parse(n, div) }
        end
      end.join("\n")
    end

    def make_generic_footnote_text(node, fnid, fn_ref)
      noko do |xml|
        xml.aside **{ id: "ftn#{fnid}" } do |div|
          node.children.each { |n| parse(n, div) }
        end
      end.join("\n")
    end

    def get_table_ancestor_id(node)
      table = node.ancestors("table") || node.ancestors("figure")
      return UUIDTools::UUID.random_create.to_s if table.empty?
      table.last["id"]
    end

    def table_footnote_parse(node, out)
      fn = node["reference"]
      tid = get_table_ancestor_id(node)
      make_table_footnote_link(out, tid + fn, fn)
      # do not output footnote text if we have already seen it for this table
      return if @seen_footnote.include?(tid + fn)
      @in_footnote = true
      out.aside { |a| a << make_table_footnote_text(node, tid + fn, fn) }
      @in_footnote = false
      @seen_footnote << (tid + fn)
    end

    def footnote_parse(node, out)
      return table_footnote_parse(node, out) if @in_table || @in_figure
      fn = node["reference"]
      out.a **{"epub:type": "footnote", href: "#ftn#{fn}" } do |a|
        a.sup { |sup| sup << fn }
      end
      return if @seen_footnote.include?(fn)
      @in_footnote = true
      @footnotes << make_generic_footnote_text(node, fn, fn)
      @in_footnote = false
      @seen_footnote << fn
    end

    def comments(div)
      return if @comments.empty?
      div.div **{ style: "mso-element:comment-list" } do |div1|
        @comments.each { |fn| div1.parent << fn }
      end
    end

    def review_note_parse(node, out)
      fn = @comments.length + 1
      make_comment_link(out, fn, node)
      @in_comment = true
      @comments << make_comment_text(node, fn)
      @in_comment = false
    end

    # add in from and to links to move the comment into place
    def make_comment_link(out, fn, node)
      out.span(**{ style: "MsoCommentReference", target: fn,
                   class: "commentLink", from: node["from"],
                   to: node["to"] }
              ) do |s1|
                s1.span **{ lang: "EN-GB", style: "font-size:9.0pt" } do |s2|
                  s2.a **{ style: "mso-comment-reference:SMC_#{fn};"\
                           "mso-comment-date:#{node['date']}" }
                  s2.span **{ style: "mso-special-character:comment",
                              target: fn } # do |s|
                end
              end
    end

    def make_comment_target(out)
      out.span **{ style: "MsoCommentReference" } do |s1|
        s1.span **{ lang: "EN-GB", style: "font-size:9.0pt"} do |s2|
          s2.span **{ style: "mso-special-character:comment" } # do |s|
          # s << "&nbsp;"
          # end
        end
      end
    end

    def make_comment_text(node, fn)
      noko do |xml|
        xml.div **{ style: "mso-element:comment", id: fn } do |div|
          div.span **{ style: %{mso-comment-author:"#{node["reviewer"]}"} }
          make_comment_target(div)
          node.children.each { |n| parse(n, div) }
        end
      end.join("\n")
    end

    def comment_cleanup(docxml)
      move_comment_link_to_from(docxml)
      reorder_comments_by_comment_link(docxml)
      embed_comment_in_comment_list(docxml)
    end

    COMMENT_IN_COMMENT_LIST =
      '//div[@style="mso-element:comment-list"]//'\
      'span[@style="MsoCommentReference"]'.freeze

    def embed_comment_in_comment_list(docxml)
      docxml.xpath(COMMENT_IN_COMMENT_LIST).each do |x|
        n = x.next_element
        n&.children&.first&.add_previous_sibling(x.remove)
      end
      docxml
    end

    def move_comment_link_to_from1(x, fromlink, docxml)
      x.remove
      link = x.at(".//a")
      fromlink.replace(x)
      link.children = fromlink
    end

    def comment_attributes(docxml, x)
      fromlink = docxml.at("//*[@id='#{x['from']}']")
      return(nil) if fromlink.nil?
      tolink = docxml.at("//*[@id='#{x['to']}']") || fromlink
      target = docxml.at("//*[@id='#{x['target']}']")
      { from: fromlink, to: tolink, target: target }
    end

    def wrap_comment_cont(from, target)
      s = from.replace("<span style='mso-comment-continuation:#{target}'>")
      s.first.children = from
    end

    def skip_comment_wrap(from)
      from["style"] != "mso-special-character:comment"
    end

    def insert_comment_cont(from, to, target, docxml)
      # includes_to = from.at(".//*[@id='#{to}']")
      while !from.nil? && from["id"] != to
        following = from.xpath("./following::*")
        (from = following.shift) && incl_to = from.at(".//*[@id='#{to}']")
        while !incl_to.nil? && !from.nil? && skip_comment_wrap(from)
          (from = following.shift) && incl_to = from.at(".//*[@id='#{to}']")
        end
        wrap_comment_cont(from, target) if !from.nil?
      end
    end

    def move_comment_link_to_from(docxml)
      docxml.xpath('//span[@style="MsoCommentReference"][@from]').each do |x|
        attrs = comment_attributes(docxml, x) || next
        move_comment_link_to_from1(x, attrs[:from], docxml)
        insert_comment_cont(attrs[:from], x["to"], x["target"], docxml)
      end
    end

    def get_comments_from_text(docxml, link_order)
      comments = []
      docxml.xpath("//div[@style='mso-element:comment']").each do |c|
        next unless c["id"] && !link_order[c["id"]].nil?
        comments << { text: c.remove.to_s, id: c["id"] }
      end
      comments.sort! { |a, b| link_order[a[:id]] <=> link_order[b[:id]] }
      comments
    end

    COMMENT_TARGET_XREFS =
      "//span[@style='mso-special-character:comment']/@target".freeze

    def reorder_comments_by_comment_link(docxml)
      link_order = {}
      docxml.xpath(COMMENT_TARGET_XREFS).each_with_index do |target, i|
        link_order[target.value] = i
      end
      comments = get_comments_from_text(docxml, link_order)
      list = docxml.at("//*[@style='mso-element:comment-list']") || return
      list.children = comments.map { |c| c[:text] }.join("\n")
    end
  end
end
