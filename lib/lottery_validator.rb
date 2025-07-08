# frozen_string_literal: true

module ::Choujiang
  class LotteryValidator
    attr_reader :errors

    def initialize
      @errors = []
    end

    # Validate lottery information parsed from post content
    def validate_lottery_info(info, topic_id = nil, post_id = nil, user_id = nil)
      @errors = []
      
      # Validate required fields
      validate_title(info[:title])
      validate_prize(info[:prize])
      validate_winners(info[:winners])
      validate_draw_time(info[:draw_time])
      
      # Validate IDs if provided
      validate_topic_id(topic_id) if topic_id
      validate_post_id(post_id) if post_id
      validate_user_id(user_id) if user_id
      
      valid?
    end

    # Create and validate a ChoujiangRecord from parsed info
    def create_lottery_record(info, topic_id, post_id, user_id)
      record_params = {
        choujiang_title: info[:title],
        choujiang_prize: info[:prize], 
        winner_count: info[:winners],
        draw_time: info[:draw_time],
        topic_id: topic_id,
        post_id: post_id,
        user_id: user_id,
        description: info[:description]
      }

      record = ChoujiangRecord.new(record_params)
      
      unless record.valid?
        @errors = record.errors.full_messages
        return nil
      end

      record
    end

    def valid?
      @errors.empty?
    end

    def error_messages
      @errors
    end

    private

    def validate_title(title)
      if title.blank?
        @errors << "抽奖名称不能为空"
      elsif title.length > 255
        @errors << "抽奖名称长度不能超过255个字符"
      end
    end

    def validate_prize(prize)
      if prize.blank?
        @errors << "奖品不能为空"
      elsif prize.length > 255
        @errors << "奖品描述长度不能超过255个字符"
      end
    end

    def validate_winners(winners)
      if winners.blank? || winners == 0
        @errors << "获奖人数不能为空或为0"
      elsif !winners.is_a?(Integer) || winners < 1
        @errors << "获奖人数必须是正整数"
      elsif winners > 1000
        @errors << "获奖人数不能超过1000"
      end
    end

    def validate_draw_time(draw_time)
      if draw_time.blank?
        @errors << "开奖时间不能为空"
      elsif !draw_time.is_a?(Time) && !draw_time.is_a?(DateTime)
        @errors << "开奖时间格式无效"
      elsif draw_time <= Time.current
        @errors << "开奖时间必须是未来的时间"
      end
    end

    def validate_topic_id(topic_id)
      if topic_id.blank?
        @errors << "主题ID不能为空"
      elsif !Topic.exists?(topic_id)
        @errors << "指定的主题不存在"
      end
    end

    def validate_post_id(post_id)
      if post_id.blank?
        @errors << "帖子ID不能为空"
      elsif !Post.exists?(post_id)
        @errors << "指定的帖子不存在"
      end
    end

    def validate_user_id(user_id)
      if user_id.blank?
        @errors << "用户ID不能为空"
      elsif !User.exists?(user_id)
        @errors << "指定的用户不存在"
      end
    end
  end
end