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
        # 添加调试日志
        Rails.logger.warn("choujiang debug: 原始时间字符串 #{time_str}")
        parsed_time = ActiveSupport::TimeZone['Beijing'].parse(time_str).utc
        Rails.logger.warn("choujiang debug: 解析后的UTC时间 #{parsed_time}, 当前UTC时间: #{Time.now.utc}")
        info[:draw_time] = parsed_time
      rescue => e
        Rails.logger.warn("choujiang debug: 时间解析错误 #{e}")
        begin
          info[:draw_time] = Time.parse(time_str).utc
          Rails.logger.warn("choujiang debug: 使用备用解析，UTC时间: #{info[:draw_time]}")
        rescue => e2
          Rails.logger.warn("choujiang debug: 备用解析也失败 #{e2}")
          info[:draw_time] = nil
        end
      end
    end
    # 解析最低积分要求
    if post.raw =~ /最低积分[:：]\s*(\d+)/
      info[:min_points] = $1.to_i
      Rails.logger.warn("choujiang debug: 设置了最低积分要求 #{info[:min_points]}")
    else
      info[:min_points] = 0  # 默认为0，表示不限制
      Rails.logger.warn("choujiang debug: 未设置积分要求，默认为0")
    end
    info
  end

  def self.select_winners(topic, info)
    Rails.logger.warn("choujiang debug: 开始选择中奖者，主题ID: #{topic.id}")
    
    replies = Post.where(topic_id: topic.id)
                  .where.not(user_id: topic.user_id) # 剔除发起人
                  .where.not(post_number: 1)         # 剔除一楼
    
    unique_users = replies.select(:user_id).distinct.pluck(:user_id)
    Rails.logger.warn("choujiang debug: 初始参与用户数: #{unique_users.length}")
    
    # 根据最低积分过滤用户
    if info[:min_points] && info[:min_points] > 0
      filtered_users = []
      unique_users.each do |user_id|
        user = User.find_by(id: user_id)
        next unless user
        
        # 尝试不同的方式获取用户积分
        points = nil
        
        # 方法1：通过PluginStore获取
        points = PluginStore.get('discourse-gamification', "user_#{user_id}_points")
        Rails.logger.warn("choujiang debug: 用户 #{user.username}(#{user_id}) 通过方法1获取积分: #{points}")
        
        # 方法2：尝试不同的键名
        if points.nil?
          points = PluginStore.get('discourse-gamification', "points_#{user_id}")
          Rails.logger.warn("choujiang debug: 用户 #{user.username}(#{user_id}) 通过方法2获取积分: #{points}")
        end
        
        # 方法3：尝试通过用户元数据
        if points.nil?
          points = user.custom_fields['gamification_points'].to_i rescue 0
          Rails.logger.warn("choujiang debug: 用户 #{user.username}(#{user_id}) 通过方法3获取积分: #{points}")
        end
        
        # 如果所有方法都失败，使用默认值0
        points ||= 0
        
        if points >= info[:min_points]
          filtered_users << user_id
          Rails.logger.warn("choujiang debug: 用户 #{user.username}(#{user_id}) 符合积分要求 (#{points} >= #{info[:min_points]})")
        else
          Rails.logger.warn("choujiang debug: 用户 #{user.username}(#{user_id}) 不符合积分要求 (#{points} < #{info[:min_points]})")
        end
      end
      unique_users = filtered_users
      Rails.logger.warn("choujiang debug: 过滤后符合积分要求的用户数: #{unique_users.length}")
    end
    
    # 如果符合条件的用户数少于要求的获奖人数，调整获奖人数
    winners_count = [unique_users.length, info[:winners]].min
    Rails.logger.warn("choujiang debug: 最终获奖人数: #{winners_count}, 请求获奖人数: #{info[:winners]}")
    
    if winners_count > 0
      winners = unique_users.sample(winners_count)
      Rails.logger.warn("choujiang debug: 已选择中奖者: #{winners.join(', ')}")
      return winners
    else
      Rails.logger.warn("choujiang debug: 无符合条件的用户，无法开奖")
      return []
    end
  end

  def self.announce_winners(topic, winners, info)
    Rails.logger.warn("choujiang debug: 开始公布中奖结果，主题ID: #{topic.id}, 中奖者数: #{winners.length}")
    
    winner_names = User.where(id: winners).pluck(:username)
    Rails.logger.warn("choujiang debug: 中奖者用户名: #{winner_names.join(', ')}")
    
    result = "\n\n🎉 **抽奖活动已开奖！** 🎉\n\n"
    
    # 显示最低积分要求信息
    if info[:min_points] && info[:min_points] > 0
      result += "参与要求：最低积分 #{info[:min_points]} 点\n\n"
    end
    
    result += "恭喜以下用户中奖：\n"
    
    if winner_names.any?
      winner_names.each_with_index do |name, idx|
        result += "#{idx+1}. @#{name}\n"
      end
    else
      result += "（没有符合条件的中奖者）\n"
    end

    # 1. 修改原帖内容，追加开奖结果
    first_post = topic.first_post
    new_raw = first_post.raw + result
    first_post.update!(raw: new_raw)
    Rails.logger.warn("choujiang debug: 已更新原帖内容，添加中奖结果")

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
        Rails.logger.warn("choujiang debug: 已在中奖者 #{User.find_by(id: user_id)&.username} 的回复中添加标注")
      end
    end

    # 3. 修改主题标题，前加【已开奖】
    unless topic.title.start_with?("【已开奖】")
      topic.title = "【已开奖】" + topic.title
      topic.save!
      Rails.logger.warn("choujiang debug: 已更新主题标题，添加【已开奖】前缀")
    end
    
    # 4. 给中奖者发送通知
    winners.each do |user_id|
      begin
        user = User.find_by(id: user_id)
        next unless user
        
        PostCreator.create!(
          Discourse.system_user,
          target_usernames: user.username,
          archetype: Archetype.private_message,
          subtype: TopicSubtype.system_message,
          title: "恭喜你中奖啦！",
          raw: <<~MD
            恭喜你在 [#{topic.title}](#{topic.relative_url}) 抽奖活动中获奖！

            活动奖品：#{info[:prize] || "（奖品信息未填写）"}

            请与抽奖活动组织者联系领奖事宜。
          MD
        )
        Rails.logger.warn("choujiang debug: 已向中奖者 #{user.username} 发送通知")
      rescue => e
        Rails.logger.warn("choujiang debug: 向中奖者 #{User.find_by(id: user_id)&.username} 发送通知失败: #{e}")
      end
    end
  end
end
