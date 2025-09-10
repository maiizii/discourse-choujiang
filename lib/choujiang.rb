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
        # Try Beijing timezone first (for Chinese users)
        info[:draw_time] = ActiveSupport::TimeZone['Beijing'].parse(time_str).utc
      rescue
        # Fallback to server default timezone
        begin
          info[:draw_time] = Time.parse(time_str).utc 
        rescue => e
          Rails.logger.warn("choujiang: Failed to parse time: #{time_str}, error: #{e.message}")
          info[:draw_time] = nil
        end
      end
    end
    # Parse minimum points requirement
    if post.raw =~ /最低积分[:：]\s*(\d+)/
      info[:min_points] = $1.to_i
    else
      info[:min_points] = 0  # Default is 0, meaning no restriction
    end
    info
  end

  def self.select_winners(topic, info)
    replies = Post.where(topic_id: topic.id)
                  .where.not(user_id: topic.user_id) # Exclude the topic starter
                  .where.not(post_number: 1)         # Exclude the first post
    unique_users = replies.select(:user_id).distinct.pluck(:user_id)
    
    # Filter users based on minimum points if specified
    if info[:min_points] && info[:min_points] > 0
      filtered_users = []
      
      unique_users.each do |user_id|
        # Use the correct method to get user points from discourse-gamification
        points = PluginStore.get('discourse-gamification', "user_#{user_id}_points").to_i
        
        # Add debug log
        Rails.logger.warn("choujiang debug: User #{user_id} has #{points} points, minimum required: #{info[:min_points]}")
        
        if points >= info[:min_points]
          filtered_users << user_id
        end
      end
      
      Rails.logger.warn("choujiang debug: Total participants: #{unique_users.length}, qualified participants: #{filtered_users.length}")
      unique_users = filtered_users
    end
    
    # Adjust winners count if there are fewer qualified participants than the required number of winners
    winners_count = [unique_users.length, info[:winners]].min
    winners = unique_users.sample(winners_count)
    
    # Add debug log
    Rails.logger.warn("choujiang debug: Selected #{winners.length} winners: #{winners.inspect}")
    
    winners
  end

  def self.announce_winners(topic, winners, info)
    winner_names = User.where(id: winners).pluck(:username)
    result = "\n\n🎉 **抽奖活动已开奖！** 🎉\n\n"
    
    # Show points requirement information if specified
    if info[:min_points] && info[:min_points] > 0
      result += "参与要求：最低积分 #{info[:min_points]} 点\n\n"
    end
    
    result += "恭喜以下用户中奖：\n"
    winner_names.each_with_index do |name, idx|
      result += "#{idx+1}. @#{name}\n"
    end

    # Add a note if no one won
    if winner_names.empty?
      result += "（没有符合条件的获奖者）\n"
    end

    # 1. Modify the original post to append the draw result
    first_post = topic.first_post
    new_raw = first_post.raw + result
    first_post.update!(raw: new_raw)

    # 2. Add winning mark to the first reply of each winner
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

    # 3. Update the topic title to add "【已开奖】"
    unless topic.title.start_with?("【已开奖】")
      topic.title = "【已开奖】" + topic.title
      topic.save!
    end
  end
end
