#!/usr/bin/ruby
##################################################################
# class NetAcuity: API class to query NetAcuity Server
# File:        NetAcuity.rb
# Author:      Digital Envoy
# Program:     NetAcuity API
# Version:     5.5.0.7
# Date:        8-Oct-2015
#
# Copyright 2000-2015, Digital Envoy, Inc.  All rights reserved.
#
# This library is provided as an access method to the NetAcuity software
# provided to you under License Agreement from Digital Envoy Inc.
# You may NOT redistribute it and/or modify it in any way without express
# written consent of Digital Envoy, Inc.
#
# Address bug reports and comments to:  tech-support@digitalenvoy.net
#
#
# Description:  Access methods to NetAcuity databases. 
# 
#
##################################################################

require_relative 'NetAcuityDBDefs'
require 'socket'
require 'timeout'

class NetAcuity

  MAX_RESPONSE_SIZE = 1496
  #################################################################
  # initialize : class constructor
  # server: IP Address of NetAcuity Server to query
  #################################################################
  def initialize(server, api_id = 0, timeout = 2)
    @server = server
    @port = 5400
    @api_id = api_id
    @timeout = timeout
    @error_message = ""
  end

  #################################################################
  # timeout= : Set the number of seconds to wait for NetAcuity Server response
  #################################################################
  attr_writer :timeout
  
  #################################################################
  # api_id= : set the api_id to pass to the NetAcuity Server (default = 0)
  #################################################################
  attr_writer :api_id
  
  #################################################################
  # error_msg() : get the error message if an error occurred
  #################################################################
  attr_reader :error_msg

  #################################################################
  # response_size() : get Raw Response size from query
  #################################################################
  attr_reader :response_size

  #################################################################
  # raw_response() : get Raw Response for query
  #################################################################
  attr_reader :raw_response

  #################################################################
  # num_of_fields() : get number of fields returned from Raw Response query            
  #################################################################
  attr_reader :num_of_fields

  #################################################################
  # query(): Method to query the NetActity Server
  # ip_address: string of ip address to query for
  # db_feature: number of the database to query
  #################################################################
  def query(ip_address, db_feature, trans_id)
    if (valid_db?(db_feature.to_i))
      my_query = "#{db_feature};#{@api_id};#{ip_address};#{NetAcuityDBDefs::NA_API_VERSION};#{NetAcuityDBDefs::NA_API_TYPE};#{trans_id};"
      if (@server.include?(":"))
        socket = UDPSocket.new(Socket::AF_INET6)
      else
        socket = UDPSocket.new(Socket::AF_INET)
      end
      socket.send(my_query, 0, @server, @port)
      begin
        timeout(@timeout) do
        response, from = socket.recvfrom(MAX_RESPONSE_SIZE)
        return parse_response(response, db_feature.to_i, trans_id, ip_address)
      end
      rescue Timeout::Error
         @error_msg = "TIMEOUT"
         return 0
      end
    end
  end
  
  ################################################################
  # query_multiple_dbs(): Query NetAcuity with multiple Databases
  #                     with a single call
  # ip_address: IP Address to query NetAcuity with
  # db_features: array of numbers of databases to query
  # trans_id: id for transaction that will be returned in response
  ################################################################
  def query_multiple_dbs(ip_address, db_features, trans_id = 0)
    request = create_request(ip_address, db_features, trans_id)
    if (@server.include?(":"))
      socket = UDPSocket.new(Socket::AF_INET6)
    else
      socket = UDPSocket.new(Socket::AF_INET)
    end
    @raw_response = ""
      socket.send(request, 0, @server, @port)
      begin
        timeout(@timeout) do
        done = false
        last_packet = 0
        while !done do
          response, from = socket.recvfrom(MAX_RESPONSE_SIZE)
          if response.length > 0
            packet_number = response[0,2].to_i
            total_packet = response[2,2].to_i
            #getting packets in order
            if ((packet_number - 1) == last_packet)
              last_packet = packet_number
              if (packet_number == total_packet)
                @raw_response << response[4..-2]
                done = true
              else
                @raw_response << response
              end
            else
              #packet out of order...error
              @error_msg = "Response Packets out of order"
              return 0
            end
          end
        end
        @response_size = @raw_response.length
      end
      rescue Timeout::Error
      @error_msg = "Timeout querying NetAcuity Server"
      return 0
    end
    return parse_xml_response(@raw_response)
  end
  
  private
  
  ################################################################
  # create_request(): Create xml request for NetAcuity for 
  #                  multiple Databases with a single call
  # ip_address: IP Address to query NetAcuity with
  # db_features: array of numbers of databases to query
  ################################################################
  def create_request(ip_address, db_features, trans_id)
    query_string = "<request trans-id=\"#{trans_id}\" ip=\"#{ip_address}\" api-id=\"#{@api_id}\" >"
    db_features.each { |db| query_string << "<query db=\"#{db}\" />" if valid_db?(db) }
    return query_string << "</request>"
  end
  
  ################################################################
  # parse_xml_response(): parse the xml response for the multiple
  #                     database query
  # response: xml response from NetAcuity Server
  ################################################################
  def parse_xml_response(response)
    #stripping off <response and trailing />
    responses = {}
    if (response.length > 0)
         
      response_string = response[10..-3]
      tokens = response_string.split(/\" /)
      @num_of_fields = tokens.length
    
      tokens.each do |token|
        equal_token = token.split(/\=/)
        if (equal_token.length == 2)
          field = equal_token[0]
          #remove the '"'(quotes)
          value = equal_token[1].gsub(/"/, '')
          if field.include?("error")
            @error_msg = value
          else
            responses[field] = value
          end
        elsif(equal_token.length != 1)
          #ERROR
          @error_msg = "Error with tokens"
          return 0
        end
      end
    end
    return responses 
  end
  
  def valid_db?(db_feature)
    return (db_feature < 500 && db_feature >= 1)
  end
  
  ################################################################
  # parse_response(): parse the response for the single
  #                     database query
  # response: response from NetAcuity Server
  # db_feature: the database queried
  # trans_id: the transaction ID the user entered.
  # ip_address: the IP address being queried
  ################################################################
  def parse_response(response, db_feature, trans_id, ip_address)
    data_fields = {}
   
    @response_size, @num_of_fields, @raw_response = parse_response_meta_data(response)
    field_values = @raw_response.split(/;/)

    if @num_of_fields == NetAcuityDBDefs::NA_API_5_INDICATOR
      api_version = field_values.shift
      response_ip_address = field_values.shift
      response_trans_id = field_values.shift
      @error_msg = field_values.shift
     
      if response_ip_address != ip_address
       @error_msg = "Error response IP does not match"
       return 0
      end
      if (Integer(response_trans_id) != trans_id)
        @error_msg = "Error Transaction ID does not match #{response_trans_id} != #{trans_id}"
        return 0
      end
      if @error_msg != ""
         return 0
      end
    end
       
    index = 0
    field_values.each do |field_value|
      if (NetAcuityDBDefs.GLOBAL[db_feature])
        if (NetAcuityDBDefs.GLOBAL[db_feature][index])
          data_fields[NetAcuityDBDefs.GLOBAL[db_feature][index]] = field_value
        end
      else
        data_fields["field-#{index+1}"] = field_value
      end
      index += 1
    end
    return data_fields
  end
  
  ################################################################
  # parse_response_meta_data(): parse the metadata about the response
  #                          from the NetActuity Server for single
  #                          database query
  # response: response from NetAcuity Server
  ################################################################
  def parse_response_meta_data(response)
    size_bin = response[0,2]
    size = size_bin.unpack('n*')[0] -1
    num_fields_bin = response[2,2]
    num_fields = num_fields_bin.unpack('n*')[0]
    return [size, num_fields, response[4..-3]]
  end

end

 
