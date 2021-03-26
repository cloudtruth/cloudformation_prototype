require_relative 'logging'
require_relative 'ctapi'
require_relative 'mustache_helper'

module CloudTruth
  class SubstitutionMacro

    include GemLogger::LoggerSupport
    attr_reader :environment, :param_filter

    def initialize(api_key:, environment:, param_filter: "")
      logger.debug "Creating new SubstitutionMacro"
      @api_key = api_key
      @environment = environment
      @param_filter = param_filter
    end

    def ctapi
      @ctapi ||= begin
        @ctapi_class = CloudTruth::CtApi(api_key: @api_key)
        @ctapi_class.new(environment: @environment)
      end
    end

    def param_hash
      @param_hash ||= begin
        params = ctapi.parameters_hash(searchTerm: @param_filter)
        # ct api currently only has a search, not a prefix filter
        params.select { |k, _| k =~ /^#{@param_filter}/ }
      end
    end

    def walk(node)
      if node.is_a? Hash
        return Hash[node.collect{|k, v| [k, walk(v)]}]
      elsif node.is_a? Array
        return node.collect{|e| walk(e)}
      elsif node.is_a? String
        # rely on mustache delimiter switching to ignore {{resolve:...}} for ssm/secrets dynamic references
        return CloudTruth::MustacheHelper.render(node, param_hash)
      else
        return node
      end
    end

  end
end
