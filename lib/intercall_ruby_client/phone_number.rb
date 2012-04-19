class PhoneNumber < Config
  attr_accessor :number, :type, :leader_pin, :conference_code, :owner_number
  
  document Settings.intercall.document
  endpoint Settings.intercall.endpoint
  
  def initialize(options = {})
    options.each_pair do |k,v|
      self.instance_variable_set("@#{k}", v)
    end
  end
  
  def delete
    response = client.request(:create_owner) do
      soap.input = ["update-owner-request", {"xmlns" => "http://intercall.com/ownerAPI"}]

      soap.body = create_body({
        'owner-number' => self.owner_number,
        'update-owner' => { 
          'owner-info' => Owner.find_by_owner_number(self.owner_number).create_intercall_hash,
          'delete-numbers' => { 'number' => self.number },
          :attributes! => { 
             "delete-numbers" => { "number-type" => self.type }
           }
         },
      })
      soap.element_form_default = :unqualified
    end

    if response
      if response.to_hash[:response_intercall_owner_service][:status] == "error"
        self.class.log_response(client.http.url, response.to_xml, client.http.body, self.class.get_class_method(__method__), 'ERROR')
        false
      else
        log_response(client.http.url, response.to_xml, client.http.body, get_class_method(__method__), 'SUCCESS')
        true
      end
    end
  end
  
end