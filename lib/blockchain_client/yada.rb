# encoding: UTF-8
# frozen_string_literal: true

module BlockchainClient
  class Yada < Base
    def initialize(*)
      super
      @json_rpc_call_id  = 0
      @json_rpc_endpoint = URI.parse(blockchain.server)
    end

    def endpoint
      @json_rpc_endpoint
    end

    def load_balance!(address, _currency_id)
      address_with_balance = rest_call_get('/explorer-get-balance?address=' + address)

      if address_with_balance.blank?
        raise Peatio::Blockchain::UnavailableAddressBalanceError, address
      end

      address_with_balance[1].to_d
    rescue Yada::Client::Error => e
      raise Peatio::Blockchain::ClientError, e
    end

    def load_deposit!(txid)
      json_rpc(:gettransaction, [normalize_txid(txid)]).fetch('result').yield_self { |tx| build_standalone_deposit(tx) }
    end

    def create_address!(options = {})
      { address: normalize_address(json_rpc(:getnewaddress).fetch('result')) }
    end

    def create_withdrawal!(issuer, recipient, amount, options = {})
      json_rpc(:settxfee, [options[:fee]]) if options.key?(:fee)
      json_rpc(:sendtoaddress, [normalize_address(recipient.fetch(:address)), amount])
        .fetch('result')
        .yield_self(&method(:normalize_txid))
    end

    def latest_block_number
      rest_call_get('/get-height')
    rescue Yada::Client::Error => e
      raise Peatio::Blockchain::ClientError, e
    end

    def get_block(block_hash)
      json_rpc(:getblock, [block_hash, 2]).fetch('result')
    end

    def get_block_hash(height)
      current_block   = height || 0
      json_rpc(:getblockhash, [current_block]).fetch('result')
    end

    def to_address(tx)
      tx.fetch('vout').map{|v| normalize_address(v['scriptPubKey']['addresses'][0]) if v['scriptPubKey'].has_key?('addresses')}.compact
    end

    def build_transaction(tx, current_block, address)
      entries = tx.fetch('vout').map do |item|

        next if item.fetch('value').to_d <= 0
        next unless item['scriptPubKey'].has_key?('addresses')
        next if address != normalize_address(item['scriptPubKey']['addresses'][0])

        { amount:   item.fetch('value').to_d,
          address:  normalize_address(item['scriptPubKey']['addresses'][0]),
          txout:    item.fetch('n') }
      end.compact

      { id:            normalize_txid(tx.fetch('txid')),
        block_number:  current_block,
        entries:       entries }
    end

    def get_unconfirmed_txns
      json_rpc(:getrawmempool).fetch('result').map(&method(:get_raw_transaction))
    end

    def get_raw_transaction(txid)
      json_rpc(:getrawtransaction, [txid, true]).fetch('result')
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
