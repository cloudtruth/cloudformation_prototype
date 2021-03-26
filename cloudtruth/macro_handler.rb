require 'json'
require_relative 'cloudtruth/version'
require_relative 'cloudtruth/logging'
require_relative 'cloudtruth/substitution_macro'

LOG_LEVEL = (ENV['CT_LOG'] || :debug).to_sym
CloudTruth::Logging.setup_logging(level: LOG_LEVEL)
include GemLogger::LoggerSupport

CT_ENV = ENV["CT_ENV"] || "default"
CT_API_KEY = ENV["CT_API_KEY"]
CT_PARAMETER_FILTER = ENV["CT_PARAMETER_FILTER"] || ""

def cloudtruth_cf_macro(event:, context:)
  begin
    logger.debug { "event: #{event.inspect}" }
    logger.debug { "context: #{context.inspect}" }

    params = event["params"]
    templateParams = event["templateParameterValues"]
    env = params["Environment"] || templateParams["Environment"] || CT_ENV
    param_filter = params["ParameterFilter"] || templateParams["ParameterFilter"] || CT_PARAMETER_FILTER
    sm = CloudTruth::SubstitutionMacro.new(api_key: CT_API_KEY, environment: env, param_filter: param_filter)
    template = sm.walk(event["fragment"])

    logger.debug { "result: #{template.inspect}" }
    return {
        "requestId" => event["requestId"],
        "status" => "success",
        "fragment" => template
    }
  rescue Exception => e
    logger.log_exception(e, "Failure while applying macro")
    msg = "#{e.class.name}: #{e.message}"
    return {
      "requestId" => event["requestId"],
      "status" => "failure",
      "fragment" => event["fragment"],
      "errorMessage" => msg
    }
  end
end
