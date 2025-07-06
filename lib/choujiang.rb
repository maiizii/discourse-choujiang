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
      # 把时间当作北京时间解析，自动转为UTC
      time_str = $1.strip
      info[:draw_time] = ActiveSupport::TimeZone['Beijing'].parse(time_str).utc rescue Time.parse(time_str).utc
    end
    info
  end

  def self.select_winners(topic, info)
    replies = Post.where(topic_id: topic.id)
                  .where.not(user_id: topic.user_id) # 剔除发起人
                  .where.not(post_number: 1)         # 剔除一楼
    unique_users = replies.select(:user_id).distinct.pluck(:user_id)
    winners = unique_users.sample(info[:winners])
    winners
  end

  def self.announce_winners(topic, winners, info)
    winner_names = User.where(id: winners).pluck(:username)
    result = "\n\n🎉 **抽奖已开奖！**\n\n抽奖名称：#{info[:title]}\n奖品：#{info[:prize]}\n获奖人数：#{info[:winners]}\n\n恭喜以下用户中奖：\n"
    winner_names.each_with_index do |name, idx|
      result += "#{idx+1}. @#{name}\n"
    end
    # 将开奖结果直接添加到原帖内容后
    first_post = topic.first_post
    new_raw = first_post.raw + result
    first_post.update!(raw: new_raw)
  end
end
