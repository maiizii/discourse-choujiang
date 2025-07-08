# frozen_string_literal: true

module ::Jobs
  class AutoChoujiangDraw < ::Jobs::Scheduled
    every 5.minutes

    def execute(args)
      return unless SiteSetting.choujiang_enabled?

      topics = ::Choujiang.choujiang_topics
      # Rails.logger.warn("【Choujiang调试】找到了#{topics.count}个抽奖主题")

      drawn_tag = SiteSetting.choujiang_drawn_tag.presence || "choujiang_drawn"

      topics.each do |topic|
        first_post = topic.first_post
        
        # Validate lottery information before processing
        validation_result = ::Choujiang.validate_lottery_info(first_post)
        
        unless validation_result[:valid]
          Rails.logger.warn("Skipping invalid lottery in topic #{topic.id}: #{validation_result[:errors].join(', ')}")
          next
        end
        
        info = validation_result[:info]
        # Rails.logger.warn("【Choujiang调试】主题ID:#{topic.id} info:#{info.inspect} now:#{Time.now}")

        # 判断是否到开奖时间
        next unless info[:draw_time] && Time.now >= info[:draw_time]
        # 判断是否已经开奖过
        next if topic.tags.exists?(name: drawn_tag)

        winners = ::Choujiang.select_winners(topic, info)
        # Rails.logger.warn("【Choujiang调试】主题ID:#{topic.id} 抽中的用户:#{winners.inspect}")
        ::Choujiang.announce_winners(topic, winners, info)

        # Create lottery record in database if not exists
        existing_record = ChoujiangRecord.find_by(topic_id: topic.id, post_id: first_post.id)
        unless existing_record
          lottery_creation_result = ::Choujiang.create_lottery_from_post(first_post)
          if lottery_creation_result[:success]
            # Mark as drawn in the database
            lottery_creation_result[:lottery_record].update!(drawn: true, drawn_at: Time.current)
          end
        end

        # 正确添加可配置的开奖标签
        tag = Tag.find_or_create_by(name: drawn_tag)
        unless topic.tags.include?(tag)
          topic.tags << tag
          topic.save
        end
      end
    end
  end
end
