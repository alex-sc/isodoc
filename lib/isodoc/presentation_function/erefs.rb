require "metanorma-utils"

module IsoDoc
  class PresentationXMLConvert < ::IsoDoc::Convert
    def expand_citeas(text)
      text.nil? and return text
      HTMLEntities.new.decode(text.gsub(/&amp;#x/, "&#"))
    end

    def erefstack1(elem)
      locs = elem.xpath(ns("./eref")).map do |e|
        [e["connective"], e.to_xml]
      end.flatten
      ret = resolve_eref_connectives(locs)
      elem.replace(ret[1])
    end

    def eref_localities(refs, target, node)
      if can_conflate_eref_rendering?(refs)
        l10n(", #{eref_localities_conflated(refs, target, node)}")
      else
        ret = resolve_eref_connectives(eref_locality_stacks(refs, target, node))
        l10n(ret.join)
      end
    end

    def eref_localities_conflated(refs, target, node)
      droploc = node["droploc"]
      node["droploc"] = true
      ret = resolve_eref_connectives(eref_locality_stacks(refs, target,
                                                          node))
      node.delete("droploc") unless droploc
      eref_localities1(target,
                       refs.first.at(ns("./locality/@type")).text,
                       l10n(ret[1..-1].join), nil, node, @lang)
    end

    def can_conflate_eref_rendering?(refs)
      (refs.size > 1 &&
        refs.all? { |r| r.name == "localityStack" } &&
        refs.all? { |r| r.xpath(ns("./locality")).size == 1 }) or return false

      first = refs.first.at(ns("./locality/@type")).text
      refs.all? do |r|
        r.at(ns("./locality/@type")).text == first
      end
    end

    def resolve_eref_connectives(locs)
      locs = resolve_comma_connectives(locs)
      locs = resolve_to_connectives(locs)
      return locs if locs.size < 3

      locs = locs.each_slice(2).with_object([]) do |a, m|
        m << { conn: a[0], label: a[1] }
      end
      [", ", combine_conn(locs)]
    end

    def resolve_comma_connectives(locs)
      locs1 = []
      add = ""
      until locs.empty?
        if [", ", " "].include?(locs[1])
          add += locs[0..2].join
          locs.shift(3)
        else
          locs1 << add unless add.empty?
          add = ""
          locs1 << locs.shift
        end
      end
      locs1 << add unless add.empty?
      locs1
    end

    def resolve_to_connectives(locs)
      locs1 = []
      until locs.empty?
        if locs[1] == "to"
          locs1 << @i18n.chain_to.sub(/%1/, locs[0]).sub(/%2/, locs[2])
          locs.shift(3)
        else locs1 << locs.shift
        end
      end
      locs1
    end

    def eref_locality_stacks(refs, target, node)
      ret = refs.each_with_index.with_object([]) do |(r, i), m|
        added = eref_locality_stack(r, i, target, node)
        added.empty? and next
        added.each { |a| m << a }
        next if i == refs.size - 1

        m << eref_locality_delimiter(r)
      end
      ret.empty? ? ret : [", "] + ret
    end

    def eref_locality_delimiter(ref)
      if ref&.next_element&.name == "localityStack"
        ref.next_element["connective"]
      else locality_delimiter(ref)
      end
    end

    def eref_locality_stack(ref, idx, target, node)
      ret = []
      if ref.name == "localityStack"
        ref.elements.each_with_index do |rr, j|
          l = eref_localities0(rr, j, target, node) or next

          ret << l
          ret << locality_delimiter(rr) unless j == ref.elements.size - 1
        end
      else
        l = eref_localities0(ref, idx, target, node) and ret << l
      end
      ret[-1] == ", " and ret.pop
      ret
    end

    def locality_delimiter(_loc)
      ", "
    end

    def eref_localities0(ref, _idx, target, node)
      if ref["type"] == "whole" then @i18n.wholeoftext
      else
        eref_localities1(target, ref["type"],
                         ref&.at(ns("./referenceFrom"))&.text,
                         ref&.at(ns("./referenceTo"))&.text, node, @lang)
      end
    end

    def eref_localities1_zh(_target, type, from, upto, node)
      ret = "第#{from}" if from
      ret += "&#x2013;#{upto}" if upto
      loc = eref_locality_populate(type, node)
      ret += " #{loc}" unless node["droploc"] == "true"
      ret
    end

    def eref_localities1(target, type, from, upto, node, lang = "en")
      return nil if type == "anchor"

      lang == "zh" and
        return l10n(eref_localities1_zh(target, type, from, upto, node))
      ret = eref_locality_populate(type, node)
      ret += " #{from}" if from
      ret += "&#x2013;#{upto}" if upto
      l10n(ret)
    end

    def eref_locality_populate(type, node)
      return "" if node["droploc"] == "true"

      loc = type.sub(/^locality:/, "")
      ret = @i18n.locality[loc] || loc
      ret = case node["case"]
            when "lowercase" then loc.downcase
            else Metanorma::Utils.strict_capitalize_first(ret)
            end
      " #{ret}"
    end
  end
end
