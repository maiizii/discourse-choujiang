# frozen_string_literal: true

module ::Jobs
  class AutoChoujiangDraw < ::Jobs::Scheduled
    every 5.minutes

    def execute(args)
      Rails.logger.warn("choujiang: start job at #{Time.now}")

      return unless SiteSetting.choujiang_enabled?

      topics = ::Choujiang.choujiang_topics
      Rails.logger.warn("choujiang: found #{topics.count} choujiang topics")

      drawn_tag = SiteSetting.choujiang_drawn_tag.presence || "choujiang_drawn"

      topics.each do |topic|
        first_post = topic.first_post
        unless first_post
          Rails.logger.warn("choujiang: topic #{topic.id} has no first_post, skip")
          next
        end

        info = ::Choujiang.parse_choujiang_info(first_post)
        unless info
          Rails.logger.warn("choujiang: topic #{topic.id} parse_choujiang_info returned nil, skip")
          next
        end

        unless info[:draw_time] && Time.now >= info[:draw_time]
          Rails.logger.warn("choujiang: topic #{topic.id} not time to draw or missing draw_time, skip")
          next
        end

        if topic.tags.exists?(name: drawn_tag)
          Rails.logger.warn("choujiang: topic #{topic.id} already drawn, skip")
          next
        end

        winners = ::Choujiang.select_winners(topic, info)
        unless winners && winners.any?
          Rails.logger.warn("choujiang: topic #{topic.id} no winners found, skip")
          next
        end

        winner_users = User.where(id: winners)
        Rails.logger.warn("choujiang: topic #{topic.id} winners: #{winner_users.map(&:username).join(', ')}")

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
            Rails.logger.warn("choujiang: 通知已发送给获奖者 #{winner.username}")
          rescue => e
            Rails.logger.warn("choujiang: 通知获奖者失败 #{winner&.username}: #{e}")
          end
        end

        tag = Tag.find_or_create_by(name: drawn_tag)
        unless topic.tags.include?(tag)
          topic.tags << tag
          topic.save
        end
        Rails.logger.warn("choujiang: topic #{topic.id} draw complete, tag added")
      end
    end
  end
end
