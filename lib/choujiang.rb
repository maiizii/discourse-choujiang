# frozen_string_literal: true

module ::Choujiang

  PLUGIN_NAME ||= "discourse-choujiang".freeze
  
  # 解析抽奖信息的方法，将从帖子内容中提取关键信息
  def self.parse_choujiang_info(post)
    return nil if post.nil?

    info = { post_id: post.id, topic_id: post.topic_id, user_id: post.user_id }
    
    # 尝试解析帖子中的抽奖信息
    if post.raw =~ /抽奖名称[:：]\s*(.+?)[\n\r]/
      info[:title] = $1.strip
    end
    
    if post.raw =~ /活动奖品[:：]\s*(.+?)[\n\r]/
      info[:prize] = $1.strip
    end
    
    if post.raw =~ /获奖人数[:：]\s*(\d+)/
      info[:winners_count] = $1.to_i
    end
    
    # 时区处理 - 使用上海时区解析时间
    if post.raw =~ /开奖时间[:：]\s*([0-9\- :]+)/
      time_str = $1.strip
      Rails.logger.warn("choujiang debug: 原始时间字符串 #{time_str}")
      
      begin
        # 将输入时间视为上海时区(UTC+8)时间，然后转换为UTC存储
        parsed_time = ActiveSupport::TimeZone['Asia/Shanghai'].parse(time_str)
        Rails.logger.warn("choujiang debug: 解析后的上海时间 #{parsed_time}, UTC时间 #{parsed_time.utc}")
        info[:draw_time] = parsed_time.utc
      rescue => e
        Rails.logger.warn("choujiang debug: 时间解析错误 #{e.message}")
        # 备用解析方法
        begin
          info[:draw_time] = Time.parse(time_str).utc
          Rails.logger.warn("choujiang debug: 备用解析时间 #{info[:draw_time]}")
        rescue => e2
          Rails.logger.warn("choujiang debug: 备用时间解析也失败 #{e2.message}")
          info[:draw_time] = nil
        end
      end
    end
    
    # 解析积分要求 (v0.4新功能)
    if post.raw =~ /最低积分[:：]\s*(\d+)/
      info[:min_points] = $1.to_i
      Rails.logger.warn("choujiang debug: 解析到最低积分要求 #{info[:min_points]}")
    else
      info[:min_points] = 0
      Rails.logger.warn("choujiang debug: 未设置最低积分要求")
    end
    
    if post.raw =~ /简单说明[:：]\s*(.+?)[\n\r]/
      info[:description] = $1.strip
    end
    
    # 检查必要信息是否完整
    return nil if info[:title].nil? || info[:prize].nil? || info[:winners_count].nil? || info[:draw_time].nil?
    
    # 记录日志，方便调试
    Rails.logger.warn("choujiang debug: 成功解析抽奖信息: #{info.inspect}")
    
    info
  end
  
  # 获取有效的参与者
  def self.get_participants(topic_id, user_id, min_points = 0)
    topic = Topic.find_by(id: topic_id)
    return [] if topic.nil?
    
    # 获取除了发帖人以外的所有回复者
    participants = Set.new
    user_ids_with_points = {}
    
    PostCreator.create(
      Discourse.system_user,
      topic_id: topic_id,
      raw: "正在统计参与者...",
      skip_validations: true
    )
    
    # 获取所有回帖用户
    Post.where(topic_id: topic_id).where.not(user_id: user_id).find_each do |post|
      next if post.user_id == user_id # 跳过发帖人
      
      # 如果设置了积分要求，检查用户积分
      if min_points > 0
        # 尝试多种方式获取用户积分，兼容不同版本的discourse-gamification插件
        user_points = get_user_points(post.user_id)
        Rails.logger.warn("choujiang debug: 用户#{post.user_id}的积分为#{user_points}, 最低要求#{min_points}")
        
        # 只有积分满足要求的用户才能参与抽奖
        if user_points >= min_points
          participants.add(post.user_id)
          user_ids_with_points[post.user_id] = user_points
        else
          Rails.logger.warn("choujiang debug: 用户#{post.user_id}积分不足，不参与抽奖")
        end
      else
        # 没有积分要求，所有回帖用户都可以参与
        participants.add(post.user_id)
      end
    end
    
    Rails.logger.warn("choujiang debug: 共有#{participants.size}名有效参与者")
    
    # 返回有效参与者的user_id数组
    participants.to_a
  end
  
  # 获取用户积分 - 兼容多种积分存储方式
  def self.get_user_points(user_id)
    return 0 if user_id.nil?
    
    # 方法1: 通过discourse-gamification插件的PluginStore获取积分
    points = PluginStore.get('discourse-gamification', "user_#{user_id}_points")
    Rails.logger.warn("choujiang debug: 方法1获取用户#{user_id}积分: #{points}")
    return points.to_i if points.present?
    
    # 方法2: 尝试其他可能的存储键名
    points = PluginStore.get('discourse-gamification', "points_#{user_id}")
    Rails.logger.warn("choujiang debug: 方法2获取用户#{user_id}积分: #{points}")
    return points.to_i if points.present?
    
    # 方法3: 如果有提供API方法
    if defined?(::DiscourseGamification) && ::DiscourseGamification.respond_to?(:get_user_points)
      points = ::DiscourseGamification.get_user_points(user_id)
      Rails.logger.warn("choujiang debug: 方法3获取用户#{user_id}积分: #{points}")
      return points.to_i if points.present?
    end
    
    # 如果都获取不到，默认返回0积分
    Rails.logger.warn("choujiang debug: 无法获取用户#{user_id}积分，默认为0")
    0
  end
  
  # 抽奖并发布结果
  def self.draw_and_announce(choujiang_info)
    Rails.logger.warn("choujiang debug: 开始抽奖流程, 信息: #{choujiang_info.inspect}")
    
    topic_id = choujiang_info[:topic_id]
    user_id = choujiang_info[:user_id]
    winners_count = choujiang_info[:winners_count]
    min_points = choujiang_info[:min_points] || 0
    
    participants = get_participants(topic_id, user_id, min_points)
    
    if participants.empty?
      # 没有参与者的情况
      Rails.logger.warn("choujiang debug: 没有有效参与者")
      PostCreator.create(
        Discourse.system_user,
        topic_id: topic_id,
        raw: "## 抽奖结果公告\n\n很遗憾，没有符合条件的参与者。\n\n#{min_points > 0 ? "本次抽奖要求最低积分：#{min_points}" : ""}\n\n抽奖已结束，感谢关注！",
        skip_validations: true
      )
      return
    end
    
    # 如果参与人数少于获奖人数，调整获奖人数
    actual_winners_count = [winners_count, participants.size].min
    Rails.logger.warn("choujiang debug: 有效参与者#{participants.size}人，将抽取#{actual_winners_count}名获奖者")
    
    # 随机抽取获奖者
    winners = participants.shuffle[0...actual_winners_count]
    Rails.logger.warn("choujiang debug: 抽取的获奖者ID: #{winners.inspect}")
    
    # 准备获奖者名单
    winner_names = []
    winners.each do |winner_id|
      user = User.find_by(id: winner_id)
      next unless user
      winner_names << "@#{user.username}"
      
      # 发送私信通知获奖者
      begin
        pm = PostCreator.create(
          Discourse.system_user,
          target_usernames: user.username,
          archetype: Archetype.private_message,
          title: "恭喜您在「#{choujiang_info[:title]}」中获奖！",
          raw: "恭喜您在「#{choujiang_info[:title]}」抽奖活动中获奖！\n\n奖品: #{choujiang_info[:prize]}\n\n请关注后续领奖信息。",
          skip_validations: true
        )
        Rails.logger.warn("choujiang debug: 已向获奖者#{user.username}发送私信通知")
      rescue => e
        Rails.logger.warn("choujiang debug: 向获奖者#{user.username}发送私信失败: #{e.message}")
      end
    end
    
    # 在主题中公布结果
    result_message = <<~TEXT
    ## 抽奖结果公告
    
    **活动名称**: #{choujiang_info[:title]}
    **奖品**: #{choujiang_info[:prize]}
    **参与人数**: #{participants.size}人
    #{min_points > 0 ? "**积分要求**: 最低#{min_points}积分" : ""}
    
    **获奖名单**:
    #{winner_names.join(", ")}
    
    恭喜以上获奖者！请等待后续领奖通知。
    TEXT
    
    # 创建结果公告帖
    Rails.logger.warn("choujiang debug: 创建抽奖结果公告帖")
    PostCreator.create(
      Discourse.system_user,
      topic_id: topic_id,
      raw: result_message,
      skip_validations: true
    )
    
    # 更新主题状态
    topic = Topic.find_by(id: topic_id)
    if topic
      # 添加"抽奖结束"标签
      topic.append_tags(["抽奖结束"])
      
      # 更新标题添加【已开奖】前缀
      unless topic.title.include?("【已开奖】")
        topic.title = "【已开奖】#{topic.title}"
        topic.save!
        Rails.logger.warn("choujiang debug: 已更新主题标题添加【已开奖】前缀")
      end
      
      # 锁定主题
      topic.update_status('closed', true, Discourse.system_user)
      Rails.logger.warn("choujiang debug: 已锁定主题")
    end
    
    Rails.logger.warn("choujiang debug: 抽奖流程完成")
  end
end
