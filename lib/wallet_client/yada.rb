# encoding: UTF-8
# frozen_string_literal: true

module WalletClient
  class Yada < Base

    def initialize(*)
      super
      @json_rpc_endpoint = URI.parse(wallet.uri)
    end

    def create_address!(options = {})
        result = rest_call_post('/generate-child-wallet', _options)
        {address: result['address']} 
    end

    def create_withdrawal!(issuer, recipient, amount, options = {})
      options.merge!(subtract_fee: false) unless options.has_key?(:subtract_fee)

      json_rpc(:settxfee, [options[:fee]]) if options.key?(:fee)
      json_rpc(:sendtoaddress, [normalize_address(recipient.fetch(:address)), amount, '', '', options[:subtract_fee]])
          .fetch('result')
          .yield_self(&method(:normalize_txid))
    end

    def inspect_address!(address)
      json_rpc(:validateaddress, [normalize_address(address)]).fetch('result').yield_self do |x|
        { address: normalize_address(address), is_valid: !!x['isvalid'] }
      end
    end

    def load_balance!(_address, _currency)
      json_rpc(:getbalance).fetch('result').to_d
    end

    protected

    def connection
      Faraday.new(@json_rpc_endpoint).tap do |connection|
        unless @json_rpc_endpoint.user.blank?
          connection.basic_auth(@json_rpc_endpoint.user, @json_rpc_endpoint.password)
        end
      end
    end
    memoize :connection

    def rest_call_get(url)
      response = connection.get \
        url,
        {'Accept' => 'application/json',
         'Content-Type' => 'application/json'}
      response.assert_success!
      response = JSON.parse(response.body)
      response['error'].tap { |error| raise ResponseError.new(error['code'], error['message']) if error }
      response
    rescue Faraday::Error => e
      raise ConnectionError, e
    rescue StandardError => e
      raise Error, e
    end

    def rest_call_post(url, params = [])
      response = connection.post \
        url,
        params.to_json,
        {'Accept' => 'application/json',
         'Content-Type' => 'application/json'}
      response.assert_success!
      response = JSON.parse(response.body)
      response['error'].tap { |error| raise ResponseError.new(error['code'], error['message']) if error }
      response
    rescue Faraday::Error => e
      raise ConnectionError, e
    rescue StandardError => e
      raise Error, e
    end
  end
end
