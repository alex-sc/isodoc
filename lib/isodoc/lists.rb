module IsoDoc
  class Convert
    def ul_parse(node, out)
      out.ul do |ul|
        node.children.each { |n| parse(n, ul) }
      end
    end

    OL_STYLE = {
      arabic: "1",
      roman: "i",
      alphabet: "a",
      roman_upper: "I",
      alphabet_upper: "A",
    }.freeze

    def ol_style(type)
      OL_STYLE[type.to_sym]
    end

    def ol_parse(node, out)
      # attrs = { numeration: node["type"] }
      style = ol_style(node["type"])
      out.ol **attr_code(type: style) do |ol|
        node.children.each { |n| parse(n, ol) }
      end
    end

    def li_parse(node, out)
      out.li do |li|
        node.children.each { |n| parse(n, li) }
      end
    end

    def dl_parse(node, out)
      out.dl do |v|
        node.elements.each_slice(2) do |dt, dd|
          v.dt do |term|
            if dt.elements.empty?
              term.p **attr_code(class: is_note ? "Note" : nil) do |p|
                p << dt.text
              end
            else
              dt.children.each { |n| parse(n, term) }
            end
          end
          v.dd do |listitem|
            dd.children.each { |n| parse(n, listitem) }
          end
        end
      end
    end
  end
end
