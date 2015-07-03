module Spontaneous::Output::Store
  # A Transaction is a write-only view of the template store.
  # It provides #commit & #rollback mechanisms that function
  # like their DB equivalents, either preserving or removing the
  # modifications made.
  class Transaction
    attr_reader :revision

    def initialize(revision, store)
      @revision, @store = revision, store
      @index = []
      @committed = false
    end

    def store(output, dynamic, template)
      key = @store.output_key(output, dynamic)
      case
      when dynamic || output.dynamic? # dynamic
        @store.store_dynamic(@revision, key, template, self)
      when output.page.dynamic? # protected
        @store.store_protected(@revision, key, template, self)
      else # static
        @store.store_static(@revision, key, template, self)
      end
    end

    def asset(key, asset)
      @store.store_asset(@revision, key, asset, self)
    end

    def static(key, file)
      @store.store_static(@revision, key, file, self)
    end

    # Stores call this method to register the keys
    # they write to their backends. This is necessary
    # because we don't want to limit our backends to those
    # that are able to return keys based on a glob
    def push(key)
      @index.push(key)
    end

    def commit
      @store.add_revision(@revision, @index)
      @committed = true
    end

    def rollback
      @store.delete_revision(@revision, @index) unless @committed
    end
  end
end
