#!/usr/bin/env bash -e


function usage {
  echo "usage: $(basename $0) [-d] environment option"
  echo
  echo "  Run bootstrap once before doing it for any of the other examples"
  echo
  echo "  Arguments:"
  echo
  echo "    environment:  the environment to run against"
  echo "    option:       the example to provision/destroy.  Valid values are 1-4."
  echo
  echo "  Options:"
  echo
  echo "    -b         Bootstrap support resources"
  echo "    -d         Destroy provisioned example"
  echo
  exit 1
}

declare -i destroy=0 bootstrap=0

while getopts ":db" opt; do
  case $opt in
    d)
      destroy=1
      ;;
    b)
      bootstrap=1
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      usage
      ;;
  esac
done
shift $((OPTIND-1))

if (($# != 2 && !bootstrap)); then
  usage
fi

environment=$1
option=$2

AWS_ACCOUNT=${AWS_ACCOUNT:-$(aws sts get-caller-identity --output text | awk '{print $1}')}

macros_s3objects_stack="ctdemo-cf-macros-s3objects"
macros_cloudtruth_stack="ctdemo-cf-macros-cloudtruth"
templates_bucket="ctdemo-cf-templates-${AWS_ACCOUNT}"
website_stack="ctdemo-cf-${environment}-${option}-website"
website_template="website-${option}.template"

mkdir -p pkg

if ((bootstrap)); then

  if ((destroy)); then

    aws cloudformation delete-stack \
      --stack-name ${macros_cloudtruth_stack}

    aws cloudformation delete-stack \
      --stack-name ${macros_s3objects_stack}

    aws s3 rb --force s3://${templates_bucket}
    rm -rf pkg

  else

    aws s3 mb s3://${templates_bucket}

    aws cloudformation package \
        --template-file macro-s3objects.template \
        --s3-bucket ${templates_bucket} \
        --output-template-file pkg/macro-s3objects-packaged.template

    aws cloudformation deploy \
        --stack-name ${macros_s3objects_stack} \
        --template-file pkg/macro-s3objects-packaged.template \
        --capabilities CAPABILITY_IAM

    (cd cloudtruth; bundle config set deployment 'true'; bundle install)

    aws cloudformation package \
        --template-file macro-cloudtruth.template \
        --s3-bucket ${templates_bucket} \
        --output-template-file pkg/macro-cloudtruth-packaged.template

    aws cloudformation deploy \
        --stack-name ${macros_cloudtruth_stack} \
        --template-file pkg/macro-cloudtruth-packaged.template \
        --capabilities CAPABILITY_IAM

  fi

else

  if [[ ! -f $website_template ]]; then
    echo "Invalid option: $option"
    exit 1
  fi

  if ! aws cloudformation describe-stacks --stack-name ${macros_s3objects_stack} &> /dev/null; then
    echo "Run with bootstrap option at least once"
    exit 1
  fi

  if ((destroy)); then

    aws cloudformation delete-stack \
        --stack-name ${website_stack}

  else

    if [[ "$option" == "2" ]]; then
      outfile="website-2-mappings.template"
      echo "Configuration:" > $outfile
      cloudtruth environments list | while read e; do
        echo "  ${e}:" >> $outfile
        cloudtruth parameters list | grep cfdemo | while read p; do
          v=$(cloudtruth -e ${e} parameter get ${p})
          safep=$(echo $p | tr -Cd [:alnum:])
          echo "    ${safep}: ${v}" >> $outfile
        done
      done
    fi

    aws cloudformation package \
        --template-file ${website_template} \
        --s3-bucket ${templates_bucket} \
        --output-template-file pkg/website-${option}-packaged.template

    aws cloudformation deploy \
        --stack-name ${website_stack} \
        --template-file pkg/website-${option}-packaged.template \
        --capabilities CAPABILITY_IAM \
        --parameter-overrides Environment=${environment}

    url=$(aws cloudformation describe-stacks \
            --stack-name ${website_stack} \
            --output text \
            --query "Stacks[0].Outputs[? OutputName == URL].OutputValue")
    echo "Opening ${url}"
    open ${url} || true

  fi

fi
