

module KinesisSupervisor
  
  def supervisor_thread()
    until @stop_flag do
      active_shard_ids = get_shard_ids()
      update_maping(active_shard_ids)
      sleep(@load_shard_interval)
    end
  end

  def update_maping(active_shard_ids)
    active_shard_ids.each do |shard_id|
      if @map.has_key?(shard_id)
        if @map[shard_id].status.nil?
          $log.error "Thread dead => shard : #{shard_id}"
          thread_kill(shard_id)
        elsif @thread_stop_map[shard_id]
          thread_kill(shard_id)
        else
          next
        end
      else
        @thread_stop_map[shard_id] = false
        t = Thread.new(shard_id, &method(:load_records_thread))
        @map[shard_id] = t
      end
    end
    
    map_shard_ids = @map.keys
    map_shard_ids.each do |map_shard_id|
      unless active_shard_ids.include?(map_shard_id)
        @thread_stop_map[shard_id] = true
        thread_kill(map_shard_id)
      end
    end
  end
  
  def thread_kill(shard_id)
    $log.info "Thread killing => shard : #{shard_id}"
    @map[shard_id].join
    @dead_thread << shard_id
    @thread_stop_map.delete(shard_id)
    @map.delete(shard_id)
  end
  
  def get_shard_ids()
    active_shard_ids = []
    shards = @client.describe_stream(stream_name: @stream_name).stream_description.shards
    shards.each do |shard|
      if @describe_shard & !@describe_use_shards.include?(shard.shard_id)
        next
      end
      
      unless @dead_thread.include?(shard.shard_id)
        active_shard_ids << shard.shard_id
      end
    end
    
    active_shard_ids
  rescue => e
    $log.error "get_shard_ids : #{e.message}"
  end
end



