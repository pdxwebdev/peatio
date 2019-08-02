# encoding: UTF-8
# frozen_string_literal: true

describe API::V2::Management::RevenueShares, type: :request do
  before do
    defaults_for_management_api_v1_security_configuration!
    management_api_v1_security_configuration.merge! \
      scopes: {
        read_revenue_shares:  { permitted_signers: %i[alex jeff],       mandatory_signers: %i[alex] },
        write_revenue_shares: { permitted_signers: %i[alex jeff james], mandatory_signers: %i[alex jeff] }
    }
  end

  describe 'list revenue shares' do
    def request
      post_json '/api/v2/management/revenue-shares', multisig_jwt_management_api_v1({ data: data }, *signers)
    end

    let(:data) { {} }
    let(:signers) { %i[alex jeff] }
    let(:members) { create_list(:member, 10, :barong) }

    before do
      members.each do |member|
        create(:revenue_share, member: member)
      end
    end

    it 'returns revenue shares' do
      request
      expect(response).to have_http_status(200)
      expect(JSON.parse(response.body).map { |x| x.fetch('id') }).to eq RevenueShare.ordered.pluck(:id)
    end

    it 'paginates' do
      ids = RevenueShare.pluck(:id)
      data.merge!(page: 1, limit: 4)
      request
      expect(response).to have_http_status(200)
      expect(JSON.parse(response.body).map { |x| x.fetch('id') }).to eq ids[0...4]
      data.merge!(page: 2, limit: 4)
      request
      expect(response).to have_http_status(200)
      expect(JSON.parse(response.body).map { |x| x.fetch('id') }).to eq ids[4...8]
      data.merge!(page: 3, limit: 4)
      request
      expect(response).to have_http_status(200)
      expect(JSON.parse(response.body).map { |x| x.fetch('id') }).to eq ids[8...10]
    end

    it 'filters by state' do
      RevenueShare::STATES.each do |state|
        data.merge!(state: state)
        request
        expect(response).to have_http_status(200)
        expect(JSON.parse(response.body).count).to eq RevenueShare.where(state: state).count
      end
    end

    it 'filters by member_uid' do
      member = members.first
      data.merge!(member_uid: member.uid)
      request
      expect(response).to have_http_status(200)
      expect(JSON.parse(response.body).count).to eq RevenueShare.where(member: member).count
      data[:member_uid] = '1234567890'
      request
      expect(response.body).to match(/member_uid does not have a valid value/i)
    end

    it 'filters by parent_uid' do
      member = members.first
      data.merge!(parent_uid: member.uid)
      request
      expect(response).to have_http_status(200)
      expect(JSON.parse(response.body).count).to eq RevenueShare.where(parent: member).count
      data[:parent_uid] = '1234567890'
      request
      expect(response.body).to match(/parent_uid does not have a valid value/i)
    end
  end

  describe 'create revenue share' do
    let(:member) { create(:member, :barong) }
    let(:parent) { create(:member, :barong) }
    let(:percent) { 10.5 }
    let :data do
      { member_uid:  member.uid,
        parent_uid:  parent.uid,
        percent:     percent }
    end
    let(:signers) { %i[alex jeff] }

    def request
      post_json '/api/v2/management/revenue-shares/new', multisig_jwt_management_api_v1({ data: data }, *signers)
    end

    it 'creates new revenue share with state «active»' do
      request
      expect(response.status).to eq 201
      record = RevenueShare.find_by_id!(JSON.parse(response.body).fetch('id'))
      expect(record.percent).to eq 10.5
      expect(record.state).to eq 'active'
      expect(record.member).to eq member
      expect(record.parent).to eq parent
    end

    it 'creates new revenue share with state «disabled»' do
      data[:state] = 'disabled'
      request
      expect(response.status).to eq 201
      record = RevenueShare.find_by_id!(JSON.parse(response.body).fetch('id'))
      expect(record.percent).to eq 10.5
      expect(record.state).to eq 'disabled'
      expect(record.member).to eq member
      expect(record.parent).to eq parent
    end

    it 'denies access unless enough signatures are supplied' do
      data.merge!(state: :active)
      signers.clear.concat %i[james jeff]
      request
      expect(response.status).to eq 401
    end

    it 'validates member' do
      data.delete(:member_uid)
      request
      expect(response.body).to match(/member_uid is missing/i)
      data[:member_uid] = '1234567890'
      request
      expect(response.body).to match(/member must exist/i)
    end

    it 'validates parent' do
      data.delete(:parent_uid)
      request
      expect(response.body).to match(/parent_uid is missing/i)
      data[:parent_uid] = '1234567890'
      request
      expect(response.body).to match(/parent must exist/i)
    end

    it 'validates percent' do
      data.delete(:percent)
      request
      expect(response.body).to match(/percent is missing/i)
      data[:percent] = '100.01'
      request
      expect(response.body).to match(/percent must be less than or equal to 100/i)
      data[:percent] = '-0.01'
      request
      expect(response.body).to match(/percent must be greater than 0/i)
    end

    it 'validates state' do
      data[:state] = 'invalid'
      request
      expect(response.body).to match(/state does not have a valid value/i)
    end
  end

  describe 'get revenue share' do
    def request
      post_json '/api/v2/management/revenue-shares/get', multisig_jwt_management_api_v1({ data: data }, *signers)
    end

    let(:signers) { %i[alex jeff] }
    let(:data) { { id: record.id } }
    let(:record) { create(:revenue_share, member: member) }
    let(:member) { create(:member, :barong) }

    it 'returns revenue share by ID' do
      request
      expect(JSON.parse(response.body).fetch('id')).to eq record.id
    end
  end

  describe 'update revenue share' do
    def request
      put_json '/api/v2/management/revenue-shares/update', multisig_jwt_management_api_v1({ data: data }, *signers)
    end

    let(:member) { create(:member, :barong) }
    let(:parent) { create(:member, :barong) }
    let(:percent) { 0.5 }
    let(:signers) { %i[alex jeff] }
    let(:record) { create(:revenue_share, member: member, percent: percent) }
    let(:data) { { id: record.id, state: 'active' } }

    it 'validates revenue share id' do
      data[:id] = RevenueShare.last.id + 100
      request
      expect(response).to have_http_status(404)
    end

    it 'updates revenue share state' do
      data[:state] = 'disabled'
      request
      expect(response).to have_http_status(200)
      expect(JSON.parse(response.body).fetch('state')).to eq 'disabled'
    end

    it 'updates revenue share percent' do
      data.merge!(percent: '10.0')
      request
      expect(response).to have_http_status(200)
      expect(JSON.parse(response.body).fetch('percent')).to eq '10.0'
    end
  end
end
