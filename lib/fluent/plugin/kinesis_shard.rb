

module KinesisShard
  
  def load_records_thread(shard_id)
    begin
      state_store = @state_dir_path.nil? ? MemoryStateStore.new : StateStore.new(@state_dir_path, shard_id)
    rescue => e
      $log.warn "does not StateStore !!: #{e.message}"
      state_store = MemoryStateStore.new
    end

    last_sequence_number = state_store.load_sequence_number
    shard_iterator_info = get_shard_iterator_info(shard_id, last_sequence_number)
    shard_iterator = shard_iterator_info.shard_iterator
    
    while !@stop_flag && !@thread_stop_map[shard_id] do
      begin
        records_info = @client.get_records(shard_iterator: shard_iterator, limit: @load_records_limit)
      rescue => e
        $log.error "get record Error: #{e.message}"
        re_shard_iterator_info = get_shard_iterator_info(shard_id, last_sequence_number)
        records_info = @client.get_records(
          shard_iterator: re_shard_iterator_info.shard_iterator, limit: @load_records_limit/10)
      end
      
      if records_info.next_shard_iterator.nil?
        @thread_stop_map[shard_id] = true
        break
      end
      
      data = records_info.records.map(&:data)
      emit_records(data, shard_id)
      tmp_last_sequence_number = sequence(records_info)
      
      unless tmp_last_sequence_number.nil?
        state_store.update(tmp_last_sequence_number)
        last_sequence_number = tmp_last_sequence_number
      end

      shard_iterator = records_info.next_shard_iterator
      sleep(@load_record_interval)
    end
  end
    
  def get_shard_iterator_info(shard_id='', last_sequence_number='')
    if last_sequence_number.empty?
      shard_iterator_info = @client.get_shard_iterator(
        stream_name: @stream_name, shard_id: shard_id, shard_iterator_type: 'TRIM_HORIZON')
    else
      shard_iterator_info = @client.get_shard_iterator(
        stream_name: @stream_name, shard_id: shard_id, shard_iterator_type: 'AFTER_SEQUENCE_NUMBER', starting_sequence_number: last_sequence_number)
    end
  rescue => e
    $log.warn "does not AFTER_SEQUENCE_NUMBER : #{e.message}"
    shard_iterator_info = @client.get_shard_iterator(
      stream_name: @stream_name, shard_id: shard_id, shard_iterator_type: 'TRIM_HORIZON')
  end

  def emit_records(data, shard_id)
    me = Fluent::MultiEventStream.new
    data.each do |d|
      if @use_base64
        d = Base64.decode64(d)
      end
      
      time, record = @parser.parse(d)
      if record.nil? || record.empty?
        $log.warn "format error :=> record #{time} : #{d}"
      else
        me.add(time, record)
      end
    end
    
    unless me.empty?
      router.emit_stream(@tag, me)
    end
  end

  def sequence(records_info)
    sequence_number_list = records_info.records.map(&:sequence_number)
    if sequence_number_list.length > 0
      sequence_number = records_info.records.map(&:sequence_number)[-1]
    else
      sequence_number = nil
    end
  end
  
  
  class StateStore
    def initialize(dir_path, shard_id)
      
      unless Dir.exist?(dir_path)
        begin
          FileUtils.mkdir_p(dir_path)
        rescue => e
          raise "does not make a directory : #{e.message}"
        end
      end
      @path = "#{dir_path}/last_recode_#{shard_id}.json"
      
      if File.exists?(@path)
        begin
          load_json_file
        rescue => e
          $log.warn "load_json_file: #{e.message}"
        end
      end
      
      if @data.nil?
        @data = {'last_sequence_number' => ''}
      end
      
      unless @data.is_a?(Hash)
        raise "state_file on #{@path.inspect} is invalid"
      end
    end
    
    def load_json_file()
      open(@path) do |io|
        @data =Yajl.load(io)
      end
    end
    
    def load_sequence_number
      @data['last_sequence_number']
    end
    
    def update(sequence_number)
      @data['last_sequence_number'] = sequence_number
      open(@path, "w") do |io|
        Yajl.dump(@data, io)
      end
    end
  end
    
  class MemoryStateStore
    
    def initialize
      @data = {'last_sequence_number' => ''}
    end
    
    def load_sequence_number
      @data['last_sequence_number']
    end
    
    def update(sequence_number)
      @data['last_sequence_number'] = sequence_number
    end
  end
end

