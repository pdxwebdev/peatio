module Yada
  class Client
    Error = Class.new(StandardError)

    class ConnectionError < Error; end

    class ResponseError < Error
      def initialize(code, msg)
        super "#{msg} (#{code})"
      end
    end

    extend Memoist

    def initialize(endpoint, idle_timeout: 5)
      @json_rpc_endpoint = URI.parse(endpoint)
      @idle_timeout = idle_timeout
      @token = ''
    end

    def unlock(options = {}, secret = '')
      response = connection.post \
        '/unlock',
        {'key_or_wif': secret}.to_json,
        {'Accept' => 'application/json',
         'Content-Type' => 'application/json'}
      response.assert_success!
      Rails.logger.warn { response.body }
      response = JSON.parse(response.body)
      @token = response.fetch(:token)
      response['error'].tap { |error| raise ResponseError.new(error['code'], error['message']) if error }
      response
    rescue Faraday::Error => e
      raise ConnectionError, e
    rescue StandardError => e
      raise Error, e
    end

    def rest_call_get(url)
      response = connection.get \
        url,
        {'Accept' => 'application/json',
         'Content-Type' => 'application/json',
         'Authorization' => 'Bearer ' + @token}
      response.assert_success!
      response = JSON.parse(response.body)
      response['error'].tap { |error| raise ResponseError.new(error['code'], error['message']) if error }
      response
    rescue Faraday::Error => e
      raise ConnectionError, e
    rescue StandardError => e
      raise Error, e
    end

    def rest_call_post(url, params = {})
      response = connection.post \
        url,
        params.to_json,
        {'Accept' => 'application/json',
         'Content-Type' => 'application/json',
         'Authorization' => 'Bearer ' + @token}
      response.assert_success!
      response = JSON.parse(response.body)
      response['error'].tap { |error| raise ResponseError.new(error['code'], error['message']) if error }
      response
    rescue Faraday::Error => e
      raise ConnectionError, e
    rescue StandardError => e
      raise Error, e
    end

    private

    def connection
      Faraday.new(@json_rpc_endpoint).tap do |connection|
        unless @json_rpc_endpoint.user.blank?
          connection.basic_auth(@json_rpc_endpoint.user, @json_rpc_endpoint.password)
        end
      end
    end
    memoize :connection
  end
end
