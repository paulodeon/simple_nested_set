require 'test/unit'

require 'rubygems'
require 'active_record'


$:.unshift File.dirname(__FILE__) + '/../lib/active_record/acts'

require 'nested_set'
#require File.dirname(__FILE__) + '/../init'
ActiveRecord::Base.send :include, ActiveRecord::Acts::NestedSet

ActiveRecord::Base.establish_connection(:adapter => "sqlite3", :dbfile => ":memory:")

class Mixin < ActiveRecord::Base
end

class NestedSet < Mixin
  set_table_name :mixins
  acts_as_nested_set :scope => "root_id IS NULL"
end

class NestedSetSubclass < NestedSet
end

class NestedSetWithNonStandardColumns < ActiveRecord::Base
	set_table_name :ns_mixins
	acts_as_nested_set :left_column => 'l', :right_column => 'r', :parent_column => 'p'
end

class NestedSetWithOverriddenCallbacks < NestedSet
  before_create :do_something
  
  def do_something
    return 1 + 1
  end
end

class SimpleNestedSetTest < Test::Unit::TestCase
  def setup
   silence_stream(STDOUT) do
      ActiveRecord::Schema.define(:version => 1) do
        create_table :mixins do |t|
          t.integer :lft, :rgt, :parent_id, :root_id, :depth
          t.string :title 
          t.timestamps
        end
				
				create_table :ns_mixins do |t|
          t.integer :l, :r, :p, :root_id, :depth
          t.timestamps
        end
      end
    end	
  end
  
  def teardown
    ActiveRecord::Base.connection.tables.each do |table|
      ActiveRecord::Base.connection.drop_table(table)
    end
  end



  def set(id)
    NestedSet.find(id)
  end
	
	def class_methods
		[:left_col_name, :right_col_name, :parent_col_name]
	end
	
	def instance_methods
		class_methods + [:left_col, :right_col, :parent_col, :left_col=, :right_col=, :parent_col=]
	end

	def object_types
		[NestedSet, NestedSetSubclass, NestedSetWithNonStandardColumns, NestedSetWithOverriddenCallbacks]
	end
	
	
		
  def check_instance_method_mixins(obj)
		for instance_method in instance_methods
			assert_respond_to obj, instance_method
		end
  end
	
	def check_class_method_mixins(obj)
		for class_method in class_methods
			assert_respond_to obj, class_method
		end
  end
    
  def test_mixing_in_instance_methods
		for type in object_types
			check_instance_method_mixins type.new
		end
  end
	
	def test_mixing_in_class_methods
		object_types.each do |type|
			check_class_method_mixins type
		end
	end
	
	def test_column_name_methods
		assert_equal 'lft', NestedSet.left_col_name
		assert_equal 'rgt', NestedSet.right_col_name
		assert_equal 'parent_id', NestedSet.parent_col_name
		
		assert_equal 'l', NestedSetWithNonStandardColumns.left_col_name 
		assert_equal 'r', NestedSetWithNonStandardColumns.right_col_name
		assert_equal 'p', NestedSetWithNonStandardColumns.parent_col_name
	end
	
	
	def test_root_creation
	  ns = NestedSet.create
	  
	  assert_equal 1, ns.left_col
	  assert_equal 2, ns.right_col
	  assert_equal 0, ns.parent_col
	  assert_equal 0, ns.depth
	end
	
	def test_child_creation
	  ns = NestedSet.create
	  ns2 = NestedSet.create(:parent_id => 1)
	  ns.reload
	  
	  assert_equal 1, ns.left_col
	  assert_equal 4, ns.right_col
	  assert_equal 0, ns.parent_col
	  assert_equal 0, ns.depth
	  
	  assert_equal 2, ns2.left_col
	  assert_equal 3, ns2.right_col
	  assert_equal 1, ns2.depth
	end
	
	def test_callbacks
	  ns = NestedSetWithOverriddenCallbacks.create
	  ns2 = NestedSetWithOverriddenCallbacks.create(:parent_id => 1)
	  ns.reload
	  
	  assert_equal 1, ns.left_col
	  assert_equal 4, ns.right_col
	  assert_equal 0, ns.parent_col
	  assert_equal 0, ns.depth
	  
	  assert_equal 2, ns2.left_col
	  assert_equal 3, ns2.right_col
	  assert_equal 1, ns2.depth
	end
	
	def test_adding_second_root
	  ns = NestedSet.create
	  ns2 = NestedSet.create(:parent_id => 1)
	  ns3 = NestedSet.create
	  
	  assert_equal 5, ns3.left_col
	  assert_equal 6, ns3.right_col
	end
	
	def test_destroy
	  ns = NestedSet.create
	  ns2 = NestedSet.create(:parent_id => 1)
	  ns3 = NestedSet.create
	  ns2.destroy
	  ns.reload
	  ns3.reload
	  
	  assert_equal 1, ns.left_col
	  assert_equal 2, ns.right_col
	  assert_equal 3, ns3.left_col
	  assert_equal 4, ns3.right_col
	end
	
	def test_children_functions
	  ns1 = NestedSet.create
	  ns2 = NestedSet.create(:parent_id => 1)
	  ns3 = NestedSet.create(:parent_id => 2)
	  ns4 = NestedSet.create(:parent_id => 3)
	  ns5 = NestedSet.create
	  
	  ns1.reload
	  ns2.reload
	  ns3.reload

	  assert_equal 3, ns1.children.length
	  assert_equal 3, ns1.children_count
	  assert_equal 2, ns2.children.length
	  assert_equal 2, ns2.children_count
	  assert_equal 1, ns3.children.length
	  assert_equal 1, ns3.children_count 
	  assert_equal 1, ns1.children(ns1.depth + 1).length
	  assert_equal 1, ns1.children(ns1.depth + 2).length

	  assert_equal ns4, ns1.children(ns1.depth + 3).last
	end
	
	def test_find
	  ns1 = NestedSet.create
	  ns2 = NestedSet.create(:parent_id => 1)
	  ns3 = NestedSet.create(:parent_id => 2)
	  ns4 = NestedSet.create(:parent_id => 3)
	  ns5 = NestedSet.create
	  
	  ns6 = NestedSet.create(:parent_id => 2)
	  ns7 = NestedSet.create(:parent_id => 4)
	  
	  full_set = NestedSet.find :all
	  
	  #Should now look like
	  #  1
	  #    2
	  #      3
	  #        4
	  #          7
	  #    6
	  #  5
	  
	  assert_equal ns4, full_set[3]
	  assert_equal ns7, full_set[4]
	  assert_equal ns6, full_set[5]
	end
	
	def test_add_child
	  ns1 = NestedSet.create
	  ns2 = ns1.add_child(NestedSet.new)
	  ns3 = ns1.add_child(NestedSet.new)
	  ns1.reload

	  assert_equal ns2, ns1.children.first
	  assert_equal ns3, ns1.children.last
	end
	
	def test_children_and_self
	  ns1 = NestedSet.create
	  ns2 = NestedSet.create(:parent_id => 1)
	  ns3 = NestedSet.create(:parent_id => 2)
	  ns4 = NestedSet.create(:parent_id => 3)
	  ns5 = NestedSet.create
	  
	  ns1.reload
	  
	  assert_equal 4, ns1.children_and_self.length
	  assert_equal ns1, ns1.children_and_self.first
	end
	
	def test_swap_children
	  ns1 = NestedSet.create
	  ns2 = NestedSet.create(:parent_id => 1)
	  ns3 = NestedSet.create(:parent_id => 2)
	  ns4 = NestedSet.create(:parent_id => 3)
	  ns5 = NestedSet.create
	  
	  ns6 = NestedSet.create(:parent_id => 2)
	  ns7 = NestedSet.create(:parent_id => 4)
	  
	  #Should now look like
	  #  1
	  #    2
	  #      3
	  #        4
	  #          7
	  #      6
	  #  5

	  NestedSet.swap_siblings(ns3, ns6)

	  ns2.reload
	  
	  #Should now look like
	  #  1
	  #    2
	  #      6
	  #      3
	  #        4
	  #          7  
	  #  5
	  
	  #test for adjacent children
	  assert_equal ns6, ns2.children.first
	  assert_equal ns3, ns2.children[1]
	  assert_equal ns7, ns2.children.last
	  
	  #test that order of children passed doesnt matter
	  NestedSet.swap_siblings(ns3, ns6)
	  
	  assert_equal ns6, ns2.children.last
	  assert_equal ns3, ns2.children.first
	  assert_equal ns7, ns2.children[-2]
	  
	  #test for children of unequal depth
	  assert_raise(ActiveRecord::ActiveRecordError) { NestedSet.swap_siblings(ns4, ns5) }
	  
	  #test for non-adjacent children
	  ns1 = NestedSet.create
	  ns2 = ns1.add_child NestedSet.new(:title => 'gamma')
	  ns3 = ns1.add_child NestedSet.new(:title => 'epsilon')
	  ns4 = ns1.add_child NestedSet.new(:title => 'zeta')
	  ns5 = ns1.add_child NestedSet.new(:title => 'delta')
	  ns6 = ns1.add_child NestedSet.new(:title => 'beta')
	  ns7 = ns1.add_child NestedSet.new(:title => 'alpha')

    NestedSet.swap_siblings(ns2, ns6)
    
    ns1.reload
    
    assert_equal ns6, ns1.children.first
    assert_equal ns2, ns1.children[-2]
    assert_equal ns7, ns1.children.last
	end
	
  def test_sort_children
    ns1 = NestedSet.create
    ns2 = ns1.add_child NestedSet.new(:title => 'e')#4
    ns3 = ns1.add_child NestedSet.new(:title => 'c')#3
    ns4 = ns1.add_child NestedSet.new(:title => 'f')#5
    ns5 = ns1.add_child NestedSet.new(:title => 'd')#2
    ns6 = ns1.add_child NestedSet.new(:title => 'b')#1
    ns7 = ns1.add_child NestedSet.new(:title => 'a')#0
    
    ns1.reload
      
    ns1.sort_children(:title)
      
    assert_equal ns7, ns1.children.first
    assert_equal ns4, ns1.children.last
  end
  
  def test_ancestors
    ns1 = NestedSet.create
	  ns2 = NestedSet.create(:parent_id => 1)
	  ns3 = NestedSet.create(:parent_id => 2)
	  ns4 = NestedSet.create(:parent_id => 3)
	  ns5 = NestedSet.create
	  
	  ns6 = NestedSet.create(:parent_id => 2)
	  ns7 = NestedSet.create(:parent_id => 4)
	  
	  #Should now look like
	  #  1
	  #    2
	  #      3
	  #        4
	  #          7
	  #      6
	  #  5
	  p ns7.ancestors
	  assert_equal ns4, ns7.ancestors.first
	  assert_equal ns1, ns7.ancestors.last
  end
  
  def test_previous_siblings
    ns1 = NestedSet.create
    ns2 = ns1.add_child NestedSet.new(:title => 'e')#4
    ns3 = ns1.add_child NestedSet.new(:title => 'c')#3
    ns4 = ns1.add_child NestedSet.new(:title => 'f')#5
    ns5 = ns1.add_child NestedSet.new(:title => 'd')#2
    ns6 = ns1.add_child NestedSet.new(:title => 'b')#1
    ns7 = ns1.add_child NestedSet.new(:title => 'a')#0
    ns1.reload
    
    assert_equal 1, ns3.previous_siblings.length
    assert_equal 3, ns5.previous_siblings.length
    assert_equal 5, ns7.previous_siblings.length
    assert_equal ns2, ns3.previous_siblings[0]
    assert_equal ns2, ns7.previous_siblings[0]
  end
  
  def test_previous_and_next_sibling
    ns1 = NestedSet.create
    ns2 = ns1.add_child NestedSet.new(:title => 'e')#4
    ns3 = ns1.add_child NestedSet.new(:title => 'c')#3
    ns4 = ns1.add_child NestedSet.new(:title => 'f')#5
    ns5 = ns1.add_child NestedSet.new(:title => 'd')#2
    ns6 = ns1.add_child NestedSet.new(:title => 'b')#1
    ns7 = ns1.add_child NestedSet.new(:title => 'a')#0 
    ns1.reload
    
    assert_equal ns3, ns2.next_sibling
    assert_equal ns2, ns3.previous_sibling
    assert_equal nil, ns1.previous_sibling
    assert_equal nil, ns7.next_sibling
  end
  
  def test_move_up_and_down
    ns1 = NestedSet.create
    ns2 = ns1.add_child NestedSet.new(:title => 'e')#4
    ns3 = ns1.add_child NestedSet.new(:title => 'c')#3
    ns4 = ns1.add_child NestedSet.new(:title => 'f')#5
    ns5 = ns1.add_child NestedSet.new(:title => 'd')#2
    ns6 = ns1.add_child NestedSet.new(:title => 'b')#1
    ns7 = ns1.add_child NestedSet.new(:title => 'a')#0 
    ns1.reload
    
    ns3.move_up
    ns5.move_up
    ns6.move_down
    ns6.move_down #shouldnt move anywhere if already last
    
    assert_equal ns3, ns1.children.first
    assert_equal ns5, ns1.children[2]
    assert_equal ns6, ns1.children.last
  end
end

