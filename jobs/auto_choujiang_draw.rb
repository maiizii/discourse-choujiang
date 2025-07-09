# frozen_string_literal: true

module ::Jobs
  class AutoChoujiangDraw < ::Jobs::Scheduled
    every 5.minutes

    def execute(args)
      return unless SiteSetting.choujiang_enabled?

      topics = ::Choujiang.choujiang_topics

      drawn_tag = SiteSetting.choujiang_drawn_tag.presence || "choujiang_drawn"

      topics.each do |topic|
        first_post = topic.first_post
        errors, info = ::Choujiang.parse_choujiang_info(first_post, raise_on_error: false)
        # 如果有格式错误或开奖时间不合规，跳过本主题，不抛异常
        next if errors.any?

        # 判断是否到开奖时间
        next unless info[:draw_time] && Time.now >= info[:draw_time]
        # 判断是否已经开奖过
        next if topic.tags.exists?(name: drawn_tag)

        winners = ::Choujiang.select_winners(topic, info)
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
