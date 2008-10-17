ActiveRecord::Base.send :include, ActiveRecord::Acts::NestedSet
ActionView::Base.send :include, ActiveRecord::Acts::NestedSetHelper