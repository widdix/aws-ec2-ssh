# Showcase Test

The goal of this tests is to ensure that the showcase is always working. The tests are implemented in Java 8 and run in JUnit 4.

If you run this tests, an AWS CloudFormation stack is created and **charges may apply**!

[widdix GmbH](https://widdix.net) sponsors the test runs on every push and once per week to ensure that everything is working as expected.

## Supported env variables

* `IAM_ROLE_ARN` if the tests should assume an IAM role before they run supply the ARN of the IAM role
* `TEMPLATE_DIR` Load templates from local disk. Must end with an `/`.
* `DELETION_POLICY` (default `delete`, allowed values [`delete`, `retain`]) should resources be deleted?
* `VERSION` RPM version to test

## Usage

### AWS credentials

The AWS credentials are passed in as defined by the AWS SDK for Java: http://docs.aws.amazon.com/sdk-for-java/v1/developer-guide/credentials.html

One addition: you can supply the env variable `IAM_ROLE_ARN` which let's the tests assume a role with the default credentials before running the tests.

### Region selection

The region selection works like defined by the AWS SDK for Java: http://docs.aws.amazon.com/sdk-for-java/v1/developer-guide/java-dg-region-selection.html

### Run all tests

```
AWS_REGION="us-east-1" TEMPLATE_DIR="/path/to/widdix-aws-ec2-ssh/" mvn test
```

### Assume role

This is useful if you run on a integration server like Jenkins and want to assume a different IAM role for this tests.

```
IAM_ROLE_ARN="arn:aws:iam::ACCOUNT_ID:role/ROLE_NAME" TEMPLATE_DIR="/path/to/widdix-aws-ec2-ssh/" mvn test mvn test
```
