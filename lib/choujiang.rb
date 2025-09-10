module ::Choujiang
  def self.choujiang_topics
    Topic.joins(:tags)
         .where(tags: { name: SiteSetting.choujiang_tag })
         .where(closed: false)
  end

  def self.parse_choujiang_info(post)
    info = {}
    if post.raw =~ /抽奖名称[:：]\s*(.+)/
      info[:title] = $1.strip
    end
    if post.raw =~ /活动奖品[:：]\s*(.+)/
      info[:prize] = $1.strip
    end
    if post.raw =~ /获奖人数[:：]\s*(\d+)/
      info[:winners] = $1.to_i
    end
    if post.raw =~ /开奖时间[:：]\s*([0-9\- :]+)/
      time_str = $1.strip
      begin
        info[:draw_time] = ActiveSupport::TimeZone['Beijing'].parse(time_str).utc
      rescue
        info[:draw_time] = Time.parse(time_str).utc rescue nil
      end
    end
    # 新增：解析最低积分要求
    if post.raw =~ /最低积分[:：]\s*(\d+)/
      info[:min_points] = $1.to_i
    else
      info[:min_points] = 0  # 默认为0，表示不限制
    end
    info
  end

  def self.select_winners(topic, info)
    replies = Post.where(topic_id: topic.id)
                  .where.not(user_id: topic.user_id) # 剔除发起人
                  .where.not(post_number: 1)         # 剔除一楼
    unique_users = replies.select(:user_id).distinct.pluck(:user_id)
    
    # 新增：根据最低积分过滤用户
    if info[:min_points] && info[:min_points] > 0
      filtered_users = []
      unique_users.each do |user_id|
        user = User.find_by(id: user_id)
        next unless user
        
        # 通过PluginStore获取用户积分
        points = PluginStore.get('discourse-gamification', "user_#{user_id}_points") || 0
        
        if points >= info[:min_points]
          filtered_users << user_id
        end
      end
      unique_users = filtered_users
    end
    
    # 如果符合条件的用户数少于要求的获奖人数，调整获奖人数
    winners_count = [unique_users.length, info[:winners]].min
    winners = unique_users.sample(winners_count)
    winners
  end

  def self.announce_winners(topic, winners, info)
    winner_names = User.where(id: winners).pluck(:username)
    # result = "\n\n🎉 **抽奖已开奖！**\n\n抽奖名称：#{info[:title]}\n活动奖品：#{info[:prize]}\n获奖人数：#{info[:winners]}\n\n恭喜以下用户中奖：\n"
    result = "\n\n🎉 **抽奖活动已开奖！** 🎉\n\n"
    
    # 新增：显示最低积分要求信息
    if info[:min_points] && info[:min_points] > 0
      result += "参与要求：最低积分 #{info[:min_points]} 点\n\n"
    end
    
    result += "恭喜以下用户中奖：\n"
    winner_names.each_with_index do |name, idx|
      result += "#{idx+1}. @#{name}\n"
    end

    # 1. 修改原帖内容，追加开奖结果
    first_post = topic.first_post
    new_raw = first_post.raw + result
    first_post.update!(raw: new_raw)

    # 2. 给每个中奖者的首个回复添加中奖标注
    winners.each_with_index do |user_id, idx|
      post = Post.where(topic_id: topic.id, user_id: user_id)
                 .where.not(post_number: 1)
                 .order(:post_number)
                 .first
      next unless post
      mark = "\n\n---\n🎉 **已第#{idx+1}个中奖！** 🎉"
      unless post.raw.include?(mark)
        post.update!(raw: post.raw + mark)
      end
    end

    # 3. 修改主题标题，前加【已开奖】
    unless topic.title.start_with?("【已开奖】")
      topic.title = "【已开奖】" + topic.title
      topic.save!
    end
  end
end
