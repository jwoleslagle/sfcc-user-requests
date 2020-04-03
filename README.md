# sfcc-user-requests
A process for automating SFCC user access requests, integrating a DynamoDB table with RESTful API endpoints and various helper lambdas. Currently this is limited to CSR user requests, but could be expanded to other roles easily.

This project was necessitated by SFCC handling of user creation and provisioning, which requires a low-level API wrapper (called SFCC-CI) where the account manager user is created and the account manager role is granted, and a manual step whereby the end user must log in and provide a password before the instance role can be granted. Password generation, i.e. setting a default password, cannot be done programmatically). Additionally, the business manager side of SFCC (which contains the job scheduler) cannot interact with account manager, which is where user accounts are provisioned and stored. 

This process allows a non-technical user with the correct Okta permissions to securely input a spreadsheet via presigned URL with 15 min expiry (the spreadsheet template can be found at https://docs.google.com/spreadsheets/d/1o49Xy6DNR57LiKpdAf2pQTHc4-L2-ycTlhd4M53gZ_o/edit?usp=sharing ), and the rest of the process is offloaded onto various AWS processes (per the data flow below). No further administration is needed.

Running costs for several thousand requests / month were estimated to be about $5.62 / month, with minimum charges for API Gateway accounting for much of the cost. Further info can be found in the ARB documentation for the project.

## TODO

- Uncomment / test push step in serverless.yml
- Final testing with live data

## Data flow

	![sfcc data flow diagram](/images/sfcc-requests-data-flow.png)

## Setup
The core of the application (including the webapp, lambdas, API gateway, and DynamoDB table) is deployed with a single command via the Serverless Framework- a versatile, cloud-agnostic framework that, when configured to use AWS, works as a wrapper for CloudFormation templates. 

The ECS task that handles the SFCC-CI commands (based on requests and updated status taken from DynamoDB) must be deployed separately. Additional setup for security compliance includes setting up the webapp for HTTPS (DNS handling, certificate provisioning, and a CloudFront distribution for HTTPS), requesting that Cloud Engineering set up an Okta group to access the webapp, and creating the SFCC-CI credentials in AWS Secrets Manager.

### Application Core Setup Steps
1. Clone this repo to a local directory.
2. Ensure that your local version of NodeJS is up-to-date (https://nodejs.org/en/download/)
3. Run `npm install` in the cloned directory.
4. Get or create an access key and secret for a least-provisioned serverless user in the target AWS account.  
5. Setup credentials for Serverless to deploy to AWS. I find it easiest to create a named profile in your ~/.aws/credentials file like this: 
`[serverlessDeploy]
aws_access_key_id=***************
aws_secret_access_key=***************
region=us-east-1`
Then, any time you need these credentials or want to deploy, just run `export AWS_PROFILE="serverlessDeploy"` first.
Other ways of configuring access can be found here: https://serverless.com/framework/docs/providers/aws/guide/credentials/
6. Deploy locally using `npm dev` (useful for testing changes to DynamoDB query lambdas and routes) or to the target AWS account using `sls deploy`. 

Other useful serverless (sls) commands include:
- `sls info` : see details of your live deployment
- `sls s3deploy` : deploy webapp bucket assets only
- `sls deploy function --f <function handler name>` : deploy one lambda function only

### ECS Task Setup Steps
1. Navigate to ECR in the target AWS account and create a new repository.
2. Copy / paste the entire repository name (including the path, e.g. ############.dkr.ecr.us-east-1.amazonaws.com/sfcc-requests) into the ecs/Makefile file whereever you see <ENDPOINT>
3. Inside the ECS directory:
- Build an image from the Dockerfile: `docker build -t sfcc-ci:Dockerfile -f Dockerfile .`
- Run `make` : this will tag and upload the image to ECR.
4. Create the cluster and task definition for the resource in ECS, then set up a scheduled task to run every hour: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/scheduled_tasks.html
  
Note: the heart of the ECS task is the `bulkProvision.sh` - the Dockerfile merely sets up the dependencies. Make any needed changes in this file.

### Additional Setup Tasks
1. Once the webapp bucket is live and populated with files, do these steps to move the webapp to a friendlier https URL.
- Create a new CNAME DNS entry in Route53 under a currently owned domain (e.g. sfcc-requests.infrastructure.awshbc.io in hbc-infrastructure)
- Create a certificate in AWS ACM for the URL you created in step 1 (or Venafi, depending on security requirements).
- Create a Cloudfront distribution referencing the webapp bucket name as origin and using the cert created in step 2.
2. The webapp is configured to restrict access to a specific Okta group. Once DNS, Cloudfront, and certificates are set up, work with Cloud Engineering to provision a Okta access group and add members.
3. The email sender must be configured and verified in AWS Simple Email Service (SES). After which, be sure to update the serverless.yml file under the provider:environment:SRC_EMAIL parameter. Double check the SES entry in the serverless.yml file under `iamRoleStatements` as well.
4. An email distribution list must be set up with the access requests team. It's important to limit this list to users privileged to upload user request files. Once this email has been set up, be sure to update the serverless.yml file under the provider:environment:DEST_EMAIL parameter.
5. The following variables have to be set up in AWS SecretsManager under the `prod/sfcc-requests` entry:
- ping:	pong <keep this set to `pong`>
- SFCC_CI_KEY:	<account manager client ID)
- SFCC_CI_SECRET:	<account manager secret)
- SFCC_CI_USER:	<sfcc-username (this is separate from above and must be provisioned for appropriate instance access: hbcsfcccsr@hbc.com by default)
- SFCC_CI_PASS: <sfcc-username password>
- API_ENDPOINT_URL:	<get the endpoint (including /rqsts) from `sls info`>
- API_KEY	<get the key from `sls info`>
6. Copy the SecretsManager SecretARN from step 5, and modify the ECSTaskExecutionRole with the following inline policy: 
  `{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "secretsmanager:GetSecretValue"
            ],
            "Resource": [
                <PUT SECRETS MANAGER ARN HERE>"
            ]
        }
    ]
}`
