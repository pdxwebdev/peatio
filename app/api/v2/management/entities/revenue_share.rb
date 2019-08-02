# encoding: UTF-8
# frozen_string_literal: true

module API
  module V2
    module Management
      module Entities
        STATES = %w[
          «active» - revenue share takes part on dividing shares between users.
          «disabled» - revenue share does not take part on dividing shares between users. Since deleting of revenue share is not permitted disabling is equal to removing.
        ].freeze

        class RevenueShare < Base
          expose(
            :id,
            documentation: {
              type: String,
              desc: 'Revenue share unique identifier.'
            }
          )
          expose(
            :member_uid,
            documentation: {
              type: String,
              desc: 'Member user identifier. Defines member whose fees will be divided during revenue sharing.'
            }
          )
          expose(
            :parent_uid,
            documentation: {
              type: String,
              desc: 'Parent user identifier. Defines parent who will receive part of fees paid by member during revenue sharing.'
            }
          )
          expose(
            :percent,
            documentation: {
              type: BigDecimal,
              desc: 'Percentage of revenue share. Defines fees part which parent will receive during revenue sharing.'
            }
          )
          expose(
            :state,
            documentation: {
              type: String,
              desc: 'The revenue share state. ' + STATES.join(' ')
            }
          )
          expose(
            :created_at,
            format_with: :iso8601,
            documentation: {
              type: String,
              desc: 'Datetime of revenue share creation.'
            }
          )
        end
      end
    end
  end
end
