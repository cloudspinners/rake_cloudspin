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


# Component project

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

```
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


## Installation

Add this line to your application's Gemfile:

```ruby
gem 'rake_cloudspin', :git => 'https://github.com/cloudspinners/rake_cloudspin.git'
```

    (TODO: Publish releases of this gem properly)

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install rake_cloudspin


## Component conifguration


## Stack configuration



## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/rake_cloudspin.
