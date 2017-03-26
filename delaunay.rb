require 'set'

class Triangle

  attr_reader :vertices
  attr_accessor :target
  attr_reader :hash

  def initialize(a, b, c)
    @vertices = SortedSet[a, b, c]
  end

  def eql?(other)
    @vertices == other.vertices
  end

  def hash
    @vertices.to_a.hash
  end

  def ==(other)
    @vertices == other.vertices
  end

  def adjoin?(other)
    @vertices.intersect?(other.vertices)
  end

  def circumcircle
    p1, p2, p3 = @vertices.to_a
    c = 2.0 * ((p2.x - p1.x) * (p3.y - p1.y) - (p2.y - p1.y) * (p3.x - p1.x))
    x = (
      (p3.y - p1.y) * (p2.x * p2.x - p1.x * p1.x + p2.y * p2.y - p1.y * p1.y) +
      (p1.y - p2.y) * (p3.x * p3.x - p1.x * p1.x + p3.y * p3.y - p1.y * p1.y)
    ) / c
    y = (
      (p1.x - p3.x) * (p2.x * p2.x - p1.x * p1.x + p2.y * p2.y - p1.y * p1.y) +
      (p2.x - p1.x) * (p3.x * p3.x - p1.x * p1.x + p3.y * p3.y - p1.y * p1.y)
    ) / c
    center = vec2(x, y)
    radius = center.dist(p1)

    Circle.new(center, radius)
  end

  def draw
    @vertices.to_a.combination(2) do |p, q|
      target.draw_line(p.x, p.y, q.x, q.y, C_YELLOW)
    end
  end

end

class Circle

  attr_accessor :center, :radius
  attr_accessor :target

  def initialize(center, radius)
    @center = center
    @radius = radius
  end

  def draw
    target.draw_circle_fill(center.x.round, center.y, 2, C_YELLOW)
    target.draw_circle(center.x, center.y, radius, C_WHITE)
  end

end

module Delaunay

  class Triangulation

    attr_reader :triangles

    def initialize(width, height)
      @triangles = Set.new
      center = vec2(width / 2.0, height / 2.0)
      radius = center.dist(vec2(0, 0)) + 1.0
      @external_triangle = Triangle.new(
        vec2(center.x - Math.sqrt(3) * radius, center.y - radius),
        vec2(center.x + Math.sqrt(3) * radius, center.y - radius),
        vec2(center.x, center.y + 2 * radius)
      )
      @triangles << @external_triangle
    end

    def compute(points)
      points.each do |point|
        storage = {}
        store = -> triangle { storage[triangle] = storage.include?(triangle) }
        @triangles.each do |triangle|
          circle = triangle.circumcircle
          if circle.center.dist(point) <= circle.radius
            p1, p2, p3 = triangle.vertices.to_a
            store[Triangle.new(point, p1, p2)]
            store[Triangle.new(point, p2, p3)]
            store[Triangle.new(point, p3, p1)]
            triangles.delete(triangle)
          end
        end
        @triangles.merge(storage.select {|triangle, dup| !dup }.keys)
      end
      @triangles.reject!(&@external_triangle.method(:adjoin?))
    end
  end

end
