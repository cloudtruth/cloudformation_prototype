# Using CloudTruth within CloudFormation
 
All options provision a simple s3 bucket webpage to test different options for passing configuration into CloudFormation with CloudTruth

### Option 1 - The Control option

All configuration hardcoded directly into templates

### Option 2 - Mappings

Included Mappings - The mappings file is included using the CF Include
Transform.  The included mappings file can be generated using a CloudTruth
template or by direct use of the CloudTruth CLI.
* Our templates don't currently allow iteration which makes it clunky for this use case
* The CLI approach used in deploy.sh is a little slow as we don't have bulk parameter fetching 
    
### Option 3 - Macro

Use a CloudTruth custom macro to directly fetch data using the CloudTruth
API. It uses mustache templating in strings to replace {{varname}} with the
parameter of the same name in CloudTruth.
* One can view the transformed template with variables substituted in the AWS CloudFormation console
    
### Option 4 - Macro with on demand fetch of CloudTruth -> SSM and dynamic references

Use a CloudTruth custom macro to sync data from CloudTruth to SSM, and replace references in the template with the SSM resolve reference
* Transformed template only shows [dynamic reference](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/dynamic-references.html) rather than value, e.g. {{cfdemo.bucket}} => {{resolve:ssm:/cloudtruth/development/cfdemo.bucket:<latestVer>}}
* The Lambda function is created with iam policy to perform DescribeParameters, GetParameters and PutParameter.
* This macro will only overwrite Parameters that it created.  If there is a key conflict, it will be noted in the logs - unlikely as by default it is configured with "/cloudtruth" as a prefix on all the SSM parameters it creates
* TODO: Extend to use the SSM SecureString type or SecretsManager for the CloudTruth parameters marked as secret 
* TODO: Add the ability to proceed using previously set SSM parameters if the CloudTruth API is down

### Option 5 - Custom Resource

Use a CloudTruth custom CF resource to directly fetch data using the CloudTruth
API

### TODO: Option 6 - Long lived CloudTruth -> SSM sync process, manual or macro based management of references to them in the CF Templates

Nothing here yet

## Usage

* Requirements: AWS CLI, CloudTruth CLI, ruby with bundler gem
* Add your CloudTruth API key to ssm:/ct_api_key and make sure it is configured for the CloudTruth CLI 
* Add the parameters cfdemo.bucket and cfdemo.message to CloudTruth (override for multiple environments if desired, or just use the `default` one)
* First bootstrap macros used by the provisioning scripts: `./deploy.sh -b`
* Then deploy one of the options for a given environment: `./deploy.sh development 1`
* After trying the desired options, you can cleanup with:
    ```
    # Clean each option you deployed like
    ./deploy.sh -d development 1
    # Cleanup bootstrap
    ./deploy.sh -d -b
    ```
