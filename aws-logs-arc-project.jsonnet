local props = import '.properties.libsonnet';
local version = '20230817';
local project = props.project;  // no spaces
local stage = props.stage;  // TEST, or PROD, etc
local account = props.account;
local region = props.region;
local bucketName = stage + '-' + project + '-aws-logs-' + account + '-' + region;
local bucketPrefix = 's3://' + bucketName;

local sourceVersion = version;
local sinkVersion = version;
local databaseName = stage + '-' + project + '-aws-logs';
local tableName = stage + '-' + project + '-' + sinkVersion + '-aws-logs';
local unit = 'Twelfths';

// the S3 URI referencing the access logs
local accessLogs = props.logs;

{
  project: {
    name: 'AwsLogs',
    version: version + '-00',
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
      computeEnvironmentName: 'simpleComputeEnvironment',
    },
    {
      type: 'aws:core:glueDatabase',
      name: 'database',
      databaseName: databaseName,
    },
    {
      type: 'aws:core:glueTable',
      name: 'table',
      databaseRef: 'database',
      tableName: tableName,
      pathURI: bucketPrefix + '/access-logs/',
      schema: {
        columns: [
          {
            name: 'bucketOwner',
            type: 'string',
          },
          {
            name: 'bucket',
            type: 'string',
          },
          {
            name: 'time',
            type: 'timestamp',
          },
          {
            name: 'remoteIP',
            type: 'string',
          },
          {
            name: 'requester',
            type: 'string',
          },
          {
            name: 'requestID',
            type: 'string',
          },
          {
            name: 'operation',
            type: 'string',
          },
          {
            name: 'key',
            type: 'string',
          },
          {
            name: 'requestURI',
            type: 'string',
          },
          {
            name: 'httpStatus',
            type: 'int',
          },
          {
            name: 'errorCode',
            type: 'string',
          },
          {
            name: 'bytesSent',
            type: 'bigint',
          },
          {
            name: 'objectSize',
            type: 'bigint',
          },
          {
            name: 'totalTime',
            type: 'bigint',
          },
          {
            name: 'turnAroundTime',
            type: 'bigint',
          },
          {
            name: 'referrer',
            type: 'string',
          },
          {
            name: 'userAgent',
            type: 'string',
          },
          {
            name: 'versionID',
            type: 'string',
          },
          {
            name: 'hostId',
            type: 'string',
          },
          {
            name: 'signatureVersion',
            type: 'string',
          },
          {
            name: 'cipherSuite',
            type: 'string',
          },
          {
            name: 'authenticationType',
            type: 'string',
          },
          {
            name: 'hostHeader',
            type: 'string',
          },
          {
            name: 'tlsVersion',
            type: 'string',
          },
          {
            name: 'accessPointArn',
            type: 'string',
          },
          {
            name: 'aclRequired',
            type: 'string',
          },
        ],
        partitions: [
          {
            name: 'time_ymd',
            type: 'string',
          },
          {
            name: 'lot',
            type: 'string',
          },
        ],
        dataFormat: 'parquet',
      },
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
        pathURI: accessLogs,
      },
      lotUnit: unit,
      runtimeProps: {
        memorySizeMB: 512,
      },
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
        },
      },
      sinks: {
        main: {
          name: 'access-logs-parquet',
          version: sinkVersion,
          pathURI: bucketPrefix + '/s3-access-logs-parquet/',
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
    {
      type: 'aws:core:glueAddPartitionsArc',
      name: 'addPartitions',
      sources: {
        main: {
          name: 'access-logs-parquet',
          version: sinkVersion,
        },
      },
      sinks: {
        main: {
          name: 'partitions',
          version: sinkVersion,
          pathURI: 'glue:///'+databaseName+'/'+tableName,
        },
      },
    },
    ]
}
