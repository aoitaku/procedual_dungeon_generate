require 'dxruby'
require 'chipmunk'
require 'pp'
require_relative 'delaunay'
require_relative 'kruskal'

class CP::Vec2

  include Comparable

  def <=>(other)
    (other.x <=> self.x) != 0 ? other.x <=> self.x : other.y <=> self.y
  end

end

class Room

  attr_reader :body, :shape, :radius
  attr_accessor :target

  def initialize(pos, radius)
    @body = CP::Body.new(Math::PI * radius ** 2, CP::INFINITY)
    @body.p = pos
    @radius = radius
    @shape = CP::Shape::Circle.new(@body, radius)
    @shape.e = 0.0
    @shape.u = 1.0
    @image = {
      default:  Image.new(radius*2, radius*2).circle_fill(radius, radius, radius / 2, C_WHITE),
      sleeping: Image.new(radius*2, radius*2).circle_fill(radius, radius, radius / 2, [128,128,128]),
      active:   Image.new(radius*2, radius*2).circle_fill(radius, radius, radius / 2, [255,255,128])
    }
    @active = false
  end

  def sleeping?
    @body.sleeping?
  end

  def active?
    !!@active
  end

  def activate
    @active = true
  end

  def draw
    @target.draw_ex(
      body.p.x - (@radius - 1),
      body.p.y - (@radius - 1),
      @image[active? ? :active : (sleeping? ? :sleeping : :default)],
      scale_y: 0.75
    )
  end

end

class Path

  attr_reader :a, :b, :angle
  attr_accessor :target

  def initialize(a, b)
    @a = a
    @b = b
    length = a.dist(b)
    @mid = (a + b) / 2
    @angle = Math.atan2(b.y - a.y, b.x - a.x) * 180 / Math::PI
    @image = Image.new(length + 2, 4).box_fill(0, 0, length + 2, 4, [128,128,128])
  end

  def draw
    @target.draw_ex(@a.x, @a.y, @image, center_x: 2, center_y: 2, angle: angle)
  end

end

class Generator

  attr_reader :center, :target, :rooms

  def initialize(width, height)
    @center = vec2(width / 2, height / 2)
    @space = CP::Space.new
    @space.gravity = vec2(0, 0)
    @space.iterations = 100
    @space.sleep_time = 1
    @target = RenderTarget.new(width, height)
    @rooms = []
    @triangles = []
    @segments = []
  end

  def random_point_in_circle(radius)
    t = 2.0 * Math::PI * rand
    u = rand + rand
    r = u > 1 ? 2 - u : u
    vec2(
      (radius * r * Math.cos(t)).floor,
      (radius * r * Math.sin(t)).floor
    )
  end

  def generate_rooms(points, radius)
    points.each do |point|
      room = Room.new(center + point, radius.call)
      room.target = @target
      @space.add_body(room.body)
      @space.add_shape(room.shape)
      @rooms << room
    end
  end

  def reset
    @rooms.each do |room|
      @space.remove_body(room.body)
      @space.remove_shape(room.shape)
    end
    @rooms.clear
    @triangles.clear
    @segments.clear
  end

  def random_generate
    generate_rooms((rand(6)+rand(6)+4).times.map { random_point_in_circle(20) }, -> { 32 })
    generate_rooms((rand(6)+rand(6)+32).times.map { random_point_in_circle(20) }, -> { rand(7)*2 + 17 })
  end

  def refresh
    reset
    random_generate
    GC.start
  end

  def draw
    @segments.each(&:draw)
    Sprite.draw(@rooms)
  end

  def update
    if !@segments.empty?
    elsif triangulated?
      segs = []
      nodes = []
      pairs = @triangles.flat_map {|triangle| triangle.vertices.to_a.combination(2).to_a }.uniq
      pairs.each do |(a, b)|
        nodes << a unless nodes.include?(a)
        nodes << b unless nodes.include?(b)
        segs << Kruskal::Segment.new(nodes.index(a), nodes.index(b), a.dist(b).abs)
      end
      kruskal = Kruskal::Graph.new(nodes.size).search(segs.sort_by(&:length))
      kruskal.mst.each do |seg|
        path = Path.new(nodes[seg.a], nodes[seg.b])
        path.target = @target
        segs.delete(seg)
        @segments << path
      end
      segs.sample(segs.size / 8).each do |seg|
        path = Path.new(nodes[seg.a], nodes[seg.b])
        path.target = @target
        @segments << path
      end
      @rooms.select!(&:active?)
    elsif selected?
      active_rooms = @rooms.select(&:active?)
      triangulation = Delaunay::Triangulation.new(@target.width, @target.height)
      triangulation.compute(active_rooms.map {|room| room.body.p })
      @triangles = triangulation.triangles.each {|triangle| triangle.target = @target }
    elsif done?
      @rooms.select{|room| room.radius >= 32 }.sample(@rooms.size / 6 + rand(@rooms.size / 3)).each(&:activate)
    else
      @space.step(1 / 60.0)
    end
  end

  def done?
    @rooms.all?(&:sleeping?)
  end

  def selected?
    @rooms.any?(&:active?)
  end

  def triangulated?
    !@triangles.empty?
  end

end

generator = Generator.new(800, 800)

Window.width = 800
Window.height = 800

Window.loop do
  if Input.key_push?(K_SPACE)
    generator.refresh
  end
  generator.update
  generator.draw
  Window.draw(
    (Window.width - generator.target.width) / 2,
    (Window.height - generator.target.height) / 2,
    generator.target
  )
end
