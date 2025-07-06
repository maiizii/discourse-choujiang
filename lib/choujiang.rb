module ::Choujiang
  def self.choujiang_topics
    # 查找所有待开奖的主题（用choujiang标签）
    Topic.joins(:tags).where(tags: { name: SiteSetting.choujiang_tag }).where(closed: false)
  end

  def self.parse_choujiang_info(post)
    info = {}
    if post.raw =~ /抽奖名称[:：]\s*(.+)/
      info[:title] = $1.strip
    end
    if post.raw =~ /奖品[:：]\s*(.+)/
      info[:prize] = $1.strip
    end
    if post.raw =~ /获奖人数[:：]\s*(\d+)/
      info[:winners] = $1.to_i
    end
    if post.raw =~ /开奖时间[:：]\s*([0-9\- :]+)/
      info[:draw_time] = Time.parse($1)
    end
    info
  end

  def self.select_winners(topic, info)
    replies = Post.where(topic_id: topic.id)
                  .where.not(user_id: topic.user_id) # 剔除发起人
                  .where.not(post_number: 1)         # 剔除一楼
                  .order(:created_at)
    unique_users = replies.select(:user_id).distinct.pluck(:user_id)
    winners = unique_users.sample(info[:winners])
    winners
  end

  def self.announce_winners(topic, winners, info)
    winner_names = User.where(id: winners).pluck(:username)
    result = "🎉 **抽奖已开奖！**\n\n抽奖名称：#{info[:title]}\n奖品：#{info[:prize]}\n获奖人数：#{info[:winners]}\n\n恭喜以下用户中奖：\n"
    winner_names.each_with_index do |name, idx|
      result += "#{idx+1}. @#{name}\n"
    end
    PostCreator.create!(Discourse.system_user, topic_id: topic.id, raw: result)
  end
end
