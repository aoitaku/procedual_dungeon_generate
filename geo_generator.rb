require 'dxruby'
require 'chipmunk'
require_relative 'delaunay'
require 'pp'

class CP::Vec2

  include Comparable

  def <=>(other)
    (other.x <=> self.x) != 0 ? other.x <=> self.x : other.y <=> self.y
  end

end

class Room

  attr_reader :body, :shape, :x, :y, :width, :height

  def initialize(pos, w, h)
    @body = CP::Body.new(w * h, CP::INFINITY)
    @body.p = pos
    verts = [[-1, -1],[-1, 1],[1, 1],[1, -1]].map {|(x, y)| vec2(x * (w + 3) / 2, y * (h + 3) / 2)}
    @shape = CP::Shape::Poly.new(@body, verts)
    @shape.e = 0.0
    @shape.u = 1.0
    @width = w
    @height = h
    @image = Image.new(w + 1, h + 1).box_fill(0, 0, w + 1, h + 1, [128, 0, 128, 128])
    @disabled_image = Image.new(w + 1, h + 1).box_fill(0, 0, w + 1, h + 1, [128, 255, 255, 255])
    @active_image = Image.new(w + 1, h + 1).box_fill(0, 0, w + 1, h + 1, [128, 255, 128, 0])
    (h / 4).times do |y|
      (w / 4).times do |x|
        @image.box(x * 4, y * 4, x * 4 + 4, y * 4 + 4, [192, 0, 128, 255])
        @disabled_image.box(x * 4, y * 4, x * 4 + 4, y * 4 + 4, [255, 128, 128, 128])
        @active_image.box(x * 4, y * 4, x * 4 + 4, y * 4 + 4, [192, 255, 0, 128])
      end
    end
    @image.box(0, 0, w + 1, h + 1, [255, 255, 255])
    @disabled_image.box(0, 0, w + 1, h + 1, [255, 255, 255])
    @active_image.box(0, 0, w + 1, h + 1, [255, 255, 255])
    @active = false
  end

  def x
    ((body.p.x - width / 2 + 4 - 1) / 4).floor * 4
  end

  def y
    ((body.p.y - height / 2 + 4 - 1) / 4).floor * 4
  end

  def mid_x
    x + width / 2
  end

  def mid_y
    y + height / 2
  end

  def target=(target)
    @target = target
  end

  def draw
    @target.draw(
      x,
      y,
      active? ? @active_image : (sleeping? ? @disabled_image : @image)
    )
  end

  def active?
    @active
  end

  def activate
    @active = true
  end

  def deactivate
    @active = false
  end

  def sleeping?
    @body.sleeping?
  end

end

class GeoGenerator

  attr_reader :center, :target, :rooms

  def initialize(width, height)
    @center = vec2(width / 2, height / 2)
    @space = CP::Space.new
    @space.gravity = vec2(0, 0)
    @space.iterations = 100
    @space.sleep_time = 1
    @target = RenderTarget.new(width, height)
    @rooms = []
    @triangles = nil
  end

  def random_point_in_circle(radius)
    t = 2 * Math::PI * rand
    u = rand + rand
    r = u > 1 ? 2 - u : r = u
    [
      ((radius * r * Math.cos(t) + 4 - 1) / 4).floor * 4,
      ((radius * r * Math.sin(t) + 4 - 1) / 4).floor * 4
    ]
  end

  def random_point_in_ellipse(width, height)
    t = 2 * Math::PI * rand
    u = rand + rand
    r = u > 1 ? 2 - u : r = u
    [
      ((width * r * Math.cos(t) + 4 - 1) / 4).floor * 4,
      ((height * r * Math.sin(t) + 4 - 1) / 4).floor * 4
    ]
  end

  def generate_rooms(points)
    points.each do |point|
      pos = center + vec2(*point)
      w = ((rand(10) + 2) + (rand(7) + 1)) * 4
      h = ((rand(7) + 2) + (rand(5) + 1)) * 4
      room = Room.new(pos, w, h)
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
    @triangles = nil
    @minimum_spanning = nil
  end

  def draw
    Sprite.draw(@rooms)
    if triangulated?
      @triangles.each {|triangle| triangle.draw }
    end
  end

  def done?
    @rooms.all?(&:sleeping?)
  end

  def selected?
    @rooms.any?(&:active?)
  end

  def triangulated?
    @triangles
  end

  def minimumized?
    @minimum_spanning
  end

  def update
    if minimumized?
    elsif triangulated?
    elsif selected?
      active_rooms = @rooms.select(&:active?)
      verts = active_rooms.map {|room| vec2(room.mid_x, room.mid_y) }
      triangulation = Delaunay::Triangulation.new(@target.width, @target.height)
      triangulation.compute(verts)
      @triangles = triangulation.triangles.each {|triangle| triangle.target = @target }
    elsif done?
      @rooms.select {|room| room.width > 32 && room.height > 32 && room.width * room.height > 1280 }.tap do |selected|
        break refresh if selected.size < 3
        num = rand(selected.size / 4) + rand(selected.size / 4) + rand(selected.size / 4) + [selected.size / 4, 4].max
        selected.sort_by{|room| room.width * room.height }.last(num).each(&:activate)
      end
    else
      @space.step(1 / 60.0)
    end
  end

  def random_generate
    generate_rooms((rand(6)+rand(6)+22).times.map { random_point_in_ellipse(64, 4) })
  end

  def refresh
    reset
    random_generate
  end

end

generator = GeoGenerator.new(800, 800)

Window.width = 800
Window.height = 800

Window.mag_filter = TEXF_POINT
Window.loop do
  if Input.key_push?(K_SPACE)
    generator.refresh
  end
  generator.update
  generator.draw
  Window.draw_ex(
    (Window.width - generator.target.width) / 2,
    (Window.height - generator.target.height) / 2,
    generator.target
  )
end
