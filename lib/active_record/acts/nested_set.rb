module ActiveRecord
	module Acts #:nodoc:
		module NestedSet #:nodoc:
      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods
        # Configuration options are:
        #
        # * +self.parent_col_name+ - specifies the column name to use for keeping the position integer (default: +parent_id+)
        # * +left_column+ - column name for left boundry data, default +lft+
        # * +right_column+ - column name for right boundry data, default +rgt+
        # * +scope+ - restricts what is to be considered a list. It only accepts simple sql strings
        # * Use the following line in your migration to create the necessary fields 
        # * +t.integer :lft, :rgt, :parent_id, :depth+
        def acts_as_nested_set(options = {})
          configuration = { :parent_column => 'parent_id', :left_column => 'lft', :right_column => 'rgt' }

          configuration.update(options) if options.is_a?(Hash)

          #It's important that we do this when the acts_as_nested_set method is called
          class_eval <<-EOV
            class << self          
              def left_col_name() "#{configuration[:left_column]}" end
              def right_col_name() "#{configuration[:right_column]}" end
              def parent_col_name() "#{configuration[:parent_column]}" end
              
              # If we want to use with_scope we will have to change this method and create a named scope for lft ordered items
              # Otherwise we will not be able to change the order in later queries
              # see http://ryandaigle.com/articles/2008/8/20/named-scope-it-s-not-just-for-conditions-ya-know
              def find(*args)
                with_scope(:find => { :order => 'lft' }) do
                  super
                end
              end
            end
                          
            unless include?(ActiveRecord::Acts::NestedSet::InstanceMethods)
              extend ActiveRecord::Acts::NestedSet::InstanceClassMethods
              include ActiveRecord::Acts::NestedSet::InstanceMethods
              
              attr_protected :#{configuration[:left_column]}, :#{configuration[:right_column]}
              # removed depth from this list as we may need to set it manually if it is used as scope in a validation
                          
              before_create   :position_at_end_of_set
              after_create    :position_correctly
              before_destroy  :reload_and_destroy_children
              after_destroy   :close_set_after_deletion
            end
          EOV
        end
      end
      
      module InstanceClassMethods
        def roots
				  find :all, :conditions => { :depth => 1 }
				end
				
				def right_outer_bound
			    find(:first, :order => "#{right_col_name} DESC").right_col
			  end
			  
			  # At the moment does them in lft order, would really like to do them in reverse order
			  def previous_siblings(node, *args)
				  with_exclusive_scope(:find => { :conditions => "#{left_col_name} BETWEEN #{node.parent.left_col} AND #{node.left_col} - 1 AND depth = #{node.depth}" }) do
				    find(:all, *args)
				  end
				end
				
				def next_siblings(node, *args)
				  with_exclusive_scope(:find => { :conditions => "#{left_col_name} BETWEEN #{node.right_col} AND #{node.parent.right_col} - 1 AND depth = #{node.depth}" }) do
				    find(:all, *args)
				  end
				end
				
				def previous_sibling(node)
				  p "#{right_col_name} = #{node.left_col} - 1"
				  find(:first, :conditions => "#{right_col_name} = #{node.left_col} - 1")
				end
				
				def next_sibling(node)
				  find(:first, :conditions => "#{left_col_name} = #{node.right_col} + 1")
				end				  
			  
        def swap_siblings(first, second)
				  raise ActiveRecord::ActiveRecordError, "You cannot move a new node" if first.new_record? || second.new_record?
          
          first.reload and second.reload
          
          return [first, second] if first == second
          
          first, second = second, first if second.lft < first.lft
          
          raise ActiveRecord::ActiveRecordError, "Nodes are not siblings" if first.parent_id != second.parent_id
                    
					move_out_delta            = right_outer_bound - first.left_col + 1
					sibling_shift_delta       = (second.right_col - second.left_col) - (first.right_col - first.left_col)
					move_up_delta             = first.left_col - second.left_col
					move_in_delta             = -(right_outer_bound - second.left_col - ((first.left_col - first.right_col) - (second.left_col - second.right_col)) + 1)
					#move_in_delta             = second.right_col - right_outer_bound - (second.right_col - second.left_col + 1)
					#move_in_delta             = (-move_out_delta + (sibling_shift_delta + 2).abs)
           
				  move_out_conditions       = "#{left_col_name} >= #{first.left_col} AND #{right_col_name} <= #{first.right_col}"
					sibling_shift_conditions  = "#{left_col_name} > #{first.right_col} AND  #{right_col_name} < #{second.left_col}"
				  #p move_up_conditions        = "id = #{second.id} OR #{parent_col_name} = #{second.id}"
				  move_up_conditions        = "id IN (#{second.children_and_self.map(&:id).join(", ")})"
				  move_in_conditions        = "#{left_col_name} > #{right_outer_bound}"
				  
				  move_out_assignment       = "#{left_col_name} = (#{left_col_name} + #{move_out_delta}), #{right_col_name} = (#{right_col_name} + #{move_out_delta})"
				  sibling_shift_assignment  = "#{left_col_name} = (#{left_col_name} + #{sibling_shift_delta}), #{right_col_name} = (#{right_col_name} + #{sibling_shift_delta})"
				  move_up_assignment        = "#{left_col_name} = (#{left_col_name} + #{move_up_delta}), #{right_col_name} = (#{right_col_name} + #{move_up_delta})"
				  move_in_assignment        = "#{left_col_name} = (#{left_col_name} + #{move_in_delta}), #{right_col_name} = (#{right_col_name} + #{move_in_delta})"            

					base_class.transaction do
					  #find(:all).each { |item| p [item.id, item.lft, item.rgt, item.title] }
					  #p ""
						update_all(move_out_assignment, move_out_conditions)
					#	 find(:all).each { |item| p [item.id, item.lft, item.rgt, item.title] }
					#	 p ""
						update_all(sibling_shift_assignment, sibling_shift_conditions) if sibling_shift_delta > 0
					#	 find(:all).each { |item| p [item.id, item.lft, item.rgt, item.title] }
					#	 p ""
				    update_all(move_up_assignment, move_up_conditions)		
				  #   find(:all).each { |item| p [item.id, item.lft, item.rgt, item.title] }
				  #   p ""
				    update_all(move_in_assignment, move_in_conditions)  
				  #   find(:all).each { |item| p [item.id, item.lft, item.rgt, item.title] }
				  #   p ""
					end

					[first.reload, second.reload]
				end
			end
      
      module InstanceMethods
        #only designed to be used by nestedset methods, use lft or your own column name in your own objects
        def left_col_name() self.class.left_col_name end
        def right_col_name() self.class.right_col_name end
        def parent_col_name() self.class.parent_col_name end
          
        def left_col() self[left_col_name] end
        def left_col=(l) self[left_col_name] = l end 
        def right_col() self[right_col_name] end
        def right_col=(r) self[right_col_name] = r end                   
        def parent_col() self[parent_col_name] end
        def parent_col=(p) self[parent_col_name] = p end
        

        
      	# Returns the parent of this node, caching it in an instance variable          
      	def parent
					@parent ||= self.class.find_by_id(parent_col)
				end
				
				def children_count
					left_col == nil || right_col == nil ? 0 : (right_col - left_col - 1) / 2
				end
				
				def ancestors(conditions = nil)
				  #return [] if self.root?
				  ancestor_conditions = "#{left_col_name} < #{left_col} AND #{right_col_name} > #{right_col}"
				  ancestor_conditions += " AND #{conditions}" if conditions
				  self.class.find(:all, :conditions => ancestor_conditions, :order => 'lft DESC')
				end
				  
				#conditions not tested
				def children(depth = 0, conditions = nil)
				  return [] if right_col == left_col + 1
				  children_conditions = "#{right_col_name} BETWEEN #{left_col + 1} AND #{right_col - 1}"
				  children_conditions += " AND depth = #{depth}" if depth > 0
				  #children_conditions += " AND depth BETWEEN #{self.depth + depth + 1} AND #{self.depth + depth + 2}" if depth > 0	  
				  children_conditions += " AND #{conditions}" if conditions
				  self.class.find(:all, :conditions => children_conditions)
				end
				
				def direct_children(conditions = nil)
				  children(self.depth + 1, conditions)
				end				
			
				#conditions not tested
				def children_and_self(conditions = nil)
				  children_conditions = "#{right_col_name} BETWEEN #{left_col} AND #{right_col}"
				  children_conditions += " AND #{conditions}" if conditions
				  self.class.find(:all, :conditions => children_conditions)
				end
				
				def previous_siblings(*args) self.class.previous_siblings(self, *args) end
				def next_siblings(*args) self.class.next_sibling(self, *args) end				
				def previous_sibling() self.class.previous_sibling(self) end
				def next_sibling() self.class.next_sibling(self) end
				
				def add_child(child)
				  child.parent_id = self.id
				  child.save
				  #self.reload
				  child
				end
				
				def move_up
				  if sibling = previous_sibling
				    self.class.swap_siblings(sibling, self) 
				  end
				end
				
			  def move_down
          if sibling = next_sibling
			      self.class.swap_siblings(sibling, self)
			    end
			  end
				
				def sort_children(by, order = :asc)
				  by = by.to_sym
				  direct_children = children(self.depth + 1)
				  #logger.info(direct_children)
				  raise ActiveRecord::ActiveRecordError, "Children did not respond to #{by}" unless direct_children.first.respond_to?(by)
				  sorted_direct_children = direct_children.sort_by(&by)
				  sorted_direct_children = sorted_direct_children.reverse if order.to_sym == :desc
				  
				  #logger.info(sorted_direct_children.map(&:title).inspect)
				  #logger.info(direct_children.map(&:title).inspect)
				  
				  self.class.base_class.transaction do
  				  sorted_direct_children.each_with_index do |child, index1|
  				    #logger.info(child.title)
  				    index2 = direct_children.index(child)
				      #logger.info self.class.find(:all, :conditions => "parent_id=#{id}").map { |item| [item.id, item.lft, item.rgt, item.title]}.inspect
  				    child1, child2 = direct_children[index1], direct_children[index2]
  				    self.class.swap_siblings(child1, child2)
  				    direct_children = children(self.depth + 1)
  				  end
  				end
				end
				
				# Remove all an items children, keeps set integrity
				def destroy_children
					return if new_record? || right_col == left_col + 1
					
					self.class.base_class.transaction do
						self.class.delete_all("#{left_col_name} > #{left_col} AND #{right_col_name} < #{right_col}")
						close_set(right_col, children_count)			
					end
					
					self
				end
				
				def open_set(from, width = 1)
				  return if width == 0
          self.class.update_all("#{left_col_name} = (#{left_col_name} + #{2 * width})", "#{left_col_name} >= #{from}")
          self.class.update_all("#{right_col_name} = (#{right_col_name} + #{2 * width})", "#{right_col_name} >= #{from}")        
				end
				
				def close_set(from, width = 1)
				  return if width == 0
				  self.class.update_all("#{left_col_name} = (#{left_col_name} - #{2 * width})", "#{left_col_name} >= #{from}")
          self.class.update_all("#{right_col_name} = (#{right_col_name} - #{2 * width})", "#{right_col_name} >= #{from}")
			  end
			  
        # Callbacks
				
				def position_at_end_of_set
				  if self.parent_col && self.parent_col != 0
				    self.depth = parent[:depth] + 1
				  else
				    self.parent_col = 0
				    self.depth = 0
				    self.left_col = (last = self.class.find(:first, :order => "#{right_col_name} DESC")) ? last.right_col + 1 : 1
				    self.right_col = self.left_col + 1
				  end
				end
				
				def position_correctly
				  if self.parent_col != 0
				    open_set(connection.select_value("SELECT #{right_col_name} FROM #{self.class.table_name} WHERE ID = #{self.parent_col}"))
				    self.class.update_all("#{left_col_name} = #{parent.right_col}, #{right_col_name} = #{parent.right_col + 1}", "id = #{id}")
				    self.reload
				  end
				end
				
				def reload_and_destroy_children
				  reload
				  destroy_children
				end

				def close_set_after_deletion
				  close_set(right_col)
				end
      end
    end
  end
end

# def find(*args)
#   if args.first == :all
#     if args.last.is_a?(Hash)                  
#       options = args.last
#       options[:order] = (options[:order] ? "#{configuration[:left_column]}, #{options[:order]}" : "#{configuration[:left_column]}") unless options[:order] =~ /#{configuration[:left_column]}/
#       args.last[:order] = options[:order]      
#     else
#       args.push({ :order => 'lft' })
#     end
#   end
#   super
# end