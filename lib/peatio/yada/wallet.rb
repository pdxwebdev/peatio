module Yada
  class Wallet < Peatio::Wallet::Abstract

    def initialize(settings = {})
      @settings = settings
    end

    def configure(settings = {})
      # Clean client state during configure.
      @client = nil

      @settings.merge!(settings.slice(*SUPPORTED_SETTINGS))

      @wallet = @settings.fetch(:wallet) do
        raise Peatio::Wallet::MissingSettingError, :wallet
      end.slice(:uri, :address)

      @currency = @settings.fetch(:currency) do
        raise Peatio::Wallet::MissingSettingError, :currency
      end.slice(:id, :base_factor, :options)
    end

    def create_address!(_options = {})
      client.unlock(_options, @wallet.fetch(:secret))
      result = client.rest_call_post('/generate-child-wallet', _options)
      {address: result['address']} 
    rescue Yada::Client::Error => e
      raise Peatio::Wallet::ClientError, e
    end

    def create_transaction!(transaction, options = {})
      client.unlock(_options, @wallet.fetch(:secret))
      client.rest_call_post(
        '/sign-transaction',
        {
          to: transaction.to_address,
          value: transaction.amount,
          from: @wallet.fetch(:address)
        }
      )
    rescue Yada::Client::Error => e
      raise Peatio::Wallet::ClientError, e
    end

    def load_balance!
      addresses = client.rest_call_get('/get-addresses')['addresses']
      client.rest_call_post(
        '/get-balance-sum',
        addresses: addresses).to_d

    rescue Yada::Client::Error => e
      raise Peatio::Wallet::ClientError, e
    end

    private

    def client
      uri = @wallet.fetch(:uri) { raise Peatio::Wallet::MissingSettingError, :uri }
      @client ||= Client.new(uri, idle_timeout: 10)
    end
  end
end
