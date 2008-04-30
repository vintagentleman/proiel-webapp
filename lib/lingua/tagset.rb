#!/usr/bin/env ruby
#
# tagset.rb - Container classes for tag sets
#
# Written by Marius L. Jøhndal, 2007, 2008.
#
# $Id: $
#
require 'xmlsimple'
require 'extensions'

module Lingua
  class Tag 
    attr_reader :code
    attr_reader :summary
    attr_reader :abbreviation

    # Creates a new tag identified by a given code +code+ and optional descriptive 
    # information.
    #
    # ==== Options
    # summary:: A summary of the purpose of the tag, e.g. "nominative.
    # abbreviation:: A human-readable abbreviation for the tag, e.g. "nom.".
    def initialize(code, options = {})
      @code = code
      @summary = options[:summary]
      @abbreviation = options[:abbreviation]
    end

    # Returns a description of tag using a specified style.
    #
    # ==== Options
    # style:: If +:abbreviation+, returns the description on abbreviated form whenever possible.
    # If +:summary+, returns the description as a summary. Default is +:summary+.
    def description(options = {})
      options[:style] ||= :summary

      if options[:style] == :abbreviation
        @abbreviation ? @abbreviation : @summary
      elsif options[:style] == :summary
        @summary
      else
        raise "Invalid style #{options[:style]}."
      end
    end
  end

  class TagSet < Hash 
    def initialize(data, klass = Tag)
      c = (data.class == Hash ? data : 
        XmlSimple.xml_in(data, { 
          'KeyToSymbol' => true, 'KeyAttr' => 'code' }))
      if c[:tag]
        c[:tag].each_pair do |key, value|
          self[key.to_sym] = klass.new(key.to_sym, value.rekey { |k| k.to_sym })
        end
      end
    end

    #FIXME: eliminate this
    def [](key)
      fetch(key.to_sym, nil)
    end

    # Returns true if +code+ is a valid tag code, false otherwise. +code+
    # may be given either as a symbol or a string.
    def valid?(code)
      !code.nil? and code != '' and has_key?(code.to_sym)
    end
  end

  class PositionalTagSet < Hash 
    attr_reader :fields

    def initialize(data_file, klass = Tag)
      file_name = data_file

      c = XmlSimple.xml_in(file_name, { 
        'KeyAttr' => { 'field' => 'id', 'tag' => 'code' }})
      c['field'].each_pair do |key, value|
        self[key.to_sym] = TagSet.new(value.rekey { |k| k.to_sym })
      end

      @fields = c['order'][0]['position'].collect { |f| f['ref'].to_sym }
    end

    # Returns a hash with descriptions for the field +field+ in the tag set.
    #
    # ==== Options
    # style:: The style the description should be returned in, one of
    # +:abbreviation+ or +:summary+. Default is +:summary+.
    def descriptions(field, options = {})
      options[:style] ||= :summary
      Hash[*self[field].values.collect {|v| [ v.code, v.description(options) ] }.flatten].merge({ '-' => 'Undefined' })
    end

    # Returns a hash with descriptions for all fields in the tag set.
    # 
    # ==== Options
    # style:: The style the description should be returned in, one of
    # +:abbreviation+ or +:summary+. Default is +:summary+.
    def all_descriptions(options = {})
      options[:style] ||= :summary

      r = {}
      keys.each { |field| r[field] = descriptions(field, options) }
      r
    end

    # Computes the `intersection' of two positional tags
    def self.intersect(a, b)
      raise "Tags have different length" unless a.length == b.length
      a.split('').zip(b.split('')).collect { |x, y| x == y ? x : '-' }.join('')
    end

    # Computes the `union' of two positional tags. Raises an
    # exceptions if the tags conflict.
    def self.union(a, b)
      raise "Tags have different length" unless a.length == b.length
      a.split('').zip(b.split('')).collect { |x, y| 
        if x == '-'
          y
        elsif y != '-' and x != y
          raise "Union undefined; tags conflict: #{a} <-> #{b}"
        else
          x
        end
      }.join('')
    end

    # Returns true if any tag in the positional tag has contradictory
    # values.
    def self.contradictory?(a, b)
      a.split('').zip(b.split('')).find { |x, y| x != '-' && y != '-' && x != y } ? true : false
    end
  end
end

if $0 == __FILE__
  require 'test/unit'
  include Lingua

  class TagSetTestClass < Test::Unit::TestCase
    def setup
      @c = TagSet.new('test.xml')
    end

    def test_access
      assert_not_nil @c['bar']
      assert_not_nil @c['baz']
      assert_nil @c['bax']
    end

    def test_retrieval
      assert_equal 'foobar', @c['bar'].summary
      assert_equal 'foobaz', @c['baz'].summary
    end

    def test_length
      assert_equal 2, @c.length
    end

    def test_string_or_symbol
      assert_equal @c['bar'], @c[:bar]
    end

    def test_intersection
      assert_equal '-y----w-', PositionalTagSet.intersect('xyz---w-', 'XyZV--w-')
    end

    def test_union
      assert_equal 'xyzv--w-', PositionalTagSet.union('xyz---w-', 'xy-v--w-')
    end

    def test_bad_union
      assert_raise RuntimeError do
        PositionalTagSet.union('xyz---w-', 'xz-v--w-')
      end
    end

    def test_contradictory
      assert_equal true, PositionalTagSet.contradictory?('xyz---w-', 'xz-v--w-')
      assert_equal false, PositionalTagSet.contradictory?('xyz---w-', 'xy-v--w-')
    end
  end
end