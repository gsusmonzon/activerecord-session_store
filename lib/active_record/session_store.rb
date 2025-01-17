require 'active_record'
require 'active_record/session_store/version'
if Rails::VERSION::STRING < '5.2.0' # AbstractSecureStore was added in Rails 5.2
require 'action_dispatch/session/abstract_secure_store_backport.rb'
end
require 'action_dispatch/session/active_record_store'
require 'active_support/core_ext/hash/keys'
require 'multi_json'

module ActiveRecord
  module SessionStore
    autoload :Session, 'active_record/session_store/session'

    module ClassMethods # :nodoc:
      mattr_accessor :serializer

      def serialize(data)
        serializer_class.dump(data) if data
      end

      def deserialize(data)
        serializer_class.load(data) if data
      end

      def drop_table!
        connection.schema_cache.clear_data_source_cache!(table_name)
        connection.drop_table table_name
      end

      def create_table!
        connection.schema_cache.clear_data_source_cache!(table_name)
        connection.create_table(table_name) do |t|
          t.string session_id_column, :limit => 255
          t.text data_column_name
        end
        connection.add_index table_name, session_id_column, :unique => true
      end

      def serializer_class
        case self.serializer
          when :marshal, nil then
            MarshalSerializer
          when :json then
            JsonSerializer
          when :hybrid then
            HybridSerializer
          when :null then
            NullSerializer
          else
            self.serializer
        end
      end

      # Use Marshal with Base64 encoding
      class MarshalSerializer
        def self.load(value)
          Marshal.load(::Base64.decode64(value))
        end

        def self.dump(value)
          ::Base64.encode64(Marshal.dump(value))
        end
      end

      # Uses built-in JSON library to encode/decode session
      class JsonSerializer
        def self.load(value)
          hash = MultiJson.load(value)
          hash.is_a?(Hash) ? hash.with_indifferent_access[:value] : hash
        end

        def self.dump(value)
          MultiJson.dump(value: value)
        end
      end

      # Transparently migrates existing session values from Marshal to JSON
      class HybridSerializer < JsonSerializer
        MARSHAL_SIGNATURE = 'BAh'.freeze

        def self.load(value)
          if needs_migration?(value)
            Marshal.load(::Base64.decode64(value))
          else
            super
          end
        end

        def self.needs_migration?(value)
          value.start_with?(MARSHAL_SIGNATURE)
        end
      end

      # Defer serialization to the ActiveRecord database adapter
      class NullSerializer
        def self.load(value)
          value
        end

        def self.dump(value)
          value
        end
      end
    end
  end
end

ActiveSupport.on_load(:active_record) do
  require 'active_record/session_store/session'
end

require 'active_record/session_store/sql_bypass'
require 'active_record/session_store/railtie' if defined?(Rails)
