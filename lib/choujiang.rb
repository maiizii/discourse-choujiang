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
    if post.raw =~ /奖品[:：]\s*(.+)/
      info[:prize] = $1.strip
    end
    if post.raw =~ /获奖人数[:：]\s*(\d+)/
      info[:winners] = $1.to_i
    end
    if post.raw =~ /开奖时间[:：]\s*(.+)/
      time_str = $1.strip
      begin
        info[:draw_time] = ActiveSupport::TimeZone['Beijing'].parse(time_str).utc
      rescue
        info[:draw_time] = Time.parse(time_str).utc rescue nil
      end
    end
    if post.raw =~ /其他说明[:：]\s*(.+)/
      info[:description] = $1.strip
    end
    info
  end

  # Validate lottery information with comprehensive error checking
  def self.validate_lottery_info(post)
    info = parse_choujiang_info(post)
    validator = Choujiang::LotteryValidator.new
    
    topic = post.topic
    is_valid = validator.validate_lottery_info(info, topic.id, post.id, post.user_id)
    
    {
      valid: is_valid,
      info: info,
      errors: validator.error_messages,
      lottery_record: is_valid ? validator.create_lottery_record(info, topic.id, post.id, post.user_id) : nil
    }
  end

  # Create a lottery record if validation passes
  def self.create_lottery_from_post(post)
    validation_result = validate_lottery_info(post)
    
    unless validation_result[:valid]
      Rails.logger.error("Lottery validation failed: #{validation_result[:errors].join(', ')}")
      return { success: false, errors: validation_result[:errors] }
    end

    begin
      lottery_record = validation_result[:lottery_record]
      lottery_record.save!
      
      Rails.logger.info("Successfully created lottery record ID: #{lottery_record.id}")
      { success: true, lottery_record: lottery_record }
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error("Failed to save lottery record: #{e.message}")
      { success: false, errors: [e.message] }
    end
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
      mark = "\n\n---\n🎉 已第#{idx+1}个中奖"
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

  # Hook for validating lottery posts on creation/update
  def self.validate_lottery_post(post)
    # Only validate if this is a lottery topic
    return { valid: true } unless is_lottery_topic?(post.topic)
    
    # Only validate the first post (lottery creation post)
    return { valid: true } unless post.post_number == 1
    
    validation_result = validate_lottery_info(post)
    
    unless validation_result[:valid]
      Rails.logger.warn("Lottery post validation failed for post #{post.id}: #{validation_result[:errors].join(', ')}")
    end
    
    validation_result
  end

  # Check if a topic is a lottery topic based on tags
  def self.is_lottery_topic?(topic)
    return false unless topic&.tags&.any?
    
    lottery_tag = SiteSetting.choujiang_tag
    topic.tags.any? { |tag| tag.name == lottery_tag }
  end

  # Utility method to get validation errors for a post
  def self.get_lottery_validation_errors(post)
    validation_result = validate_lottery_post(post)
    validation_result[:valid] ? [] : validation_result[:errors]
  end
end
