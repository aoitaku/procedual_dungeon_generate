require 'set'

module Kruskal

  class Segment

    attr_reader :a, :b, :length

    def initialize(a, b, length)
      @a = a
      @b = b
      @length = length
    end

    def inspect
      "#{@a} -> #{@b}: #{@length}"
    end

  end

  class Graph

    attr_reader :group, :group_set, :mst

    def initialize(num_of_nodes)
      @num_of_nodes = num_of_nodes
      @group = [*0...num_of_nodes]
      @group_set = (0...num_of_nodes).collect {|x| Set[x] }
      @mst = []
    end

    def merge(a, b)
      group_set_a = group_set[group[a]]
      group_set_b = group_set[group[b]]
      g, group_set_c = if group_set_a.length <= group_set_b.length
        group_set_a.merge(group_set_b)
        [group[a], group_set_b]
      else
        group_set_b.merge(group_set_a)
        [group[b], group_set_a]
      end
      group_set_c.each do |x|
        group[x] = g
      end
      group_set_c.clear
    end

    def search(segments)
      segments.each do |segment|
        if group[segment.a] != group[segment.b]
          merge(segment.a, segment.b)
          mst << segment
        end
      end
      self
    end

  end

end
