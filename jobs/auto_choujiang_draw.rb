# frozen_string_literal: true

module ::Jobs
  class AutoChoujiangDraw < ::Jobs::Scheduled
    every 5.minutes

    def execute(args)
      return unless SiteSetting.choujiang_enabled?

      topics = ::Choujiang.choujiang_topics
      Rails.logger.warn("【Choujiang调试】找到了#{topics.count}个抽奖主题")
      topics.each do |topic|
        first_post = topic.first_post
        info = ::Choujiang.parse_choujiang_info(first_post)
        Rails.logger.warn("【Choujiang调试】主题ID:#{topic.id} info:#{info.inspect} now:#{Time.now}")
        next unless info[:draw_time] && Time.now >= info[:draw_time]
        next if topic.tags.include?("choujiang_drawn")
        winners = ::Choujiang.select_winners(topic, info)
        Rails.logger.warn("【Choujiang调试】主题ID:#{topic.id} 抽中的用户:#{winners.inspect}")
        ::Choujiang.announce_winners(topic, winners, info)
        topic.tags << "choujiang_drawn"
        topic.save
      end
    end
  end
end
