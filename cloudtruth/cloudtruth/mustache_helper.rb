require 'mustache'
require 'active_support/core_ext/hash'

module CloudTruth
  module MustacheHelper

    def render(template, hash)
      Mustache.render(template, structured_params(hash))
    end

    def structured_params(params)
      params.each_with_object({}) do |e, hash|
        k, v = e
        key_parts = k.to_s.split(".")
        if key_parts.length == 1
          # The key_name did not include a dot. Simple key_name => value
          hash[k] = v
        else
          # The key_name included dots. The result should be a nested hash with the final part of the key pointing to the value
          # Example:
          # key_name is foo.bar.baz
          # value is "my custom value"
          # result is { "foo" => { "bar" => { "baz" => "my custom value" } } }
          hash[key_parts.first] ||= {}
          translated_value = key_parts[1...-1].reverse.reduce({ key_parts.last => v }) do |acc, key_part|
            { key_part => acc }
          end
          hash[key_parts.first].deep_merge! translated_value
        end
      end
    end

    extend self
  end
end
