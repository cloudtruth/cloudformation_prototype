require_relative 'logging'
require_relative 'substitution_macro'
require 'aws-sdk-ssm'

module CloudTruth
  class SSMSubstitutionMacro < SubstitutionMacro

    include GemLogger::LoggerSupport

    def initialize(api_key:, environment:, param_filter: "", key_template: "/%{key}")
      logger.debug "Creating new SSMSubstitutionMacro"
      super(api_key: api_key, environment: environment, param_filter: param_filter)
      @key_template = key_template
    end

    def ssm_client
      @ssm_client ||= ::Aws::SSM::Client.new
    end

    def param_hash
      @param_hash ||= begin
        ct_params = super
        sync_ssm_params(ct_params)
      end
    end

    def get_ssm_params(keys)
      result = {}
      next_token = nil
      loop do
        logger.debug {"Describing ssm params for: #{keys.inspect}"}

        # max_results can't be greater than 10, which is the default
        # # use describe (to get description) in lockstep with get (for value)
        resp = ssm_client.describe_parameters(parameter_filters: [{
                key: "Name", # required
                option: "Equals",
                values: keys
            }],
                                              max_results: 10,
                                              next_token: next_token)

        logger.debug {"Describe ssm params result: #{resp.parameters.inspect}"}

        param_values = {}
        if resp.parameters.size > 0
          respval = ssm_client.get_parameters(names: resp.parameters.collect {|p| p.name } )
          param_values = Hash[respval.parameters.collect {|p| [p.name, p.value] }]
        end

        resp.parameters.each do |p|
          result[p.name] = [p, param_values[p.name]]
        end

        next_token = resp.next_token
        break if next_token.nil?
      end

      return result
    end

    def sync_ssm_params(ct_params)
      resolve_tmpl = "{{resolve:ssm:%{key}:%{version}}}"
      resolve_mapping = {}

      key_mapping =  Hash[ct_params.keys.collect {|key| [key, @key_template % {environment: environment, key: key}] }]
      ssm_params = get_ssm_params(key_mapping.values)

      ct_params.each do |k, v|
        version = nil
        ssm_param = Array(ssm_params[key_mapping[k]]) # Array, could be nil, 0=describe_parm, 1=value
        p, pv = ssm_param[0], ssm_param[1]

        opts = {
          name: key_mapping[k],
          value: v,
          type: "String",
          description: "Set by CloudTruth for #{k} in #{environment}"
        }

        if ! p
          logger.info "Creating parameter '#{key_mapping[k]}'"
          resp = ssm_client.put_parameter(opts)
          version = resp.version
        elsif pv != v
          # Should really use a tag here, but its a separate api call, and since
          # we have description, we can make use of it.
          if p.description !~ /^Set by CloudTruth/
            logger.info "Skipping set of parameter '#{p.name}' as it is not being managed by CloudTruth"
            version = p.version
          else
            logger.info "Updating parameter '#{p.name}'"
            resp = ssm_client.put_parameter(opts.merge(overwrite: true))
            version = resp.version
          end
        else
          logger.info "No changes needed for parameter '#{p.name}'"
          version = p.version
        end

        resolve_mapping[k] = resolve_tmpl % {key: key_mapping[k], version: version}
      end

      return resolve_mapping
    end

  end
end
