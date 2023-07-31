local props = import '.properties.libsonnet';
local project = props.project; // no spaces
local stage = props.stage; // TEST, or PROD, etc
local account = props.account;
local region = props.region;
local bucketName = stage + '-' + project + '-aws-logs-' + account + '-' + region;
local bucketPrefix = 's3://' + bucketName;
local unit = 'Twelfths';
local sourceVersion = '20230705';
local sinkVersion = '20230705';

// the S3 URI referencing the access logs
local accessLogs = props.logs;

{
  project: {
    name: 'AwsLogs',
    version: sourceVersion + '-00',
  },
  placement: {
    stage: stage,
    provider: 'aws',
    account: account,
    region: region,
  },
  resources: [
    {
      type: 'aws:core:s3Bucket',
      name: 'bucket',
      bucketName: bucketName,
    },
    {
      type: 'aws:core:computeEnvironment',
      name: 'simple',
      computeEnvironmentName: 'simpleComputeEnvironment'
    },
  ],
  boundaries: [
    {
      type: 'aws:core:s3PutListenerBoundary',
      name: 'IngressListener',
      eventArrival: 'frequent',
      dataset: {
        name: 's3-access-logs',
        version: sourceVersion,
        pathURI: accessLogs
      },
      // filename format: 2019-06-12-04-17-02-1CA30D5A9C018088
      lotUnit: unit,
      runtimeProps:{
        memorySizeMB: 512
      }
    },
  ],
  arcs: [
    {
      exclude: false,
      type: 'aws:core:batchExecArc',
      name: 'convertParquet',
      sources: {
        main: {
          name: 's3-access-logs',
          version: sourceVersion,
        pathURI: accessLogs
        },
      },
      sinks: {
        main: {
          name: 'access-logs',
          version: sinkVersion,
          pathURI: bucketPrefix + '/access-logs/',
        },
      },
      workload: {
        computeEnvironmentRef: 'simple',
        imagePath: 'app',
        command: [
          './tess-ingest.sh',
          '--lot',
          '$.arcNotifyEvent.lot',
          '--manifest',
          '$.arcNotifyEvent.manifest',
        ],
      },
    },
  ],
}
