klass = if ActionPack::VERSION::MAJOR >= 3
  ActionDispatch::Routing::DeprecatedMapper
else
  ActionController::Routing::RouteSet::Mapper
end

klass.send(:include, MongoDBLogging::RoutingExtensions)
