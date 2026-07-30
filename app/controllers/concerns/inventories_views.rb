module InventoriesViews
  extend ActiveSupport::Concern

  included do
    singleton_class.prepend(Module.new {
      def _prefixes
        @_prefixes ||= ["inventories"] | super
      end
    })
  end
end
