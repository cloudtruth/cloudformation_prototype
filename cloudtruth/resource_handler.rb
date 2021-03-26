require 'json'
require_relative 'cloudtruth/version'
require_relative 'cloudtruth/logging'
require_relative 'cloudtruth/cf_resource'
require_relative 'aws_cloudformation_helper'

LOG_LEVEL = (ENV['CT_LOG'] || :debug).to_sym
CloudTruth::Logging.setup_logging(level: LOG_LEVEL)
include GemLogger::LoggerSupport

CT_ENV = ENV["CT_ENV"] || "default"
CT_API_KEY = ENV["CT_API_KEY"]

def cloudtruth_cf_resource_handler(event:, context:)
  logger.debug { "event: #{event.inspect}" }
  logger.debug { "context: #{context.inspect}" }

  environment = event["ResourceProperties"]["Environment"] || CT_ENV
  api_key = event["ResourceProperties"]["ApiKey"] || CT_API_KEY
  param_filter = event["ResourceProperties"]["ParameterFilter"] || ""

  logger.info "Initializing resource with environment=#{environment.inspect} and param_filter=#{param_filter.inspect}"
  resource = CloudTruth::CfResource.new(api_key: api_key, environment: environment, param_filter: param_filter)

  # Initializes CloudFormation Helper library
  @cfn_helper = AWS::CloudFormation::Helper.new(resource, event, context)

  # Add additional initialization code here
  @cfn_helper.logger.log_level = LOG_LEVEL

  # Executes the event
  @cfn_helper.event.execute
end
