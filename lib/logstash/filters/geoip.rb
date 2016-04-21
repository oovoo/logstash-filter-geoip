# encoding: utf-8
require "logstash/filters/base"
require "logstash/namespace"
require "tempfile"
require "redis"
require "lru_redux"
require "json"
require_relative '../../netacuity/NetAcuity'

# The GeoIP filter adds information about the geographical location of IP addresses,
# based on data from the Maxmind database.
#
# Starting with version 1.3.0 of Logstash, a `[geoip][location]` field is created if
# the GeoIP lookup returns a latitude and longitude. The field is stored in
# http://geojson.org/geojson-spec.html[GeoJSON] format. Additionally,
# the default Elasticsearch template provided with the
# <<plugins-outputs-elasticsearch,`elasticsearch` output>> maps
# the `[geoip][location]` field to an https://www.elastic.co/guide/en/elasticsearch/reference/1.7/mapping-geo-point-type.html#_mapping_options[Elasticsearch geo_point].
#
# As this field is a `geo_point` _and_ it is still valid GeoJSON, you get
# the awesomeness of Elasticsearch's geospatial query, facet and filter functions
# and the flexibility of having GeoJSON for all other applications (like Kibana's
# map visualization).
#
# Logstash releases ship with the GeoLiteCity database made available from
# Maxmind with a CCA-ShareAlike 3.0 license. For more details on GeoLite, see
# <http://www.maxmind.com/en/geolite>.
class LogStash::Filters::GeoIP < LogStash::Filters::Base
  LOCAL_CACHE_INIT_MUTEX = Mutex.new
  # Map of lookup caches, keyed by geoip_type
  LOOCAL_CACHES = {}

  attr_accessor :local_cache
  attr_accessor :redis_cache
  attr_reader :threadkey


  config_name "geoip"

  # The path to the GeoIP database file which Logstash should use. Country, City, ASN, ISP
  # and organization databases are supported.
  # Also, you can specify as a'NetAcuity' which Logstash filter will use as a IP data source.
  # Choosing 'NetAcuity' as a source, please be sure, that you have specified 'net_acuity_address'
  #
  # If not specified, this will default to the GeoLiteCity database that ships
  # with Logstash.
  # Up-to-date databases can be downloaded from here: <https://dev.maxmind.com/geoip/legacy/geolite/>
  # Please be sure to download a legacy format database.
  config :database, :validate => :string

  # NetAcuity is used external source for fetching information about Ip address.
  # You should specify this address for right querying information about Ip address.
  # Beware, that it works only if your 'database => 'NetAcuity'
  config :net_acuity_address, :validate => :string

  # NetAcuity can be used for fetching different type of information. You can specify it by
  # choosing different api_id. By default - [3,7,8,12]
  # API_ID  | DB Name   | Info
  #   3     |  GEO      | ["country", "region", "city", "conn-speed", "country-conf", "region-conf", "city-conf", "metro-code", "latitude", "longitude", "country-code", "region-code", "city-code", "continent-code", "two-letter-country"]
  #   4     |  EDGE     | ["edge-country", "edge-region", "edge-city", "edge-conn-speed", "edge-metro-code", "edge-latitude", "edge-longitude", "edge-postal-code", "edge-country-code", "edge-region-code", "edge-city-code", "edge-continent-code", "edge-two-letter-country", "edge-internal-code", "edge-area-codes", "edge-country-conf", "edge-region-conf", "edge-city-conf", "edge-postal-code-conf", "edge-gmt-offset", "edge-in-dst"]
  #   5     |  SIC      | ["sic-code"]
  #   6     |  DOMAIN   | ["domain-name"]
  #   7     |  ZIP      | ["area-code", "zip-code", "gmt-offset", "in-dst", "zip-code-text", "zip-country"]
  #   8     |  ISP      | ["isp-name"]
  #   9     |  HOME_BIZ | ["homebiz-type"]
  #   10    |  ASN      | [ "asn", "asn-name"]
  #   11    |  LANGUAGE | [ "primary-lang","secondary-lang"]
  #   12    |  PROXY    | ["proxy-type","proxy-description"]
  #   14    |  ISANISP  | ["is-an-isp"]
  #   15    |  COMPANY  | ["company-name"]
  #   17    |  DEMOGRAPHICS| ["rank", "households", "women", "w18-34", "w35-39", "men", "m18-34", "m35-49", "teens", "kids"]
  #   18    |  NAICS    | ["naics-code"]
  #   19    |  CBSA     | ["cbsa-code", "cbsa-title", "cbsa-type", "csa-code", "csa-title", "md-code", "md-title"]
  #   24    |  MOBILE_CARRIER | ["mobile-carrier", "mcc", "mnc"]
  #   25    |  ORG      | ["organization-name"]
  #   26    |  PULSE    | ["pulse-country", "pulse-region", "pulse-city", "pulse-conn-speed", "pulse-conn-type", "pulse-metro-code", "pulse-latitude", "pulse-longitude", "pulse-postal-code", "pulse-country-code", "pulse-region-code", "pulse-city-code", "pulse-continent-code", "pulse-two-letter-country", "pulse-internal-code", "pulse-area-codes", "pulse-country-conf", "pulse-region-conf", "pulse-city-conf", "pulse-postal-conf", "pulse-gmt-offset", "pulse-in-dst"]
  config :net_acuity_api, :validate => :array, :default => [3, 7, 8, 12]

  # The field containing the IP address or hostname to map via geoip. If
  # this field is an array, only the first value will be used.
  config :source, :validate => :string, :required => true

  # An array of geoip fields to be included in the event.
  #
  # Possible fields depend on the database type. By default, all geoip fields
  # are included in the event.
  #
  # For the built-in GeoLiteCity database, the following are available:
  # `city_name`, `continent_code`, `country_code2`, `country_code3`, `country_name`,
  # `dma_code`, `ip`, `latitude`, `longitude`, `postal_code`, `region_name` and `timezone`.
  #
  # For the NetAcuity database the following are availabe:
  # "ip", "country", "region", "city", "conn-speed", "country-conf", "region-conf", "city-conf", "metro-code",
  # "latitude", "longitude", "country-code", "region-code", "city-code", "continent-code", "two-letter-country"
  config :fields, :validate => :array

  # Specify the field into which Logstash should store the geoip data.
  # This can be useful, for example, if you have `src\_ip` and `dst\_ip` fields and
  # would like the GeoIP information of both IPs.
  #
  # If you save the data to a target field other than `geoip` and want to use the
  # `geo\_point` related functions in Elasticsearch, you need to alter the template
  # provided with the Elasticsearch output and configure the output to use the
  # new template.
  #
  # Even if you don't use the `geo\_point` mapping, the `[target][location]` field
  # is still valid GeoJSON.
  config :target, :validate => :string, :default => 'geoip'

  # GeoIP or NetAcuity quering lookup is surprisingly expensive. This filter uses an cache to take advantage of the fact that
  # IPs agents are often found adjacent to one another in log files and rarely have a random distribution.
  # The higher you set this the more likely an item is to be in the cache and the faster this filter will run.
  # However, if you set this too high you can use more memory than desired.
  #
  # Experiment with different values for this option to find the best performance for your dataset.
  # This is main behaviour of the cache usage, between LRU local cache OR remote Redis instance
  # 'caching_source' will define place for caching you GEOIP information on LRU principles.
  config :caching_source, :validate => :string, :default => 'lru_cache'

  # Possible fields which will be cached. Otherwise all info will be cached
  config :caching_fields, :validate => :array


  # This MUST be set to a value > 0. There is really no reason to not want this behavior, the overhead is minimal
  # and the speed gains are large.
  #
  # It is important to note that this config value is global to the geoip_type. That is to say all instances of the geoip filter
  # of the same geoip_type share the same cache. The last declared cache size will 'win'. The reason for this is that there would be no benefit
  # to having multiple caches for different instances at different points in the pipeline, that would just increase the
  # number of cache misses and waste memory.
  config :lru_cache_size, :validate => :number, :default => 1000


  # Redis configuration paranmeters for replcating it with LRU cache
  # This field contains redis host parameter
  # By default, it's localhost
  config :redis_host, :validate => :string, :default => "localhost"

  # Redis port number for connecting to Redis
  # By default, it's basic redis port from configuration
  config :redis_port, :validate => :number,  :default => 6379

  # Namespace storing keys in Redis, named as redis DB
  # represents in integer from 0 to 12, by default is 0
  config :redis_db, :validate => :number, :default => 0

  # Password for authentications in redis.
  # By default: nil
  # When password is nil, there is no authentications process after connecting to Redis
  config :redis_password, :validate => :string, :default => nil

  # Set Time to Live on each inserted key to Redis
  config :redis_ttl, :validate => :number, :default => 0

  # Keyspace which will be used for SET keys to redis
  config :redis_key_preffix, :validate => :string, :default => "geo"

  public
  def register
    require "geoip"

    if @database == 'NetAcuity'
      if @net_acuity_address.nil?
        raise "You have choosen NetActuty as a database. You must specify 'netActuityIP' => .... in your geoip filter configuration "
      end
      @netAcuityDB = NetAcuity.new(@net_acuity_address)
    else

      if @database.nil?
        @database = ::Dir.glob(::File.join(::File.expand_path("../../../vendor/", ::File.dirname(__FILE__)),"GeoLiteCity*.dat")).first
        if !File.exists?(@database)
          raise "You must specify 'database => ...' in your geoip filter (I looked for '#{@database}'"
        end
      end

      # For the purpose of initializing this filter, geoip is initialized here but
      # not set as a global. The geoip module imposes a mutex, so the filter needs
      # to re-initialize this later in the filter() thread, and save that access
      # as a thread-local variable.
      geoip_initialize = ::GeoIP.new(@database)

      @geoip_type = case geoip_initialize.database_type
                      when GeoIP::GEOIP_CITY_EDITION_REV0, GeoIP::GEOIP_CITY_EDITION_REV1
                        :city
                      when GeoIP::GEOIP_COUNTRY_EDITION
                        :country
                      when GeoIP::GEOIP_ASNUM_EDITION
                        :asn
                      when GeoIP::GEOIP_ISP_EDITION, GeoIP::GEOIP_ORG_EDITION
                        :isp
                      else
                        raise RuntimeException.new "This GeoIP database is not currently supported"
                    end

      @threadkey = "geoip-#{self.object_id}"
    end
    @logger.info("Using database", :path => @database)

    # This is wrapped in a mutex to make sure the initialization behavior of LOOKUP_CACHES (see def above) doesn't create a dupe
    LOCAL_CACHE_INIT_MUTEX.synchronize do
      self.local_cache = LOOCAL_CACHES[@geoip_type] ||= LruRedux::ThreadSafeCache.new(1000)
    end

    if @caching_source.casecmp("redis").zero?
      self.redis_cache = Redis.new(:host => @redis_host, :port => @redis_port, :db=> @redis_db, :password => @redis_password)
    end

    @no_fields = @fields.nil? || @fields.empty?
    @all_caching_fields = @caching_fields.nil? || @caching_fields.empty?
  end # def register

  public
  def filter(event)
    geo_data_hash = get_geo_data(event)
    if apply_geodata(geo_data_hash, event)
      filter_matched(event)
    end
  end # def filter

  def apply_geodata(geo_data_hash, event)
    # don't do anything more if the lookup result is nil?
    return false if geo_data_hash.nil?
    # only set the event[@target] if the lookup result is not nil: BWC
    event[@target] = {} if event[@target].nil?
    # don't do anything more if the lookup result is empty?
    return false if geo_data_hash.empty?
    geo_data_hash.each do |key, value|
      if @no_fields || @fields.include?(key)
        # can't dup numerics
        event["[#{@target}][#{key}]"] = value.is_a?(Numeric) ? value : value.dup
      end
    end # geo_data_hash.each
    true
  end

  def get_geo_data(event)
    # pure function, must control return value
    result = {}
    ip = event[@source]
    ip = ip.first if ip.is_a? Array
    return nil if ip.nil?
    begin
      result = get_geo_data_for_ip(ip)
    rescue SocketError => e
      @logger.error("IP Field contained invalid IP address or hostname", :field => @source, :event => event)
    rescue StandardError => e
      @logger.error("Unknown error while looking up GeoIP data", :exception => e, :field => @source, :event => event)
    end
    result
  end

  def get_geo_data_for_ip(ip)
    if (cached = lookup_cache(ip))
      cached
    else
      geo_data = get_geo_data_db(ip)
      geo_data_filtered = filter_caching_fields(geo_data)
      converted = prepare_geodata_for_cache(geo_data_filtered)
      setup_cache(ip, converted)
      converted
    end
  end

  def get_geo_data_db(ip)
    if @database.casecmp('netacuity').zero?
      result = Hash.new
      @net_acuity_api.each{ |api_id|
        na_res = @netAcuityDB.query(ip, api_id, api_id)
        result = result.merge(na_res) if (na_res.is_a?(Hash))
      }
      result
    else
      ensure_geoip_database!
      Thread.current[threadkey].send(@geoip_type, ip)
    end
  end

  def lookup_cache(ip)
    if @caching_source.casecmp('redis').zero?
      cached = redis_cache.get(redis_key(ip))
      cached.nil? ? false : JSON.parse(cached)
    else
      local_cache[ip]
    end
  end


  def setup_cache(ip, converted)
    if @caching_source.casecmp("redis").zero?
      redis_cache.setex(redis_key(ip), @redis_ttl, converted.to_json)
    else
      local_cache[ip] = converted
    end

  end

  def filter_caching_fields(geo_data_hash)
    geodata_hash_filtered = {}

    geo_data_hash.each do |key, value|
      if @all_caching_fields || @caching_fields.include?(key)
        # can't dup numerics
        geodata_hash_filtered["#{key}"] = value.is_a?(Numeric) ? value : value.dup
      end
    end # geo_data_hash.each

    geodata_hash_filtered
  end


  def prepare_geodata_for_cache(geo_data)
    # GeoIP returns a nil or a Struct subclass
    return nil if !geo_data.respond_to?(:each_pair)
    #lets just do this once before caching
    result = {}
    geo_data.each_pair do |k, v|
      next if v.nil? || k == :request
      if v.is_a?(String)
        next if v.empty?
        # Some strings from GeoIP don't have the correct encoding...
        result[k.to_s] = case v.encoding
          # I have found strings coming from GeoIP that are ASCII-8BIT are actually
          # ISO-8859-1...
        when Encoding::ASCII_8BIT
          v.force_encoding(Encoding::ISO_8859_1).encode(Encoding::UTF_8)
        when Encoding::ISO_8859_1, Encoding::US_ASCII
          v.encode(Encoding::UTF_8)
        else
          v
        end
      else
        result[k.to_s] = v
      end
    end

    lat, lng = result.values_at("latitude", "longitude")
    if lat && lng
      result["location"] = [ lng.to_f, lat.to_f ]
    end

    result
  end

  def redis_key(key)
    "#{@redis_key_preffix}:#{key}"
  end

  def ensure_geoip_database!
    # Use thread-local access to GeoIP. The Ruby GeoIP module forces a mutex
    # around access to the database, which can be overcome with :pread.
    # Unfortunately, :pread requires the io-extra gem, with C extensions that
    # aren't supported on JRuby. If / when :pread becomes available, we can stop
    # needing thread-local access.
    Thread.current[threadkey] ||= ::GeoIP.new(@database)
  end
end # class LogStash::Filters::GeoIP
