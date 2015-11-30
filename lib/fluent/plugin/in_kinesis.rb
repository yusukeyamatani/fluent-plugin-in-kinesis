# Copyright 2014 Amazon.com, Inc. or its affiliates. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License"). You
# may not use this file except in compliance with the License. A copy of
# the License is located at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# or in the "license" file accompanying this file. This file is
# distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF
# ANY KIND, either express or implied. See the License for the specific
# language governing permissions and limitations under the License.

require 'aws-sdk-core'
require 'multi_json'
require 'yajl'
require 'logger'
require 'securerandom'
require 'base64'
require 'fluent/plugin/thread_supervisor'
require 'fluent/plugin/kinesis_shard'


module FluentPluginKinesis
  class InputFilter < Fluent::Input
    include Fluent::DetachMultiProcessMixin
    include KinesisSupervisor
    include KinesisShard

    USER_AGENT_NAME = 'fluent-plugin-kinesis-input-filter'

    Fluent::Plugin.register_input("kinesis", self)
    
    config_param :tag,                    :string, :default => nil
    config_param :state_dir_path,         :string, :default => nil

    config_param :aws_key_id,             :string, :default => nil, :secret => true
    config_param :aws_sec_key,            :string, :default => nil, :secret => true
    config_param :region,                 :string, :default => nil
    config_param :profile,                :string, :default => nil
    config_param :credentials_path,       :string, :default => nil
    config_param :stream_name,            :string
    
    config_param :use_base64,             :bool,    :default => false,  :secret => true
    config_param :load_records_limit,     :integer, :default => 10000,  :secret => true
    config_param :load_record_interval,   :integer, :default => 1,      :secret => true #=> sec
    config_param :load_shard_interval,    :integer, :default => 1,      :secret => true #=> sec
    config_param :format,                 :string,  :default => 'none', :secret => true
    config_param :describe_shard,         :bool,    :default => false,  :secret => true
    config_param :describe_use_shards,    :array,   :default => [],     :secret => true
    
    def configure(conf)
      super
      
      unless @state_dir_path
        $log.warn "'state_dir_path PATH' parameter is not set to a 'kinesis' source."
        $log.warn "this parameter is highly recommended to save the last rows to resume tailing."
      end
      @parser = Fluent::Plugin.new_parser(conf['format'])
      @parser.configure(conf)

      @map = {} #=> Thread Object management
      @thread_stop_map = {} #=> Thread stop flag management
      @dead_thread=[] #=> Dead Thread management
    end
    
    def start
      detach_multi_process do
        super
        @stop_flag = false
        load_client
        Thread.new(&method(:supervisor_thread))
      end
    end
    
    def shutdown
      @stop_flag = true
    end

    def load_client
      user_agent_suffix = "#{USER_AGENT_NAME}/#{FluentPluginKinesis::VERSION}"
      
      options = {
        user_agent_suffix: user_agent_suffix
      }
      
      if @region
        options[:region] = @region
      end
    
      if @aws_key_id && @aws_sec_key
        options.update(
          access_key_id: @aws_key_id,
          secret_access_key: @aws_sec_key,
        )
      elsif @profile
        credentials_opts = {:profile_name => @profile}
        credentials_opts[:path] = @credentials_path if @credentials_path
        credentials = Aws::SharedCredentials.new(credentials_opts)
        options[:credentials] = credentials
      end
      
      @client = Aws::Kinesis::Client.new(options)
    end
  end
end
