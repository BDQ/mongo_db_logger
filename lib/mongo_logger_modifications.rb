module MongoLoggerModifications
  def self.included(base)
    base.class_eval {
      alias_method :old_add, :add
      alias_method :new_add, :add
      
      db_configuration = {
        'host'    => 'localhost',
        'port'    => 27017,
        'capsize' => 100000}.merge( YAML::load(ERB.new(IO.read(File.join(Rails.root, 'config/database.yml'))).result)[Rails.env]['mongo'] )

      @@mongo_collection_name      = "#{Rails.env}_log"
      @@mongo_connection ||= Mongo::Connection.new(db_configuration['host'], db_configuration['port'], :auto_reconnect => true).db(db_configuration['database'])

      # setup the capped collection if it doesn't already exist
      unless @@mongo_connection.collection_names.include?(@@mongo_collection_name)
        @@mongo_connection.create_collection(@@mongo_collection_name, {:capped => true, :size => db_configuration['capsize']})
      end

      cattr_reader :mongo_connection, :mongo_collection_name
    }
  end
  
  def mongoize(options={})      
    @mongo_record = options.merge({
      :messages => Hash.new { |hash, key| hash[key] = Array.new },
      :request_time => Time.now.utc
    })
    runtime = Benchmark.ms do
      yield
    end
    @mongo_record[:runtime]     = runtime.ceil
    self.class.mongo_connection[self.class.mongo_collection_name].insert(@mongo_record) rescue nil
  end
  
  def add_metadata(options={})
    options.each_pair do |key, value|
      unless [:messages, :request_time, :ip, :runtime].include?(key.to_sym)
        info("adding #{key} => #{value}")
        @mongo_record[key] = value
      else
        raise ArgumentError, ":#{key} is a reserved key for the mongo logger. Please choose a different key"
      end
    end
  end
  
  def new_add(severity, message = nil, progname = nil, &block)
    unless @level > severity
      if ActiveRecord::Base.colorize_logging
        # remove colorization done by rails and just save the actual message
        @mongo_record[:messages][level_to_sym(severity)] << message.gsub(/(\e(\[([\d;]*[mz]?))?)?/, '').strip rescue nil
      else
        @mongo_record[:messages][level_to_sym(severity)] << message
      end
    end
    
    old_add(severity, message, progname, &block)
  end
end