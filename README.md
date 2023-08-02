# Convert AWS S3 Access Logs to Parquet

This repo provides a sample pipeline using [Clusterless](https://github.com/ClusterlessHQ/clusterless) and [Tessellate](https://github.com/ClusterlessHQ/tessellate) to convert native [AWS S3 access logs](https://docs.aws.amazon.com/AmazonS3/latest/userguide/LogFormat.html) into [Apache Parquet](https://parquet.apache.org) files for use with tools like AWS Athena (or any other log format with minor edits).

See https://github.com/ClusterlessHQ/clusterless-aws-examples for simpler examples that should be run first to familiarize yourself with Clusterless.

The code in this repo is free to fork, copy, and use under the <u>MIT License</u>.

## Overview

This example expects that an existing bucket in your account has [server access logging enabled](https://docs.aws.amazon.com/AmazonS3/latest/userguide/ServerLogs.html). The location of the access logs will need to be added to the `.properties.libsonnet` file (see below).

The project file, `aws-logs-arc-project.jsonnet`, when deployed, will create three core resources. 

A new AWS S3 bucket to store the result [dataset](https://docs.clusterless.io/guide/wip-1.0/concepts/dataset.html) as Parquet files. A [Clusterless Boundary](https://docs.clusterless.io/guide/wip-1.0/concepts/boundary.html)  (a Clusterless provided AWS Lambda), to listen to the logging location for new log files in order to push availability events. And a [Clusterless Arc](https://docs.clusterless.io/guide/wip-1.0/concepts/arc.html) to listen for new log availability events and convert the text files into Parquet. 

The arc [workload](https://docs.clusterless.io/guide/wip-1.0/concepts/workload.html) is simply a Tessellate instance running as a Docker image in AWS Fargate. When the arc completes, a new availability event is published allowing for other arcs to participate in the pipeline.

Every time AWS drops a new log file in the access logging bucket, the boundary is notified by AWS. The boundary in turn, every 5 minutes, creates a manifest of the newly arrived file(s) and publishes an availability event for the access log dataset.

The arc listens for new arrivals of data from the access log dataset and runs the Tessellate workload. On completion, a new dataset availability event is published.

If no data arrives in the access logging bucket, an event is still published every 5 minutes, but the manifest is marked as `empty`. This way it's clear the system is running, but there just happens to be no new data. The Tessellate arc still runs, but it in turn also publishes an empty manifest (a future version will short-circuit the workload and publish an empty manifest to reduce costs for). 

## Notes

This example relies on `jsonnet` to generate the JSON files that are piped into the `cls` command via `cls -p -`.

For this to work, `--approve` must be included in the `cls` command, which may seem a bit scary.

Alternatively, pipe the jsonnet output to a file and then run `cls` on the file without `--approve` to enable
manual approvals.

By editing `app/ingest.json`, this sample can trivially parse other log formats into Parquet. See the Tessellate documentation for more information.

## Running

Copy `.properties.libsonnet.template` to `.properties.libsonnet` and edit.

[Tessellate](https://github.com/ClusterlessHQ/tessellate) should also be installed locally to test the arc locally. Otherwise this step may be skipped.

Note that `.properties.libsonnet` is listed in the `.gitignore`file. If forking this project to use as a template for an actual deployment, remove the declaration from the ignore file so it can be maintained in your git repo.

### Bootstrap

The following command will initialize the AWS placement environment, if not already done so.

```shell
jsonnet bootstrap.jsonnet | jq -r '.[0]' | sh
```

### Verify

The following command will confirm the jsonnet file translates into a valid clusterless project file.

```shell
jsonnet aws-logs-arc-project.jsonnet | cls verify -p -
```

### Deploy the Boundary

The provided project file deploys both a boundary and an arc. We need to deploy the boundary first so we can locally test the arc.

```shell
jsonnet aws-logs-arc-project.jsonnet | cls deploy -p - --exclude-all-arcs --approve
```

Because we are piping the project file into `cls`, we must include the `--approve` option.

Note, this pipeline could have been split into multiple projects files, one with resources and boundaries, and another with arcs. For this example we are using one file.

After deployment, log into S3 to confirm new manifests are being created. They will be located in:

`s3://[STAGE]-clusterless-manifest-[ACCOUNT]-[REGION]/datasets/name=s3-access-logs/`

If manifests do not show up in a few minutes, confirm logs are being written to the given log path specified in the `.properties.libsonnet` file.

Once confirmed, check to see if the deployed boundary lambda is running successfully in the AWS Console.

### Test

Once manifests begin to arrive, copy a lot id that has a `state=complete` state and use it below:

```shell
jsonnet aws-logs-arc-project.jsonnet | cls local -p - --arc convertParquet --lot 20230717PT5M250 > local.sh
```

Run `local.sh` from the `app` directory:

```shell
chmod a+x local.sh
cd app
../local.sh
```

Currently this requires [Tessellate](https://github.com/ClusterlessHQ/tessellate) to be installed locally. A future version will build and execute the Docker image (which automatically downloads and install `tess` into the image).

It's encouraged to look inside the `local.sh` script that was generated. The shell script emulates how the resulting Docker image will be executed in AWS Batch.

To test an empty manifest, look for a lot with `state=empty`, if any.

```shell
jsonnet aws-logs-arc-project.jsonnet | cls local -p - --arc convertParquet --lot 20230731PT5M217 --manifest-state empty > local.sh
```

If `local.sh` completes with no errors, confirm a manifest file, for the given lot, was written to: 

`s3://[STAGE]-clusterless-manifest-[ACCOUNT]-[REGION]/datasets/name=access-logs/`

Look inside the manifest file to see where the data was written and confirm it is available.

Note that all the Clusterless metadata is human readable as JSON text files. And much of the important information is embedded in the file path and name (AWS S3 object key), for example, the state of the manifest file (`empty` or `complete`), or the state of the arc itself. So reporting on running arcs is as simple as a `aws s3 ls ...` command.

### Deploy

This command will deploy the declared project.

```shell
jsonnet aws-logs-arc-project.jsonnet | cls deploy -p - --approve
```

Actually, the whole project will be deployed, the resources and boundaries deployed above will be "updated", and the arc will be created.

Note that if changes are made to the project file, it can just be re-deployed for the updates to take effect. This allows a developer to incrementally deploy an updated arc workload for development when testing locally isn't possible.

### Destroy

This command will destroy the whole project and clean up what resources it can.

```shell
jsonnet aws-logs-arc-project.jsonnet | cls destroy -p - --approve
```

Note that frequently the AWS CDK creates resources that it will not delete on destroy, such as AWS CloudWatch Log Groups.