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
        next unless first_post

        info = ::Choujiang.parse_choujiang_info(first_post)
        next unless info

        next unless info[:draw_time] && Time.now >= info[:draw_time]
        next if topic.tags.exists?(name: drawn_tag)

        winners = ::Choujiang.select_winners(topic, info)
        next unless winners && winners.any?

        winner_users = User.where(id: winners)
        ::Choujiang.announce_winners(topic, winner_users, info)

        winner_users.each do |winner|
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
            Rails.logger.warn("choujiang: 通知获奖者失败 #{winner&.username}: #{e}")
          end
        end

        tag = Tag.find_or_create_by(name: drawn_tag)
        unless topic.tags.include?(tag)
          topic.tags << tag
          topic.save
        end

        # 开奖后：封贴不可回复，不可编辑主贴
        topic.update!(closed: true)
        topic.first_post.update!(locked_by_id: Discourse.system_user.id, locked_at: Time.now)
      end
    end
  end
end
