# frozen_string_literal: true

class ChoujiangRecord < ActiveRecord::Base
  belongs_to :topic
  belongs_to :post
  belongs_to :user
  has_many :choujiang_participants, dependent: :destroy

  # Required field validations
  validates :choujiang_title, presence: { message: "抽奖名称不能为空" }, 
                              length: { minimum: 1, maximum: 255, message: "抽奖名称长度必须在1-255字符之间" }
  
  validates :choujiang_prize, presence: { message: "奖品不能为空" },
                              length: { minimum: 1, maximum: 255, message: "奖品描述长度必须在1-255字符之间" }
  
  validates :winner_count, presence: { message: "获奖人数不能为空" },
                           numericality: { 
                             only_integer: true, 
                             greater_than: 0, 
                             less_than_or_equal_to: 1000,
                             message: "获奖人数必须是1-1000之间的正整数" 
                           }
  
  validates :draw_time, presence: { message: "开奖时间不能为空" }
  
  validates :topic_id, presence: { message: "主题ID不能为空" }
  validates :post_id, presence: { message: "帖子ID不能为空" }
  validates :user_id, presence: { message: "用户ID不能为空" }

  # Custom validations
  validate :draw_time_must_be_future
  validate :draw_time_format_valid

  private

  def draw_time_must_be_future
    return unless draw_time.present?
    
    if draw_time <= Time.current
      errors.add(:draw_time, "开奖时间必须是未来的时间")
    end
  end

  def draw_time_format_valid
    return unless draw_time.present?
    
    # Ensure the time is a valid DateTime object
    unless draw_time.is_a?(Time) || draw_time.is_a?(DateTime)
      errors.add(:draw_time, "开奖时间格式无效")
    end
  end

  # Class method for validation without saving
  def self.validate_lottery_params(params)
    record = new(params)
    record.valid?
    record.errors
  end

  # Scope for active (not drawn) lotteries
  scope :active, -> { where(drawn: false) }
  scope :drawn, -> { where(drawn: true) }
end