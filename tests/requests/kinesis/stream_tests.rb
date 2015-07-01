Shindo.tests('AWS::Kinesis | stream requests', ['aws', 'kinesis']) do
  @stream_id = 'fog-test-stream'

  tests('success') do
    wait_for_delete = lambda {
      begin
        while Fog::AWS[:kinesis].describe_stream("StreamName" => @stream_id).body["StreamDescription"]["StreamStatus"] == "DELETING"
          sleep 1
          print '.'
        end
      rescue Excon::Errors::BadRequest; end
    }

    # ensure we start from a clean slate
    if Fog::AWS[:kinesis].list_streams.body["StreamNames"].include?(@stream_id)
      wait_for_delete.call
      begin
        Fog::AWS[:kinesis].delete_stream("StreamName" => @stream_id)
        wait_for_delete.call
      rescue Excon::Errors::BadRequest; end
    end

    # optional keys are commented out
    @list_streams_format = {
      "HasMoreStreams" => Fog::Boolean,
      "StreamNames" => [
        String
      ]
    }

    @describe_stream_format = {
      "StreamDescription" => {
        "HasMoreShards" => Fog::Boolean,
        "Shards" => [
          {
            #"AdjacentParentShardId" => String,
            "HashKeyRange" => {
              "EndingHashKey" => String,
              "StartingHashKey" => String
            },
            #"ParentShardId" => String,
            "SequenceNumberRange" => {
              # "EndingSequenceNumber" => String,
              "StartingSequenceNumber" => String
            },
            "ShardId" => String
          }
        ],
        "StreamARN" => String,
        "StreamName" => String,
        "StreamStatus" => String
      }
    }

    @get_shard_iterator_format = {
      "ShardIterator" => String
    }

    @put_records_format = {
      "FailedRecordCount" => Integer,
      "Records" => [
        {
          # "ErrorCode" => String,
          # "ErrorMessage" => String,
          "SequenceNumber" => String,
          "ShardId" => String
        }
      ]
    }

    @put_record_format = {
      "SequenceNumber" => String,
      "ShardId" => String
    }

    @get_records_format = {
      "MillisBehindLatest" => Integer,
      "NextShardIterator" => String,
      "Records" => [
                  {
                    "Data" => String,
                    "PartitionKey" => String,
                    "SequenceNumber" => String
                  }
                 ]
      }

    tests("#create_stream").returns("") do
      result = Fog::AWS[:kinesis].create_stream("StreamName" => @stream_id).body
      while Fog::AWS[:kinesis].describe_stream("StreamName" => @stream_id).body["StreamDescription"]["StreamStatus"] != "ACTIVE"
        sleep 1
        print '.'
      end
      result
    end

    tests("#list_streams").formats(@list_streams_format, false) do
      Fog::AWS[:kinesis].list_streams.body
    end

    tests("#list_streams").returns(true) do
      Fog::AWS[:kinesis].list_streams.body["StreamNames"].include?(@stream_id)
    end

    tests("#describe_stream").formats(@describe_stream_format) do
      Fog::AWS[:kinesis].describe_stream("StreamName" => @stream_id).body
    end

    tests("#put_records").formats(@put_records_format, false) do
      records = [
                 {
                   "Data" => Base64.encode64("foo").chomp!,
                   "PartitionKey" => "1"
                 },
                 {
                   "Data" => Base64.encode64("bar").chomp!,
                   "PartitionKey" => "1"
                 }
                ]
      Fog::AWS[:kinesis].put_records("StreamName" => @stream_id, "Records" => records).body
    end

    tests("#put_record").formats(@put_record_format) do
      Fog::AWS[:kinesis].put_record("StreamName" => @stream_id, "Data" => Base64.encode64("baz").chomp!, "PartitionKey" => "1").body
    end

    tests("#get_shard_iterator").formats(@get_shard_iterator_format) do
      first_shard_id = Fog::AWS[:kinesis].describe_stream("StreamName" => @stream_id).body["StreamDescription"]["Shards"].first["ShardId"]
      Fog::AWS[:kinesis].get_shard_iterator("StreamName" => @stream_id, "ShardId" => first_shard_id, "ShardIteratorType" => "TRIM_HORIZON").body
    end

    tests("#get_records").formats(@get_records_format) do
      first_shard_id = Fog::AWS[:kinesis].describe_stream("StreamName" => @stream_id).body["StreamDescription"]["Shards"].first["ShardId"]
      shard_iterator = Fog::AWS[:kinesis].get_shard_iterator("StreamName" => @stream_id, "ShardId" => first_shard_id, "ShardIteratorType" => "TRIM_HORIZON").body["ShardIterator"]
      Fog::AWS[:kinesis].get_records("ShardIterator" => shard_iterator, "Limit" => 1).body
    end

    tests("#get_records").returns(["foo", "bar"]) do
      first_shard_id = Fog::AWS[:kinesis].describe_stream("StreamName" => @stream_id).body["StreamDescription"]["Shards"].first["ShardId"]
      shard_iterator = Fog::AWS[:kinesis].get_shard_iterator("StreamName" => @stream_id, "ShardId" => first_shard_id, "ShardIteratorType" => "TRIM_HORIZON").body["ShardIterator"]

      data = []
      2.times do
        response = Fog::AWS[:kinesis].get_records("ShardIterator" => shard_iterator, "Limit" => 1).body
        response["Records"].each do |record|
          data << Base64.decode64(record["Data"])
        end
        shard_iterator = response["NextShardIterator"]
      end
      data
    end

    tests("#delete_stream").returns("") do
      Fog::AWS[:kinesis].delete_stream("StreamName" => @stream_id).body
    end

  end
end
