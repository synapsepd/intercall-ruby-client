# Ruby API client for InterCall phone conferencing
module IntercallRubyClient
  class Owner < Config

    attr_accessor :owner_number, :first_name, :last_name, :mid_init, :position, :address1, :address2, :address3, :city
    attr_accessor :state, :country, :zip, :phone, :fax, :email, :pac_code, :web_pin, :confirmation_format, :status
    attr_accessor :numbers

    document Settings.intercall.document
    endpoint Settings.intercall.endpoint

  
    # Public: InterCall field names
    FIELDS = ['first_name', 'last_name', 'position', 'address1', 'address2', 'address3',
      'city', 'state', 'country', 'zip', 'phone', 'fax', 'email', 'pac_code', 'web_pin']

    # Public: Initialize a Owner.
    #
    # options - The Hash options used to refine the selection (default: {}):
    #           :first_name  - The first name of the Owner.
    #           :last_name   - The last name of the Owner.
    #           :position    - The position of the Owner.
    #           :address1    - The address1 of the Owner.
    #           :address2    - The address2 of the Owner.
    #           :address3    - The address1 of the Owner.
    #           :city        - The city of the Owner.
    #           :state       - The state of the Owner.
    #           :country     - The country of the Owner.
    #           :zip         - The ZIP of the Owner.
    #           :phone       - The phone number of the Owner.
    #           :fax         - The fax of the Owner.
    #           :email       - The email of the Owner.
    #           :pac_code    - The PAC code of the Owner.
    #           :web_pin     - The web pin of the Owner.
    #
    # Examples
    #   Owner.new({'first-name' => 'Bob','last-name' => 'Jones','mid-init' => 'C','position' => 'Plumber',
    #              'address1' => '123 Test St', 'city' => 'Seattle', 'state' => 'WA', 'country' => 'US',
    #              'zip' => '123456', 'phone' => '12345678', 'fax' => '12345678', 'email' => 'bobster@synapse.com'})
    #
    # Returns the Owner object

    def initialize(options = {})
      options = options.select { |k,v| FIELDS.include?(k.to_s) }
      options.each_pair { |k,v| self.instance_variable_set("@#{k}", v) }
    end

    # Public: Find owner by owner number via Intercall API
    #
    # owner_number  - The unique identifier for an owner on Intercall
    #
    # Examples
    #   owner = Owner.find_by_owner_number(224343)
    #
    # Returns the Owner object with owner_number initialized
    # Returns false if owner number is nil

    def self.find_by_owner_number(owner_number=nil)
      return false unless owner_number
    
      response = client.request(:retrieve_owner) do
        soap.input = ["retrieve-owner-request", { "xmlns" => "http://intercall.com/ownerAPI" }]
        soap.body = self.create_body({'owner-number' => owner_number})
        soap.element_form_default = :unqualified
      end

      if response
        if response.to_hash[:response_intercall_owner_service][:status] == "error"
          log_response(client.http.url, response.to_xml, client.http.body, get_class_method(__method__), 'ERROR')
          false
        else
          log_response(client.http.url, response.to_xml, client.http.body, get_class_method(__method__), 'SUCCESS')
          response = response.to_hash[:response_intercall_owner_service]
          owner = Owner.new(response[:owner][:owner_info])
          owner.owner_number = response[:owner][:owner_number]
          owner.status = response[:status]
          owner.numbers = []

          if response[:owner][:numbers] && response[:owner][:numbers].count == 2
            response[:owner][:numbers].each do |number|
              if number[:number]
                options = {
                  :number => number[:number],
                  :type => number[:@number_type],
                  :owner_number => owner.owner_number
                }
                # Example format of conference code and pin coming back from intercall
                #
                # @conference_code="5142675386          ", @pin="9715                "
                options['conference_code'] = number[:conference_code].strip! if number[:conference_code]
                options['leader_pin'] = number[:pin].strip! if number[:pin]
                owner.numbers << PhoneNumber.new(options)
              end
            end
          else
            puts 'an error occurred'
            # TODO - add better error handling here
          end
          owner
        end
      end
    end
  
    # Public: Get dial in numbers via Intercall API
    #
    # owner_number  - The unique identifier for an owner on Intercall
    #
    # Examples
    #   owner = Owner.get_dial_in_numbers(224343)
    #
    # Returns a hash of dial in numbers

    def self.get_dial_in_numbers(owner_number=nil)
      owner_number ||= Settings.conference.default_owner
      response = client.request(:getDialInNumbers) do
        soap.input = ["retrieveDialinNumbersRequest", { "xmlns" => "http://intercall.com/ownerAPI" }]
        namespaces = {
          "xmlns:soapenv" => "http://schemas.xmlsoap.org/soap/envelope/",
          "xmlns:own" => "http://intercall.com/ownerAPI",
          "xmlns:com" => "http://intercall.com/common"
        }
        soap.xml do |xml|
          xml.soapenv(:Envelope, namespaces) do |xml|
            xml.soapenv(:Header)
            xml.soapenv(:Body) do |xml|
              xml.own(:retrieveDialinNumbersRequest) do |xml|
                xml.own(:"login-info") do |xml|
                  xml.com(:"userName", Settings.intercall.username)
                  xml.com(:"password", Settings.intercall.password)
                end
                xml.own(:"dialInCriteria") do |xml|
                  xml.own(:"owner-number", owner_number)
                  xml.own(:"audioProduct", "RESPLUS")
                end
              end
            end
          end
        end
      end
      log_response(client.http.url, response.to_xml, client.http.body, get_class_method(__method__), 'SUCCESS')
      sections = response.to_hash[:retrieve_dialin_numbers_response][:product_dialin_numbers_info]
    
      local_numbers = []
      toll_free_numbers = []
      sections.each_with_index do |section, key|
        if key != 0 && key != 1
          section[:dialin_number_info].each do |number|
            if number[:display_label] == 'Local Dial-In Numbers Dial-In #'
              local_numbers << number
            elsif number[:display_label] == 'International Toll-Free Dial-In Number(s)'
              toll_free_numbers << number
            end
          end
        end
      end
    
      return { :toll_free => toll_free_numbers, :local => local_numbers }
      # @us = @numbers[:retrieve_dialin_numbers_response][:product_dialin_numbers_info][1][:dialin_number_info]
    end

    # Public: Create owner via Intercall API
    #
    # options - The Hash options used to create the owner (default: {}):
    #           :first-name  - The first name of the owner
    #           :last-name - The last name of the owner
    #           :mid-init - The middle initial of the owner
    #           :position - The position of the owner
    #           :address1 - The address1 of the owner
    #           :address2 - The address1 of the owner
    #           :address3 - The address3 of the owner
    #           :city - The city of the owner
    #           :state - The state of the owner (ex: WA)
    #           :country - The country of the owner (ex: US)
    #           :zip - The zip of the owner
    #           :zip-extn - The zip extension of the owner
    #           :phone - The phone of the owner
    #           :fax - The fax of the owner
    #           :email - The email of the owner :pac-code, :web-pin, :confirmation_format
    #
    # Examples
    #   owner = Owner.create(options)
    #
    # Returns the Owner object
    # Returns nil if owner object is not created

    def self.create(options = {})
      response = client.request(:create_owner) do
        soap.input = ["add-owner-request", {"xmlns" => "http://intercall.com/ownerAPI"}]
        soap.body = Owner.create_body({'add-owner' => { 'owner-info' => options }})
        soap.element_form_default = :unqualified
      end

      if response
        if response.to_hash[:response_intercall_owner_service][:status] == "error"
          log_response(client.http.url, response.to_xml, client.http.body, get_class_method(__method__), 'ERROR')
          false
        else
          log_response(client.http.url, response.to_xml, client.http.body, get_class_method(__method__), 'SUCCESS')
          owner = Owner.new(response.to_hash[:response_intercall_owner_service][:owner][:owner_info])
          owner.owner_number = response.to_hash[:response_intercall_owner_service][:owner][:owner_number]
          #owner.status = response.to_hash[:response_intercall_owner_service][:status]
          owner
        end
      end
    end

    # Public: Update owner via Intercall API
    #
    # Examples
    #   owner = Owner.find_by_owner_number(7891575)
    #   owner.first_name = "John"
    #   owner.update
    #   # => true
    #
    # Returns true if owner is updated
    # Returns false if owner is not updated

    def update(options = {})
      if options
        options = options.select { |k,v| FIELDS.include?(k.to_s) }
        options.each_pair { |k,v| instance_variable_set("@#{k}", v) }
      end
    
      response = client.request(:create_owner) do
        soap.input = ["update-owner-request", {"xmlns" => "http://intercall.com/ownerAPI"}]
        soap.body = Owner.create_body({
          'owner-number' => self.owner_number,
          'update-owner' => {
            'owner-info' => self.create_intercall_hash 
          }
        })
        soap.element_form_default = :unqualified
      end

      if response
        if response.to_hash[:response_intercall_owner_service][:status] == "error"
          self.class.log_response(client.http.url, response.to_xml, client.http.body, self.class.get_class_method(__method__), 'ERROR')
          false
        else
          self.class.log_response(client.http.url, response.to_xml, client.http.body, self.class.get_class_method(__method__), 'SUCCESS')
          return true
        end
      end
    end

    # Public: Add number via Intercall API
    #
    # type -  The type of number to add. The options are (reslessplus-intl or reslessplus)
    #
    # Examples
    #   owner = Owner.find_by_owner_number(7891575)
    #   owner.add_number
    #   # => true
    #
    # Returns true if automated international number is provisioned
    # Returns false if automated international number is not provisioned

    def add_number(type)
      response = client.request(:create_owner) do
        soap.input = ["update-owner-request", {"xmlns" => "http://intercall.com/ownerAPI"}]

        soap.body = create_body({
          'owner-number' => self.owner_number,
          'update-owner' => {
            'owner-info' => self.create_intercall_hash,
            'add-numbers' => '',
            :attributes! => {
              "add-numbers" => { "number-type" => type }
            }
          }
        })
        soap.element_form_default = :unqualified
      end

      if response
        if response.to_hash[:response_intercall_owner_service][:status] == "error"
          log_response(client.http.url, response.to_xml, client.http.body, get_class_method(__method__), 'ERROR')
          false
        else
          log_response(client.http.url, response.to_xml, client.http.body, get_class_method(__method__), 'SUCCESS')
          response = response.to_hash[:response_intercall_owner_service]
          if response[:owner][:numbers] && response[:owner][:numbers].count == 2
            self.status = response[:status]

            response[:owner][:numbers].each do |number|
              if number[:number]
                options = {
                  :number => number[:number],
                  :type => number[:@number_type],
                  :owner_number => self.owner_number
                }
                self.numbers = [] unless self.numbers
                # Example format of conference code and pin coming back from intercall
                #
                # @conference_code="5142675386          ", @pin="9715                "

                options['conference_code'] = number[:conference_code].strip! if number[:conference_code]
                options['leader_pin'] = number[:pin].strip! if number[:pin]
                self.numbers << PhoneNumber.new(options)
              end
            end
          end
          return true
        end
      end
    end

    # Public: Disable owner via Intercall API
    #
    # options - The Hash options used to create the owner (default: {}):
    #           :reference-number, :callback-url, :client-request, :audit-user
    #           :owner-number, :terminationNote
    #
    # Examples
    #   owner = Owner.new
    #   owner.disable(options)
    #   # => response
    #
    # Returns the Owner object with status = 'DISABLED'

    def disable(options= {})
      response = client.request(:stop_owner_activity) do
        soap.body = {}
        soap.input = [ "stop-activity-owner-request",
          {"xmlns" => "http://intercall.com/ownerAPI", "action" => "disable"} 
        ]
        options['owner-number'] = self.owner_number
        soap.body = create_body(options)
        soap.element_form_default = :unqualified
      end

      if response
        if response.to_hash[:stop_activity_owner_response][:status] == "error"
          self.class.log_response(client.http.url, response.to_xml, client.http.body, self.class.get_class_method(__method__), 'ERROR')
          false
        elsif response.to_hash[:stop_activity_owner_response][:status] == "disabled"
          self.class.log_response(client.http.url, response.to_xml, client.http.body, self.class.get_class_method(__method__), 'SUCCESS')
          self.status = "DISABLED"
          true
        end
      end
    end

    # Public: Enable owner via Intercall API
    #
    # options - The Hash options used to create the owner (default: {}):
    #           :reference-number, :callback-url, :client-request, :audit-user
    #           :owner-number (required), :termination-note
    #
    # Examples
    #   owner = Owner.new
    #   owner.enable(options)
    #   # => response
    #
    # Returns the duplicated String.

    def enable(options = {})
      response = client.request(:stop_owner_activity) do
        soap.input = [ "stop-activity-owner-request",
          {"xmlns" => "http://intercall.com/ownerAPI", "action" => "enable"} 
        ]
        options['owner-number'] = self.owner_number
        soap.body = Intercall.create_body(options)
        soap.element_form_default = :unqualified
      end

      if response
        if response.to_hash[:stop_activity_owner_response][:status] == "error"
          self.class.log_response(client.http.url, response.to_xml, client.http.body, self.class.get_class_method(__method__), 'ERROR')
          false
        elsif response.to_hash[:stop_activity_owner_response][:status] == "enabled"
          self.class.log_response(client.http.url, response.to_xml, client.http.body, self.class.get_class_method(__method__), 'SUCCESS')
          self.status = "ENABLED"
          true
        end
      end
    end

    # Public: Delete owner via Intercall API
    #
    # termination_note - The note to include for the deleted Owner
    #
    # Examples
    #   owner = Owner.new
    #   owner.delete(options)
    #   # => response
    #
    # Returns true is the owner is deleted
    # Returns false if the owner is not deleted

    def delete(termination_note=nil)
      response = client.request(:delete_owner) do
        soap.input = [ "delete-owner-request", {"xmlns" => "http://intercall.com/ownerAPI"} ]
        soap.body = Intercall.create_body({ "delete-owner" => {
          "owner-number" => self.owner_number, "terminationNote" => termination_note }
        })
        soap.element_form_default = :unqualified
      end

      if response
        if response.to_hash[:delete_owner_response_service][:status] == "error"
          log_response(client.http.url, response.to_xml, client.http.body, get_class_method(__method__), 'ERROR')
          return false
        elsif response.to_hash[:delete_owner_response_service][:status] == "Delete Successful"
          log_response(client.http.url, response.to_xml, client.http.body, get_class_method(__method__), 'SUCCESS')
          return true
        end
      end
    end

    # Public: Create intercall hash from instance

    def create_intercall_hash
      options = {
        'first-name' => self.first_name,
        'last-name' => self.last_name,
        'position' => self.position,
        'address1' => self.address1,
        'address2' => self.address2,
        'address3' => self.address3,
        'city' => self.city,
        'state' => self.state,
        'country' => self.country,
        'zip' => self.zip,
        'phone' => self.phone,
        'fax' => self.fax,
        'email' => self.email,
      }
      options.delete_if {|k,v| v.blank? }  #this may be need to prevent nil values in XML
      options
    end
  

  end
end