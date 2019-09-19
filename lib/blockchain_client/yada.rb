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
      rest_call_get('/explorer-get-balance?address=' + address)['balance'].to_d
    end

    def load_deposit!(txid)
      tx = rest_call_get('/get-transaction?id=' + normalize_txid(txid))
      build_standalone_deposit(tx)
    end

    def create_address!(options = {})
      result = rest_call_post('/generate-child-wallet', options)
      {address: result['address']} 
    end

    def create_withdrawal!(issuer, recipient, amount, options = {})
      #json_rpc(:settxfee, [options[:fee]]) if options.key?(:fee)
      rest_call_post('/send-transaction', {
        'from': normalize_address(issuer.fetch(:address)), 
        'address': normalize_address(recipient.fetch(:address)), 
        'value': amount
      })['id']
    end

    def latest_block_number
      rest_call_get('/get-height')['height']
    end

    def get_block_by_index(block_index)
      rest_call_get('/get-block?index=' + block_index.to_s)
    end

    def get_block_hash(height)
      current_block   = height || 0
      rest_call_get('/get-block?index=' + current_block.to_s)['hash']
    end

    def to_address(tx)
      tx.fetch('outputs').map{|v| normalize_address(v['to'])}.compact
    end

    def build_transaction(tx, current_block, address)
      entries = tx.fetch('outputs').map do |item|

        next if item.fetch('value').to_d <= 0
        next if address != normalize_address(item['to'])

        { amount:   item.fetch('value').to_d,
          address:  normalize_address(item['to']),
          txout:    item['n'] }
      end.compact

      { id:            normalize_txid(tx.fetch('id')),
        block_number:  current_block,
        entries:       entries }
    end

    def get_unconfirmed_txns
      tx = rest_call_get('/get-pending-transaction-ids')['txn_ids'].map(&method(:get_raw_transaction)))
    end

    def get_raw_transaction(txid)
      rest_call_get('/get-pending-transaction?id=' + txid)
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
    end
  end
end
