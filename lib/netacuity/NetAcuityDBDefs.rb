#!/usr/bin/ruby
##################################################################
# class NetAcuity: API definitions module to query NetAcuity Server
# File:        NetAcuityDBDefs.rb
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
# Description:  Definitions for Access methods to NetAcuity databases. 
#
#
##################################################################

module NetAcuityDBDefs

  NA_API_VERSION = 5
  NA_API_TYPE = 8
  NA_API_5_INDICATOR = 32767  
  
  
  NA_GEO_DB = 3
  NA_EDGE_DB = 4
  NA_SIC_DB = 5
  NA_DOMAIN_DB = 6
  NA_ZIP_DB = 7
  NA_ISP_DB = 8
  NA_HOME_BIZ_DB = 9
  NA_ASN_DB = 10
  NA_LANGUAGE_DB = 11
  NA_PROXY_DB = 12
  NA_ISANISP_DB = 14
  NA_COMPANY_DB = 15
  NA_DEMOGRAPHICS_DB = 17
  NA_NAICS_DB = 18
  NA_CBSA_DB = 19
  NA_MOBILE_CARRIER_DB = 24
  NA_ORGANIZATION_DB = 25
  NA_PULSE_DB = 26
    
  @GEO = [
    "country", 
    "region", 
    "city", 
    "conn-speed", 
    "country-conf", 
    "region-conf", 
    "city-conf", 
    "metro-code", 
    "latitude", 
    "longitude", 
    "country-code", 
    "region-code", 
    "city-code", 
    "continent-code", 
    "two-letter-country"
  ]
  
  @EDGE = [
    "edge-country", 
    "edge-region", 
    "edge-city", 
    "edge-conn-speed", 
    "edge-metro-code", 
    "edge-latitude", 
    "edge-longitude", 
    "edge-postal-code",
    "edge-country-code", 
    "edge-region-code", 
    "edge-city-code", 
    "edge-continent-code", 
    "edge-two-letter-country",
    "edge-internal-code",
    "edge-area-codes",
    "edge-country-conf",
    "edge-region-conf",
    "edge-city-conf",
    "edge-postal-code-conf",
    "edge-gmt-offset",
    "edge-in-dst"
  ]
  
  @SIC = ["sic-code"]
  
  @DOMAIN = ["domain-name"]
  
  @ZIP = [
    "area-code",
    "zip-code",
    "gmt-offset",
    "in-dst",
    "zip-code-text",
    "zip-country"
  ]
  
  @ISP = ["isp-name"]
  
  @HOME_BIZ = ["homebiz-type"]
  
  @ASN = [
    "asn",
    "asn-name"
  ]
  
  @LANGUAGE = [
    "primary-lang",
    "secondary-lang"
  ]
  
  @PROXY = ["proxy-type",
    "proxy-description"
  ]
  
  @ISANISP = ["is-an-isp"]
  
  @COMPANY = ["company-name"]
  
  @DEMOGRAPHICS = [
    "rank",
    "households",
    "women",
    "w18-34",
    "w35-39",
    "men",
    "m18-34",
    "m35-49",
    "teens",
    "kids"
  ]
  
  @NAICS = ["naics-code"]
  
  @CBSA = [
    "cbsa-code",
    "cbsa-title",
    "cbsa-type",
    "csa-code",
    "csa-title",
    "md-code",
    "md-title"
  ]

  @MOBILE_CARRIER = [
    "mobile-carrier",
    "mcc",
    "mnc"
  ]

  @ORG = ["organization-name"]

  @PULSE = [
    "pulse-country",
    "pulse-region",
    "pulse-city",
    "pulse-conn-speed",
    "pulse-conn-type",
    "pulse-metro-code",
    "pulse-latitude",
    "pulse-longitude",
    "pulse-postal-code",
    "pulse-country-code",
    "pulse-region-code",
    "pulse-city-code",
    "pulse-continent-code",
    "pulse-two-letter-country",
    "pulse-internal-code",
    "pulse-area-codes",
    "pulse-country-conf",
    "pulse-region-conf",
    "pulse-city-conf",
    "pulse-postal-conf",
    "pulse-gmt-offset",
    "pulse-in-dst"
  ]
  
@GLOBAL = Array.new                 
@GLOBAL[NA_GEO_DB] = @GEO
@GLOBAL[NA_EDGE_DB] = @EDGE
@GLOBAL[NA_SIC_DB] = @SIC
@GLOBAL[NA_DOMAIN_DB] = @DOMAIN
@GLOBAL[NA_ZIP_DB] = @ZIP
@GLOBAL[NA_ISP_DB] = @ISP
@GLOBAL[NA_HOME_BIZ_DB] = @HOME_BIZ
@GLOBAL[NA_ASN_DB] = @ASN
@GLOBAL[NA_LANGUAGE_DB] = @LANGUAGE
@GLOBAL[NA_PROXY_DB] = @PROXY
@GLOBAL[NA_ISANISP_DB] = @ISANISP
@GLOBAL[NA_COMPANY_DB] = @COMPANY
@GLOBAL[NA_DEMOGRAPHICS_DB] = @DEMOGRAPHICS
@GLOBAL[NA_NAICS_DB] = @NAICS
@GLOBAL[NA_CBSA_DB] = @CBSA
@GLOBAL[NA_MOBILE_CARRIER_DB] = @MOBILE_CARRIER
@GLOBAL[NA_ORGANIZATION_DB] = @ORG
@GLOBAL[NA_PULSE_DB] = @PULSE




def self.GLOBAL
  @GLOBAL
end

end

#print "#{NetAcuityDBDefs.GLOBAL[3][2]}"
