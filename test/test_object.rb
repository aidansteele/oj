#!/usr/bin/env ruby
# encoding: UTF-8

$: << File.dirname(__FILE__)

require 'helper'

class ObjectJuice < Minitest::Test
  class Jeez
    attr_accessor :x, :y

    def initialize(x, y)
      @x = x
      @y = y
    end

    def eql?(o)
      self.class == o.class && @x == o.x && @y == o.y
    end
    alias == eql?

    def to_json(*a)
      %{{"json_class":"#{self.class}","x":#{@x},"y":#{@y}}}
    end

    def self.json_create(h)
      self.new(h['x'], h['y'])
    end
  end # Jeez

  module One
    module Two
      module Three
        class Deep

          def initialize()
          end

          def eql?(o)
            self.class == o.class
          end
          alias == eql?

          def to_hash()
            {'json_class' => "#{self.class.name}"}
          end

          def to_json(*a)
            %{{"json_class":"#{self.class.name}"}}
          end

          def self.json_create(h)
            self.new()
          end
        end # Deep
      end # Three
    end # Two

    class Stuck2 < Struct.new(:a, :b)
    end

  end # One

  class Stuck < Struct.new(:a, :b)
  end

  class Strung < String

    def initialize(str, safe)
      super(str)
      @safe = safe
    end

    def safe?()
      @safe
    end

    def self.create(str, safe)
      new(str, safe)
    end

    def eql?(o)
      super && self.class == o.class && @safe == o.safe?
    end
    alias == eql?

    def inspect()
      return super + '(' + @safe + ')'
    end
  end

  class AutoStrung < String
    attr_accessor :safe

    def initialize(str, safe)
      super(str)
      @safe = safe
    end

    def eql?(o)
      self.class == o.class && super(o) && @safe == o.safe
    end
    alias == eql?
  end

  class AutoArray < Array
    attr_accessor :safe

    def initialize(a, safe)
      super(a)
      @safe = safe
    end

    def eql?(o)
      self.class == o.class && super(o) && @safe == o.safe
    end
    alias == eql?
  end

  class AutoHash < Hash
    attr_accessor :safe

    def initialize(h, safe)
      super(h)
      @safe = safe
    end

    def eql?(o)
      self.class == o.class && super(o) && @safe == o.safe
    end
    alias == eql?
  end

  def setup
    @default_options = Oj.default_options
  end

  def teardown
    Oj.default_options = @default_options
  end

  def test_nil
    dump_and_load(nil, false)
  end

  def test_true
    dump_and_load(true, false)
  end

  def test_false
    dump_and_load(false, false)
  end

  def test_fixnum
    dump_and_load(0, false)
    dump_and_load(12345, false)
    dump_and_load(-54321, false)
    dump_and_load(1, false)
  end

  def test_float
    dump_and_load(0.0, false)
    dump_and_load(12345.6789, false)
    dump_and_load(70.35, false)
    dump_and_load(-54321.012, false)
    dump_and_load(1.7775, false)
    dump_and_load(2.5024, false)
    dump_and_load(2.48e16, false)
    dump_and_load(2.48e100 * 1.0e10, false)
    dump_and_load(-2.48e100 * 1.0e10, false)
  end

  def test_string
    dump_and_load('', false)
    dump_and_load('abc', false)
    dump_and_load("abc\ndef", false)
    dump_and_load("a\u0041", false)
  end

  def test_symbol
    dump_and_load(:abc, false)
    dump_and_load(":abc", false)
  end

  def test_encode
    opts = Oj.default_options
    Oj.default_options = { :ascii_only => false }
    unless 'jruby' == $ruby
      dump_and_load("ぴーたー", false)
    end
    Oj.default_options = { :ascii_only => true }
    json = Oj.dump("ぴーたー")
    assert_equal(%{"\\u3074\\u30fc\\u305f\\u30fc"}, json)
    unless 'jruby' == $ruby
      dump_and_load("ぴーたー", false)
    end
    Oj.default_options = opts
  end

  def test_unicode
    # hits the 3 normal ranges and one extended surrogate pair
    json = %{"\\u019f\\u05e9\\u3074\\ud834\\udd1e"}
    obj = Oj.load(json)
    json2 = Oj.dump(obj, :ascii_only => true)
    assert_equal(json, json2)
  end

  def test_array
    dump_and_load([], false)
    dump_and_load([true, false], false)
    dump_and_load(['a', 1, nil], false)
    dump_and_load([[nil]], false)
    dump_and_load([[nil], 58], false)
  end

  def test_array_deep
    dump_and_load([1,[2,[3,[4,[5,[6,[7,[8,[9,[10,[11,[12,[13,[14,[15,[16,[17,[18,[19,[20]]]]]]]]]]]]]]]]]]]], false)
  end

  # Hash
  def test_hash
    dump_and_load({}, false)
    dump_and_load({ 'true' => true, 'false' => false}, false)
    dump_and_load({ 'true' => true, 'array' => [], 'hash' => { }}, false)
  end

  def test_hash_deep
    dump_and_load({'1' => {
                      '2' => {
                        '3' => {
                          '4' => {
                            '5' => {
                              '6' => {
                                '7' => {
                                  '8' => {
                                    '9' => {
                                      '10' => {
                                        '11' => {
                                          '12' => {
                                            '13' => {
                                              '14' => {
                                                '15' => {
                                                  '16' => {
                                                    '17' => {
                                                      '18' => {
                                                        '19' => {
                                                          '20' => {}}}}}}}}}}}}}}}}}}}}}, false)
  end

  def test_hash_escaped_key
    json = %{{"a\nb":true,"c\td":false}}
    obj = Oj.object_load(json)
    assert_equal({"a\nb" => true, "c\td" => false}, obj)
  end

  def test_bignum_object
    dump_and_load(7 ** 55, false)
  end

  # BigDecimal
  def test_bigdecimal_object
    dump_and_load(BigDecimal.new('3.14159265358979323846'), false)
  end

  def test_bigdecimal_load
    orig = BigDecimal.new('80.51')
    json = Oj.dump(orig, :mode => :object, :bigdecimal_as_decimal => true)
    bg = Oj.load(json, :mode => :object, :bigdecimal_load => true)
    assert_equal(BigDecimal, bg.class)
    assert_equal(orig, bg)
  end

  # Stream IO
  def test_io_string
    json = %{{
  "x":true,
  "y":58,
  "z": [1,2,3]
}
}
    input = StringIO.new(json)
    obj = Oj.object_load(input)
    assert_equal({ 'x' => true, 'y' => 58, 'z' => [1, 2, 3]}, obj)
  end

  def test_io_file
    filename = File.join(File.dirname(__FILE__), 'open_file_test.json')
    File.open(filename, 'w') { |f| f.write(%{{
  "x":true,
  "y":58,
  "z": [1,2,3]
}
}) }
    f = File.new(filename)
    obj = Oj.object_load(f)
    f.close()
    assert_equal({ 'x' => true, 'y' => 58, 'z' => [1, 2, 3]}, obj)
  end

  # symbol_keys option
  def test_symbol_keys
    json = %{{
  "x":true,
  "y":58,
  "z": [1,2,3]
}
}
    obj = Oj.object_load(json, :symbol_keys => true)
    assert_equal({ :x => true, :y => 58, :z => [1, 2, 3]}, obj)
  end

  # comments
  def test_comment_slash
    json = %{{
  "x":true,//three
  "y":58,
  "z": [1,2,
3 // six
]}
}
    obj = Oj.object_load(json)
    assert_equal({ 'x' => true, 'y' => 58, 'z' => [1, 2, 3]}, obj)
  end

  def test_comment_c
    json = %{{
  "x"/*one*/:/*two*/true,
  "y":58,
  "z": [1,2,3]}
}
    obj = Oj.object_load(json)
    assert_equal({ 'x' => true, 'y' => 58, 'z' => [1, 2, 3]}, obj)
  end

  def test_comment
    json = %{{
  "x"/*one*/:/*two*/true,//three
  "y":58/*four*/,
  "z": [1,2/*five*/,
3 // six
]
}
}
    obj = Oj.object_load(json)
    assert_equal({ 'x' => true, 'y' => 58, 'z' => [1, 2, 3]}, obj)
  end

  def test_json_module_object
    obj = One::Two::Three::Deep.new()
    dump_and_load(obj, false)
  end

  def test_time
    t = Time.now()
    dump_and_load(t, false)
  end

  def test_xml_time
    Oj.default_options = { :mode => :object, :time_format => :xmlschema }
    t = Time.now()
    dump_and_load(t, false)
  end

  def test_utc_time
    Oj.default_options = { :mode => :object, :time_format => :xmlschema }
    t = Time.now().utc
    dump_and_load(t, false)
  end

  def test_ruby_time
    Oj.default_options = { :mode => :object, :time_format => :ruby }
    t = Time.now()
    dump_and_load(t, false)
  end

  def test_time_early
    t = Time.xmlschema("1954-01-05T00:00:00.123456")
    dump_and_load(t, false)
  end

  def test_json_object
    obj = Jeez.new(true, 58)
    dump_and_load(obj, false)
  end

  def test_json_object_create_deep
    obj = One::Two::Three::Deep.new()
    dump_and_load(obj, false)
  end

  def test_json_object_bad
    json = %{{"^o":"Junk","x":true}}
    begin
      Oj.object_load(json)
    rescue Exception => e
      assert_equal("Oj::ParseError", e.class().name)
      return
    end
    assert(false, "*** expected an exception")
  end

  def test_json_object_not_hat_hash
    json = %{{"^#x":[1,2]}}
    h = Oj.object_load(json)
    assert_equal({1 => 2}, h);

    json = %{{"~#x":[1,2]}}
    h = Oj.object_load(json)
    assert_equal({'~#x' => [1,2]}, h);
  end

  def test_json_struct
    unless 'jruby' == RUBY_DESCRIPTION.split(' ')[0]
      obj = Stuck.new(false, 7)
      dump_and_load(obj, false)
    end
  end

  def test_json_struct2
    unless 'jruby' == RUBY_DESCRIPTION.split(' ')[0]
      obj = One::Stuck2.new(false, 7)
      dump_and_load(obj, false)
    end
  end

  def test_json_non_str_hash
    obj = { 59 => "young", false => true }
    dump_and_load(obj, false)
  end

  def test_mixed_hash_object
    Oj.default_options = { :mode => :object }
    json = Oj.dump({ 1 => true, 'nil' => nil, :sim => 4 })
    h = Oj.object_load(json)
    assert_equal({ 1 => true, 'nil' => nil, :sim => 4 }, h)
  end

  def test_circular_hash
    h = { 'a' => 7 }
    h['b'] = h
    json = Oj.dump(h, :mode => :object, :indent => 2, :circular => true)
    h2 = Oj.object_load(json, :circular => true)
    assert_equal(h2['b'].__id__, h2.__id__)
  end

  def test_circular_array
    a = [7]
    a << a
    json = Oj.dump(a, :mode => :object, :indent => 2, :circular => true)
    a2 = Oj.object_load(json, :circular => true)
    assert_equal(a2[1].__id__, a2.__id__)
  end

  def test_circular_object
    obj = Jeez.new(nil, 58)
    obj.x = obj
    json = Oj.dump(obj, :mode => :object, :indent => 2, :circular => true)
    obj2 = Oj.object_load(json, :circular => true)
    assert_equal(obj2.x.__id__, obj2.__id__)
  end

  def test_circular
    h = { 'a' => 7 }
    obj = Jeez.new(h, 58)
    obj.x['b'] = obj
    json = Oj.dump(obj, :mode => :object, :indent => 2, :circular => true)
    Oj.object_load(json, :circular => true)
    assert_equal(obj.x.__id__, h.__id__)
    assert_equal(h['b'].__id__, obj.__id__)
  end

  def test_odd_date
    dump_and_load(Date.new(2012, 6, 19), false)
  end

  def test_odd_datetime
    dump_and_load(DateTime.new(2012, 6, 19, 13, 5, Rational(4, 3)), false)
    dump_and_load(DateTime.new(2012, 6, 19, 13, 5, Rational(7123456789, 1000000000)), false)
  end

  def test_odd_string
    Oj.register_odd(Strung, Strung, :create, :to_s, 'safe?')
    s = Strung.new("Pete", true)
    dump_and_load(s, false)
  end

  def test_auto_string
    s = AutoStrung.new("Pete", true)
    dump_and_load(s, false)
  end

  def test_auto_array
    a = AutoArray.new([1, 'abc', nil], true)
    dump_and_load(a, false)
  end

  def test_auto_hash
    h = AutoHash.new(nil, true)
    h['a'] = 1
    h['b'] = 2
    dump_and_load(h, false)
  end

  def dump_and_load(obj, trace=false)
    json = Oj.dump(obj, :indent => 2, :mode => :object)
    puts json if trace
    loaded = Oj.object_load(json);
    assert_equal(obj, loaded)
    loaded
  end

end
