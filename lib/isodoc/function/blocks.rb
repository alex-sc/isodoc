require_relative "blocks_example_note"

module IsoDoc
  module Function
    module Blocks
      def figure_name_parse(_node, div, name)
        name.nil? and return
        div.p class: "FigureTitle", style: "text-align:center;" do |p|
          name.children.each { |n| parse(n, p) }
        end
      end

      def figure_attrs(node)
        attr_code(id: node["id"], class: "figure", style: keep_style(node))
      end

      def figure_parse(node, out)
        node["class"] == "pseudocode" || node["type"] == "pseudocode" and
          return pseudocode_parse(node, out)
        @in_figure = true
        figure_parse1(node, out)
        @in_figure = false
      end

      def figure_parse1(node, out)
        out.div **figure_attrs(node) do |div|
          node.children.each do |n|
            parse(n, div) unless n.name == "fmt-name"
          end
          figure_name_parse(node, div, node.at(ns("./fmt-name")))
        end
      end

      def pseudocode_attrs(node)
        attr_code(id: node["id"], class: "pseudocode", style: keep_style(node))
      end

      def pseudocode_parse(node, out)
        @in_figure = true
        name = node.at(ns("./fmt-name"))
        out.div **pseudocode_attrs(node) do |div|
          node.children.each { |n| parse(n, div) unless n.name == "fmt-name" }
          sourcecode_name_parse(node, div, name)
        end
        @in_figure = false
      end

      def sourcecode_name_parse(_node, div, name)
        name.nil? and return
        div.p class: "SourceTitle", style: "text-align:center;" do |p|
          name.children.each { |n| parse(n, p) }
        end
      end

      def sourcecode_attrs(node)
        attr_code(id: node["id"], class: "Sourcecode", style: keep_style(node))
      end

      def sourcecode_parse(node, out)
        name = node.at(ns("./fmt-name"))
        out.p **sourcecode_attrs(node) do |div|
          sourcecode_parse1(node, div)
        end
        annotation_parse(node, out)
        sourcecode_name_parse(node, out, name)
      end

      def sourcecode_parse1(node, div)
        @sourcecode = "pre"
        node.at(ns(".//table[@class = 'rouge-line-table']")) ||
          node.at("./ancestor::xmlns:table[@class = 'rouge-line-table']") and
          @sourcecode = "table"
        node.children.each do |n|
          %w(fmt-name dl).include?(n.name) and next
          parse(n, div)
        end
        @sourcecode = false
      end

      def pre_parse(node, out)
        out.pre node.text, **attr_code(id: node["id"])
      end

      def annotation_parse(node, out)
        dl = node.at(ns("./dl")) or return
        @sourcecode = false
        out.div class: "annotation" do |div|
          parse(dl, div)
        end
      end

      def formula_parse1(node, out)
        out.div **attr_code(class: "formula") do |div|
          div.p do |_p|
            parse(node.at(ns("./stem")), div)
            if lbl = node&.at(ns("./fmt-name"))&.text
              insert_tab(div, 1)
              div << lbl
            end
          end
        end
      end

      def formula_attrs(node)
        attr_code(id: node["id"], style: keep_style(node))
      end

      def formula_parse(node, out)
        out.div **formula_attrs(node) do |div|
          formula_parse1(node, div)
          node.children.each do |n|
            %w(stem fmt-name).include? n.name and next
            parse(n, div)
          end
        end
      end

      def para_class(node)
        classtype = nil
        classtype = "MsoCommentText" if in_comment
        node["type"] == "floating-title" and
          classtype = "h#{node['depth']}"
        classtype ||= node["class"]
        classtype
      end

      def para_attrs(node)
        attrs = { class: para_class(node), id: node["id"] }
        s = node["align"].nil? ? "" : "text-align:#{node['align']};"
        s = "#{s}#{keep_style(node)}"
        attrs[:style] = s unless s.empty?
        attrs
      end

      def para_parse(node, out)
        out.p **attr_code(para_attrs(node)) do |p|
          node.children.each { |n| parse(n, p) }
        end
      end

      def attribution_parse(node, out)
        out.div class: "QuoteAttribution" do |d|
          node.children.each { |n| parse(n, d) }
        end
      end

      def quote_parse(node, out)
        attrs = para_attrs(node)
        attrs[:class] = "Quote"
        out.div **attr_code(attrs) do |p|
          node.children.each { |n| parse(n, p) }
        end
      end

      def passthrough_parse(node, out)
        node["formats"] &&
          !(node["formats"].split(" ").include? @format.to_s) and return
        out.passthrough node.text
      end

      def svg_parse(node, out)
        out.parent.add_child(node)
      end

      def toc_parse(node, out)
        out.div class: "toc" do |div|
          node.children.each { |n| parse(n, div) }
        end
      end

      def source_parse(node, out)
        out.div class: "BlockSource" do |d|
          d.p do |p|
            node.children.each { |n| parse(n, p) }
          end
        end
      end

      def cross_align_parse(node, out)
        out.table do |t|
          t.tbody do |b|
            node.xpath(ns("./align-cell")).each do |c|
              b.td do |td|
                c.children.each { |n| parse(n, td) }
              end
            end
          end
        end
      end

      def columnbreak_parse(node, out); end
    end
  end
end
