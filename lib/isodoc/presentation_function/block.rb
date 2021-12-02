require_relative "./image"

module IsoDoc
  class PresentationXMLConvert < ::IsoDoc::Convert
    def lower2cap(text)
      return text if /^[[:upper:]][[:upper:]]/.match?(text)

      text.capitalize
    end

    def prefix_name(node, delim, number, elem)
      return if number.nil? || number.empty?

      unless name = node.at(ns("./#{elem}"))
        (node.children.empty? and node.add_child("<#{elem}></#{elem}>")) or
          node.children.first.previous = "<#{elem}></#{elem}>"
        name = node.children.first
      end
      if name.children.empty? then name.add_child(number)
      else (name.children.first.previous = "#{number}#{delim}")
      end
    end

    def sourcecode(docxml)
      docxml.xpath(ns("//sourcecode")).each do |f|
        sourcecode1(f)
      end
    end

    def sourcecode1(elem)
      return if labelled_ancestor(elem)

      lbl = @xrefs.anchor(elem["id"], :label, false) or return
      prefix_name(elem, "&nbsp;&mdash; ",
                  l10n("#{lower2cap @i18n.figure} #{lbl}"), "name")
    end

    def formula(docxml)
      docxml.xpath(ns("//formula")).each do |f|
        formula1(f)
      end
    end

    # introduce name element
    def formula1(elem)
      lbl = @xrefs.anchor(elem["id"], :label, false)
      prefix_name(elem, "", lbl, "name")
    end

    def example(docxml)
      docxml.xpath(ns("//example")).each do |f|
        example1(f)
      end
    end

    def example1(elem)
      n = @xrefs.get[elem["id"]]
      lbl = if n.nil? || n[:label].nil? || n[:label].empty?
              @i18n.example
            else
              l10n("#{@i18n.example} #{n[:label]}")
            end
      prefix_name(elem, "&nbsp;&mdash; ", lbl, "name")
    end

    def note(docxml)
      docxml.xpath(ns("//note")).each do |f|
        note1(f)
      end
    end

    # introduce name element
    def note1(elem)
      return if elem.parent.name == "bibitem"

      n = @xrefs.get[elem["id"]]
      lbl = if n.nil? || n[:label].nil? || n[:label].empty?
              @i18n.note
            else
              l10n("#{@i18n.note} #{n[:label]}")
            end
      prefix_name(elem, "", lbl, "name")
    end

    def recommendation(docxml)
      docxml.xpath(ns("//recommendation")).each do |f|
        recommendation1(f, lower2cap(@i18n.recommendation))
      end
    end

    def requirement(docxml)
      docxml.xpath(ns("//requirement")).each do |f|
        recommendation1(f, lower2cap(@i18n.requirement))
      end
    end

    def permission(docxml)
      docxml.xpath(ns("//permission")).each do |f|
        recommendation1(f, lower2cap(@i18n.permission))
      end
    end

    # introduce name element
    def recommendation1(elem, type)
      n = @xrefs.anchor(elem["id"], :label, false)
      lbl = (n.nil? ? type : l10n("#{type} #{n}"))
      prefix_name(elem, "", lbl, "name")
    end

    def table(docxml)
      docxml.xpath(ns("//table")).each do |f|
        table1(f)
      end
    end

    def table1(elem)
      return if labelled_ancestor(elem)
      return if elem["unnumbered"] && !elem.at(ns("./name"))

      n = @xrefs.anchor(elem["id"], :label, false)
      prefix_name(elem, "&nbsp;&mdash; ", l10n("#{lower2cap @i18n.table} #{n}"),
                  "name")
    end

    # we use this to eliminate the semantic amend blocks from rendering
    def amend(docxml)
      docxml.xpath(ns("//amend")).each do |f|
        amend1(f)
      end
    end

    def amend1(elem)
      elem.xpath(ns("./autonumber")).each(&:remove)
      elem.xpath(ns("./newcontent")).each { |a| a.name = "quote" }
      elem.xpath(ns("./description")).each { |a| a.replace(a.children) }
      elem.replace(elem.children)
    end
  end
end
