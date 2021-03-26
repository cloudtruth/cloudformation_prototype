require_relative 'logging'

module CloudTruth
  Parameter = Struct.new(:key, :value, :secret, :original_key, keyword_init: true)
end
