# frozen_string_literal: true

class ChoujiangParticipant < ActiveRecord::Base
  belongs_to :choujiang_record
  belongs_to :user
  belongs_to :post

  validates :choujiang_record_id, presence: { message: "抽奖记录ID不能为空" }
  validates :user_id, presence: { message: "用户ID不能为空" }
  validates :post_id, presence: { message: "帖子ID不能为空" }

  # Ensure a user can only participate once per lottery
  validates :user_id, uniqueness: { 
    scope: :choujiang_record_id, 
    message: "每个用户在同一抽奖中只能参与一次" 
  }

  # Winner ranking validation
  validates :winner, numericality: { 
    only_integer: true, 
    greater_than: 0,
    allow_nil: true,
    message: "中奖排名必须是正整数" 
  }

  # Scopes
  scope :winners, -> { where.not(winner: nil) }
  scope :non_winners, -> { where(winner: nil) }
  scope :by_winner_rank, -> { order(:winner) }
end