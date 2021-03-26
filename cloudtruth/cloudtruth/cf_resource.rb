require_relative 'logging'
require_relative 'ctapi'

module CloudTruth
  class CfResource

    include GemLogger::LoggerSupport

    def initialize(api_key:, environment:, param_filter: "")
      logger.debug "Creating new CfResource"
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

    def create
      # Add code to handle CloudFormation Create event
      return param_hash
    end

    def delete
      # Add code to handle CloudFormation Delete event
    end

    def update
      # Add code to handle CloudFormation Update event
      return param_hash
    end

  end
end
