### Building and running your application

When you're ready, start your application by running:
`docker compose up --build`.

### Deploying your application to the cloud

First, build your image, e.g.: `docker build -t myapp .`.
If your cloud uses a different CPU architecture than your development
machine (e.g., you are on a Mac M1 and your cloud provider is amd64),
you'll want to build the image for that platform, e.g.:
`docker build --platform=linux/amd64 -t myapp .`.

Then, push it to your registry, e.g. `docker push myregistry.com/myapp`.

Consult Docker's [getting started](https://docs.docker.com/go/get-started-sharing/)
docs for more detail on building and pushing.

# IaC

Tutorial: https://developer.hashicorp.com/terraform/tutorials/oci-get-started
https://registry.terraform.io/providers/oracle/oci/latest/docs
https://registry.terraform.io/providers/oracle/oci/latest/docs/resources/functions_function

To list compartments: `oci iam compartment list --config-file /Users/[your username]]/.oci/config --profile DEFAULT --auth security_token --compartment-id-in-subtree true`

## Deploy Docker Image

docker login lhr.ocir.io
docker build --platform=linux/amd64 -t lhr.ocir.io/[repositoryNamespace]/ftp-bridge:0.1.0 .
docker push lhr.ocir.io/[repositoryNamespace]/ftp-bridge:0.1.0

(you may want to move the docker image to correct compartment if this is your first time pushing)

...and then update main.tf

## Deploy Infrastructure

oci session authenticate (Then choose - 70, then type DEFAULT)
oci session authenticate (Then choose - 70, then type FTP-BRIDGE-TF)
oci session refresh --profile FTP-BRIDGE-TF     -- to refresh the auth token

terraform apply

## Create 'terraform.tfvars' file as follows

``
compartment_id  = "<your_compartment_OCID_here>"
region          = "uk-london-1"
``

# fn

``
fn invoke ftp-bridge-application ftp-bridge-function
``