require "isodoc/html_function/mathvariant_to_plain"
require_relative "postprocess_footnotes"
require "metanorma-utils"

module IsoDoc
  module HtmlFunction
    module Html
      def script_cdata(result)
        result.gsub(%r{<script([^>]*)>\s*<!\[CDATA\[}m, "<script\\1>")
          .gsub(%r{\]\]>\s*</script>}, "</script>")
          .gsub(%r{<!\[CDATA\[\s*<script([^>]*)>}m, "<script\\1>")
          .gsub(%r{</script>\s*\]\]>}, "</script>")
      end

      def htmlstylesheet(file)
        return if file.nil?

        file.open if file.is_a?(Tempfile)
        stylesheet = file.read
        xml = Nokogiri::XML("<style/>")
        xml.children.first << Nokogiri::XML::Comment
          .new(xml, "\n#{stylesheet}\n")
        file.close
        file.unlink if file.is_a?(Tempfile)
        xml.root.to_s
      end

      def htmlstyle(docxml)
        return docxml unless @htmlstylesheet

        head = docxml.at("//*[local-name() = 'head']")
        head << htmlstylesheet(@htmlstylesheet)
        s = htmlstylesheet(@htmlstylesheet_override) and head << s
        @bare and
          head << "<style>body {margin-left: 2em; margin-right: 2em;}</style>"
        docxml
      end

      def html_preface(docxml)
        html_cover(docxml) if @htmlcoverpage && !@bare
        html_intro(docxml) if @htmlintropage && !@bare
        docxml.at("//body") << mathjax(@openmathdelim, @closemathdelim)
        docxml.at("//body") << sourcecode_highlighter
        html_main(docxml)
        authority_cleanup(docxml)
        docxml
      end

      def authority_cleanup1(docxml, klass)
        dest = docxml.at("//div[@id = 'boilerplate-#{klass}-destination']")
        auth = docxml.at("//div[@id = 'boilerplate-#{klass}' or "\
                         "@class = 'boilerplate-#{klass}']")
        auth&.xpath(".//h1[not(text())] | .//h2[not(text())]")&.each(&:remove)
        auth&.xpath(".//h1 | .//h2")&.each { |h| h["class"] = "IntroTitle" }
        dest and auth and dest.replace(auth.remove)
      end

      def authority_cleanup(docxml)
        %w(copyright license legal feedback).each do |t|
          authority_cleanup1(docxml, t)
        end
        coverpage_note_cleanup(docxml)
      end

      def coverpage_note_cleanup(docxml)
        if dest = docxml.at("//div[@id = 'coverpage-note-destination']")
          auth = docxml.xpath("//*[@coverpage]")
          if auth.empty? then dest.remove
          else
            auth.each do |x|
              dest << x.remove
            end
          end
        end
        docxml.xpath("//*[@coverpage]").each { |x| x.delete("coverpage") }
      end

      def html_cover(docxml)
        doc = to_xhtml_fragment(File.read(@htmlcoverpage, encoding: "UTF-8"))
        d = docxml.at('//div[@class="title-section"]')
        d.children.first.add_previous_sibling(
          populate_template(doc.to_xml(encoding: "US-ASCII"), :html),
        )
      end

      def html_intro(docxml)
        doc = to_xhtml_fragment(File.read(@htmlintropage, encoding: "UTF-8"))
        d = docxml.at('//div[@class="prefatory-section"]')
        d.children.first.add_previous_sibling(
          populate_template(doc.to_xml(encoding: "US-ASCII"), :html),
        )
      end

      def html_toc_entry(level, header)
        content = header.at("./following-sibling::p"\
                            "[@class = 'variant-title-toc']") || header
        %(<li class="#{level}"><a href="##{header['id']}">\
      #{header_strip(content)}</a></li>)
      end

      def toclevel_classes
        (1..@htmlToClevels).reduce([]) { |m, i| m << "h#{i}" }
      end

      def toclevel
        ret = toclevel_classes.map do |l|
          "#{l}:not(:empty):not(.TermNum):not(.noTOC)"
        end
        <<~HEAD.freeze
          function toclevel() { return "#{ret.join(',')}";}
        HEAD
      end

      # needs to be same output as toclevel
      def html_toc(docxml)
        idx = docxml.at("//div[@id = 'toc']") or return docxml
        toc = "<ul>"
        path = toclevel_classes.map do |l|
          "//main//#{l}#{toc_exclude_class}"
        end
        docxml.xpath(path.join(" | ")).each_with_index do |h, tocidx|
          h["id"] ||= "toc#{tocidx}"
          toc += html_toc_entry(h.name, h)
        end
        idx.children = "#{toc}</ul>"
        docxml
      end

      def toc_exclude_class
        "[not(@class = 'TermNum')][not(@class = 'noTOC')]"\
          "[string-length(normalize-space(.))>0]"
      end

      def inject_script(doc)
        return doc unless @scripts

        scripts = File.read(@scripts, encoding: "UTF-8")
        scripts_override = ""
        @scripts_override and
          scripts_override = File.read(@scripts_override, encoding: "UTF-8")
        a = doc.split(%r{</body>})
        "#{a[0]}#{scripts}#{scripts_override}</body>#{a[1]}"
      end

      def sourcecode_highlighter
        '<script src="https://cdn.rawgit.com/google/code-prettify/master/'\
          'loader/run_prettify.js"></script>'
      end

      MATHJAX_ADDR =
        "https://cdnjs.cloudflare.com/ajax/libs/mathjax/2.7.5/latest.js".freeze
      MATHJAX = <<~"MATHJAX".freeze
        <script type="text/x-mathjax-config">
          MathJax.Hub.Config({
            "HTML-CSS": { preferredFont: "STIX" },
            asciimath2jax: { delimiters: [['OPEN', 'CLOSE']] }
         });
        </script>
        <script src="#{MATHJAX_ADDR}?config=MML_HTMLorMML-full" async="async"></script>
      MATHJAX

      def mathjax(open, close)
        MATHJAX.gsub("OPEN", open).gsub("CLOSE", close)
      end
    end
  end
end
