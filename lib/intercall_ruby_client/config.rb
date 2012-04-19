module IntercallRubyClient
  class Config
    extend Savon::Model

    document Settings.intercall.document
    endpoint Settings.intercall.endpoint

    private

    # Private: Create SOAP body with default credentials for InterCall API
    #
    # options - The Hash options used to create the owner (default: {}):
    #
    # Examples
    #   body = Owner.create_body({:test1 => 'test1', :test2 => 'test2'})
    #   #  => {"login-info"= {"user-name"=>"synapse", "password"=>"FuJume8a", "account-number"=>"889797"},
    #   :test1=>"test1", :test2=>"test2"}
    #
    # Returns the merged hash.

    def self.create_body(options = {})
      {
        'login-info' => {
          'user-name'      => Settings.intercall.username,
          'password'       => Settings.intercall.password,
          'account-number' => Settings.intercall.account_number
        }
      }.merge!(options)
    end
  
    def self.log_debug(url, action, status, request, response)
      RedisLogger.debug({ 
       "url" => url,
       "class::method" => action,
       "status" => status,
       "request" => request,
       "response" => response
      }, ['conference'])
    end

    def self.log_error(url, action, status, request, response)
      RedisLogger.error({ 
       "url" => url,
       "class::method" => action,
       "status" => status,
       "request" => request,
       "response" => response
      }, ['conference'])
    end

    def self.log_response(url, response_hash, request, class_method, status)
      if status == 'ERROR'
        log_error(url, class_method, 'ERROR', 
          request, response_hash
        )
        false
      else
        log_debug(url, class_method, 'SUCCESS', 
          request, response_hash
        )
        true
      end
    end
  
    def self.get_class_method(method)
      self.name + '::' + method.to_s
    end
  end
end