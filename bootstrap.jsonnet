local props = import '.properties.libsonnet';

[
  'cls bootstrap --providers aws --account ' + props.account + ' --region ' + props.region + ' --stage ' + props.stage + ' --approve',
]
