# frozen_string_literal: true

module ::Jobs
  class AutoChoujiangDraw < ::Jobs::Scheduled
    every 5.minutes

    def execute(args)
      return unless SiteSetting.choujiang_enabled?

      topics = ::Choujiang.choujiang_topics
      Rails.logger.warn("【Choujiang调试】找到了#{topics.count}个抽奖主题")

      drawn_tag = SiteSetting.choujiang_drawn_tag.presence || "choujiang_drawn"

      topics.each do |topic|
        first_post = topic.first_post
        info = ::Choujiang.parse_choujiang_info(first_post)
        Rails.logger.warn("【Choujiang调试】主题ID:#{topic.id} info:#{info.inspect} now:#{Time.now}")

        # 判断是否到开奖时间
        next unless info[:draw_time] && Time.now >= info[:draw_time]
        # 判断是否已经开奖过
        next if topic.tags.exists?(name: drawn_tag)

        winners = ::Choujiang.select_winners(topic, info)
        Rails.logger.warn("【Choujiang调试】主题ID:#{topic.id} 抽中的用户:#{winners.inspect}")
        ::Choujiang.announce_winners(topic, winners, info)

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
