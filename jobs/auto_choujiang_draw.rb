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
        info = ::Choujiang.parse_choujiang_info(first_post)
        # Rails.logger.warn("【Choujiang调试】主题ID:#{topic.id} info:#{info.inspect} now:#{Time.now}")

        # 判断是否到开奖时间
        next unless info[:draw_time] && Time.now >= info[:draw_time]
        # 判断是否已经开奖过
        next if topic.tags.exists?(name: drawn_tag)

        winners = ::Choujiang.select_winners(topic, info)
        # Rails.logger.warn("【Choujiang调试】主题ID:#{topic.id} 抽中的用户:#{winners.inspect}")
        ::Choujiang.announce_winners(topic, winners, info)

        # 新增：给每位中奖者发送一条站内信
        winners.each do |winner|
          begin
            PostCreator.create!(
              Discourse.system_user,
              target_usernames: winner.username,
              archetype: Archetype.private_message,
              subtype: TopicSubtype.system_message,
              title: "恭喜你中奖啦！",
              raw: <<~MD
                恭喜你在 [#{topic.title}](#{topic.relative_url}) 抽奖活动中获奖！

                奖品：#{info[:prize] || "（奖品信息未填写）"}

                请关注后续发奖通知，或与管理员联系领奖事宜。
              MD
            )
          rescue => e
            Rails.logger.warn("choujiang 通知获奖者失败: #{winner.username}: #{e}")
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
