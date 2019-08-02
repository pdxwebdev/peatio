# encoding: UTF-8
# frozen_string_literal: true

describe API::V2::Management::Entities::RevenueShare do
  let(:record) { create(:revenue_share, member: create(:member, :barong), parent: create(:member, :barong)) }

  subject { OpenStruct.new API::V2::Management::Entities::RevenueShare.represent(record).serializable_hash }

  it { expect(subject.id).to eq record.id }
  it { expect(subject.member_uid).to eq record.member.uid }
  it { expect(subject.parent_uid).to eq record.parent.uid }
  it { expect(subject.state).to eq record.state }
  it { expect(subject.percent).to eq record.percent }
  it { expect(subject.created_at).to eq record.created_at.iso8601 }
end
