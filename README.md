# RakeCloudspin

This library of Rake tasks is a prototype for an infrastructure project build framework. It is intended as a basis for exploring project structures, conventions, and functionality, but is not currently in a stable state. Feel free to copy and use it, but be prepared to extend and modify it in order to make it usable, and be aware that there isn't likely to be a clean path to upgrade your projects as this thing evolves.


## What's the point of this?

Currently, most people and teams managing infrastructure with tools such as Terraform, CloudFormation, etc. define their own project structures, and write their own wrapper scripts to run that tool and associated tasks. Essentially, each project is a unique snowflake.

The goal for cloudspin is to evolve a common structure and build tooling for infrastructure projects, focused on the lifecycle of "[stacks](http://infrastructure-as-code.com/patterns/2018/03/28/defining-stacks.html)" - infrastructure elements provisioned on dynamic infrastructure such as IaaS clouds.

Our hypothesis is that, with a common project structure and tooling:

- Teams will spend less time building and maintaining snowflake build systems,
- New team members can more quickly get up to speed when joining an infrastructure project,
- People can create and share tools and scripts that work with the common structure, creating an ecosystem,
- People can create and share infrastructure code for running various software and services, creating a community library.


## Philosophy

- [Convention over configuration](https://en.wikipedia.org/wiki/Convention_over_configuration).
-- The tool should discover elements of the project based on folder structure
-- A given configuration value should be set in a single place
-- Implies a highly "[opinionated](https://medium.com/@stueccles/the-rise-of-opinionated-software-ca1ba0140d5b)" approach
- Encourage good agile engineering practices for the infrastructure code
-- Writing and running tests should be a natural thing
-- Building and using [infrastructure pipelines](http://infrastructure-as-code.com/book/2017/08/02/environment-pipeline.html) should be a natural thing
- Support evolutionary architecture
-- Loose coupling of infrastructure elements
- Empower developers / users of infrastructure


# Structure of a project

Cloudspin is used to manage Terraform projects for AWS infrastructure. It uses Ruby rake. There are some example projects, [simple-stack](https://github.com/cloudspinners/spin-simple-stack) is a simple example.

Each cloudspin project represents a **Component**. A Component is a collection of stacks (as defined above) that together provide a useful service of some sort. Each instance of a service provisioned in the cloud is a *Deployment*. You may have Deployments for environments, e.g. a QA deployment, Staging deployment, Production deployment, etc. You might also have multiple production deployments, for example you might provision a deployment for each of your customers.

## Project structure

Your component project should have the following basic structure:

```
COMPONENT-ROOT
  |-- deployment/
  |-- delivery/
  |-- component.yaml
  |-- component-local.yaml
  |-- Rakefile
  └-- go*
```

## Deployment stacks

The `COMPONENT-ROOT/deployment/` folder has a subfolder for each stack that is provisioned for a deployment of the component.

```
COMPONENT-ROOT
  └-- deployment/
      |-- networking/
      |-- cluster/
      └-- database/
```

In this example, we have one stack for networking (VPC, subnets, etc.), one for a cluster (ECS cluster), and a third for a database (RDS instance).


## Stack folders

Each stack has the following structure:

```
deployment/
└── networking/
    ├── stack.yaml
    ├── infra/
    │   ├── backend.tf
    │   ├── bastion.tf
    │   ├── dns.tf
    │   ├── outputs.tf
    │   ├── subnets.tf
    │   ├── variables.tf
    │   └── vpc.tf
    └── tests/
        └── inspec/
            ├── controls/
            │   ├── bastion.rb
            │   ├── subnets.rb
            │   └── vpc.rb
            └── inspec.yml
```

See below for details on the `stack.yaml` file.


## Delivery stacks

The `COMPONENT-ROOT/delivery/` folder can have a number of subfolders, each representing a stack that provisions things needed for delivery. Each of these is typically provisioned only once per component. Examples include pipeline definitions, and artefact repository configurations.

```bash
delivery/
└── aws-pipeline
    ├── infra
    │   ├── artefact_bucket.tf
    │   ├── backend.tf
    │   ├── outputs.tf
    │   ├── packaging_codebuild_stage.tf
    │   ├── pipeline.tf
    │   ├── prodapply_codebuild_stage.tf
    │   ├── testapply_codebuild_stage.tf
    │   └── variables.tf
    └── stack.yaml
```


# Setting up a cloudspin project

These are the steps to set up a new cloudspin infrastructure project:

1. Import the `rake_cloudspin` gem.
2. Create component configuration
3. Create one or more deployment and delivery stacks


## Adding the rake_cloudspin gem to your project

### Install the gem

Add this line to your application's Gemfile:

```ruby
gem 'rake_cloudspin', :git => 'https://github.com/cloudspinners/rake_cloudspin.git'
```

    (TODO: Publish releases of this gem properly)

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install rake_cloudspin


## Import the library into your Rakefile

Here is an example Rakefile:

```ruby
require 'rake/clean'
require 'rake_cloudspin'

CLEAN.include('build')
CLEAN.include('work')
CLEAN.include('dist')
CLOBBER.include('vendor')

task :default => [ :plan ]

RakeCloudspin.define_tasks

```

Many of our example projects use a `go` script as a wrapper to run rake. This makes sure prerequisites are installed, including the gems. See [example go script](https://raw.githubusercontent.com/cloudspinners/spin-simple-stack/master/go) from the spin-simple-stack project.


## Component configuration (component.yaml)

There are two files used to configure your Component, both of which live at the root of the project, alongside the Rakefile. 

* `component.yaml` has the default configuration options, and is intended to be checked into source control with the rest of your project.
* `component-local.yaml` allows you to override configuration options when you run cloudspin locally.  This is intended to be excluded from source control, so each person who works on the project can have their own custom options.

Here is an example, again from the *simpleweb* project, of a `component.yaml` file.


```yaml
---
estate: cloudspin
component: simple
region: eu-west-1
```

Some of these configuration variables are used for naming things, others are for configuring infrastructure.

- *estate* is an identifier that runs across all components, all deployments. It may be the name of the organisation, division, etc.
- *component* is the name of this component.
- *region* is the default region for deploying stacks.


Other variables are used to configure infrastructure, generally passed to Terraform code. The specific variables that are available in your component configuration will depend on your own project code. They will tend to be driven by the `stack.yaml` files for the deployment and delivery stacks in your project.


# Stack configuration (stack.yaml)

Each stack in `deployment/*` and `delivery/*` must have a `stack.yaml` file in its root. Otherwise, the cloudspin build won't recognize the stack.

Here's another example from simpleweb.

```yaml
---
vars:
  region: "%{hiera('region')}"
  component: "%{hiera('component')}"
  deployment_identifier: "%{hiera('deployment_identifier')}"
  estate: "%{hiera('estate')}"
  service: "%{hiera('service')}"
  base_dns_domain: "%{hiera('domain_name')}"

  webserver_ssh_public_key_path: "../ssh_keys/webserver_ssh_key.pub"
  bastion_ssh_public_key_path: "../ssh_keys/bastion_ssh_key.pub"
  allowed_cidr: "%{hiera('my_ip')}/32"

ssh_keys:
  - webserver_ssh_key
  - bastion_ssh_key

state:
  type: s3
  scope: deployment
```


## Terraform variables

The `vars:` section of the `stack.yaml` file defines variables that are passed to terraform. See the [terraform configuration documentation](https://www.terraform.io/docs/configuration/variables.html) for how these are used. Cloudspin passes the variables defined in the `stack.yaml` file to the terraform command on the commandline.

The values in the configuration file can include values from component variables or other variables set by cloudspin. Cloudspin uses hiera to do this, so the syntax is:

```
"%{hiera('VARIABLE_NAME')}"
```

## SSH keys

Some infrastructure needs ssh keys, for example keypairs used by EC2 instances. Cloudspin can manage these for you if your stack.yaml file has an `ssh_key` section as below:

```yaml
ssh_keys:
  - webserver_ssh_key
  - bastion_ssh_key
```

Each keyname listed in here represents an ssh public/private key pair required by the stack. When run the first time, cloudspin will generate an ssh key pair, and upload both keys to the AWS SSM Parameter Store as values encrypted with KMS. On later runs, Cloudspin will retrieve the existing keys and use those as appropriate.

A separate keypair is used for each deployment of the given stack. So keys are not shared between components, stacks, or environments. They don't need to be checked into version control. Ephemeral test instances of the stack will have keys automatically generated, and these will be destroyed afterwards along with the environment.

The keys are written or downloaded to the local filesystem, so they can be passed to Terraform. In the simpleweb example, two keypairs are generated, and the location of their public keys are passed as vars:

```yaml
vars:
  ...
  webserver_ssh_public_key_path: "../ssh_keys/webserver_ssh_key.pub"
  bastion_ssh_public_key_path: "../ssh_keys/bastion_ssh_key.pub"
```

TODO: The location of the keyfiles should be set in variables by cloudspin, so you don't need to know the location.

If you don't want cloudspin to generate ssh keys for you, don't list the keys under the `ssh_keys` section of the `stack.yaml` file, and simply give the path to the keyfile you want to use in the `vars` section.


# Running cloudspin tasks

You run cloudspin either by running `rake`, or using a wrapper like the `go` script. Our examples assume the `go` script is used.

## ${deployment_identifier}

You must set a unique `deployment_identifier` value for each unique instance of your component. You can set a default in your `component.yaml` file, although this is dangerous - it will be easy for someone to forget to set the value in some other way, and accidentally make changes to that instance. So if you do this, make sure the named environment is one you don't care about accidentally breaking.

    Your **production** environment should of course NEVER be the default `deployment_identifier`.

It's common for each person to set their own `deployment_identifier` in `component-local.yaml`, so they can run cloudspin locally to create a personal "sandbox" instance to work on. It's useful to have a naming convention for this, so it's easy to manage instances, e.g. to destroy unneeded developer instances.

Most non-sandbox instances of the component will be provisioned and managed by the pipeline. In these cases, the pipeline configuration will set the `deployment_identifier` value.

The most common way to set the `deployment_identifier` is with an environment variable:

```bash
DEPLOYMENT_IDENTIFIER=mytest ./go provision
```

## Cloudspin tasks

You can see the tasks by running `rake -T` or `./go -T`.

The main lifecycle tasks are:

- plan: Show what Terraform will do to the existing component instance
- provision: Create or update all deployment stacks in the instance
- test: Run all component tests against the instance
- destroy: Completely destroy all deployment stacks in the instance
- vars: Show the Terraform variables that will be set by cloudspin

Each of these commands can be run to affect all deployment stacks in the instance. They will not affect the delivery stacks.

It's also possible to run these commands for a specific deployment stack (or delivery stack):

```bash
rake deployment:simpleweb:plan         # Plan deployment-simpleweb using terraform
rake deployment:simpleweb:provision    # Provision deployment-simpleweb using terraform
rake deployment:simpleweb:test         # Run inspec tests
rake deployment:simpleweb:destroy      # Destroy deployment-simpleweb using terraform
rake deployment:simpleweb:vars         # Show terraform variables for stack 'simpleweb'
```

Replace `simpleweb` with the name of a different stack as appropriate. For delivery stacks, the syntax is to `rake delivery:STACKNAME:task`.


# Runtime details

What's the `work` folder about?


# General info


## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/rake_cloudspin.


## Components

This is largely based on code from [Infrablocks](https://github.com/infrablocks), and uses some components, including [rake_terraform](https://github.com/infrablocks/rake_terraform).

