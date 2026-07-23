// AWS config — credentials come from the environment, never from source.
// In the cluster these are injected by External Secrets Operator from
// AWS Secrets Manager.
const awsConfig = {
  region: process.env.AWS_REGION || 'eu-west-2',
  accessKeyId: process.env.AWS_ACCESS_KEY_ID,
  secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY
};

module.exports = awsConfig;
