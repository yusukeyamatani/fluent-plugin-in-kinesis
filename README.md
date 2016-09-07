# Fluent::Plugin::InKinesis

##Overview
  * This plugin retrieves records from Amazon Kinesis.
  
  * 1 thread is used for each shard; record retrieval occurs in parallel.
  
  * Number of threads is automatically adjusted to match number of shards.
  
  * Sequence numbers from each shard are saved.
  
  * Conforms to default fluent format.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'fluent-plugin-in-kinesis'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install fluent-plugin-in-kinesis


##Configuration
### `type`
  Use the word 'kinesis'.

### `stream_name`
  Name of the stream to put data.
 
### `aws_key_id`
  AWS access key id.
 
### `aws_sec_key`
  AWS secret key.
     
### `region`
  AWS region of your stream.
  It should be in form like "us-east-1", "us-west-2".
  
  Refer to [Regions and Endpoints in AWS General Reference](http://docs.aws.amazon.com/general/latest/gr/rande.html#ak_region)
  
  for supported regions.

### `profile` & `credentials_path`
  Set as needed to specify credentials file.
  
### `stream_name`
  Name of the stream to put data.
 
### `state_dir_path`
  Directory to save sequence number data.
  Save file will be created in specified directory.
  
### `use_base64`
  Set if BASE64 decode is necessary.
 
### `use_gunzip`
  Set if GZip decompress is necessary.

### `load_records_limit`
  The maximum number of records to return. 
  
  Valid range: Minimum value of 1. Maximum value of 10000.
 
### `load_record_interval`
  Frequency of record retrieval.
  
  Value is in seconds.
 
### `load_shard_interval`
  Frequency of shard state checks.
  
  Value is in seconds.
  
### `format`
  Parse strings in log.
  fluentd default parser.
  
### `describe_shard`
  Set to manually specify target Kinesis shards (see below). 
   
### `describe_use_shards`
  Specify the shards to be used (see below).
 
##Configuration examples
    <source>
    
      type kinesis
      
      stream_name YOUR_STREAM_NAME
      
      aws_key_id YOUR_AWS_ACCESS_KEY
      
      aws_sec_key YOUR_SECRET_KEY
    
      region ap-northeast-1
      
      load_records_limit 1000
      
      load_shard_interval 10
      
      load_record_interval 2
      
      tag target.log
      
      state_dir_path /tmp/kinesis/save_file
      
      use_base64 true
      
      format json
      
    </source>
    
##Using describe_shard
When describe_shard is specified, target shards are manually set using describe_use_shards parameter.

    <source>
    
      type kinesis
      
      stream_name YOUR_STREAM_NAME
      
      aws_key_id YOUR_AWS_ACCESS_KEY
      
      aws_sec_key YOUR_SECRET_KEY
    
      region ap-northeast-1
      
      load_records_limit 1000
      
      load_shard_interval 10
      
      load_record_interval 2
      
      tag target.log
      
      state_dir_path /tmp/kinesis/save_file
      
      use_base64 true
      
      format json
      
      describe_shard true
      
      describe_use_shards  ["shardId-000000000000", "shardId-000000000002"]
      
    </source>
    
## Related Resources

* [Amazon Kinesis Developer Guide](http://docs.aws.amazon.com/kinesis/latest/dev/introduction.html)      
