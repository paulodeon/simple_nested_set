module ActiveRecord
	module Acts #:nodoc:
		module NestedSetHelper
			def render_tree(tree, selected_item = nil, tree_start_tag = 'ul', list_tag = 'ul', item_tag = 'li', partial = nil, locals = nil, &block)
			  locals = {} unless locals.is_a?(Hash)
				start_tag = "<#{list_tag}>"
				end_tag = "</#{list_tag}>"
				item_end_tag = "</#{item_tag}>"
				
				ret = "<#{tree_start_tag}>"
				
				tree.each_with_index do |item, i|
				  previous_item = item == tree.first ? nil : tree[i - 1]
					next_item = item == tree.last ? nil : tree[i + 1]
					
					previous_depth = previous_item ? previous_item.depth : 0
					next_depth = next_item ? next_item.depth : 0
					
					children = item.children_count > 0 && next_item && next_item.parent_id == item.id
					
					first = item.depth > previous_depth 
					last = item.depth > next_depth
					
					
					ret += if partial
					  render(:partial => partial, :locals => locals.merge({ :item => item, :children => children, :first => first, :last => last, :selected_item => selected_item }))
					else
					  capture(item, selected_item, children, first, last, &block)
					end
					
					ret += children ? start_tag : item_end_tag
					(item.depth - next_depth).times { ret += end_tag + item_end_tag }
				end
			  
			  ret += end_tag
			  concat(ret, block.binding) unless partial
			  ret
			end
					
			def render_full_tree(items, selected_item = nil, tree_start_tag = 'ul', list_tag = 'ul', item_tag = 'li', partial = 'list_item')			  
				render_tree(items, selected_item, tree_start_tag, list_tag, item_tag, partial, { :selected_item => selected_item })
			end
		end
	end
end
