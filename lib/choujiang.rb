module ::Choujiang
  def self.choujiang_topics
    Topic.joins(:tags)
         .where(tags: { name: SiteSetting.choujiang_tag })
         .where(closed: false)
  end

  # 发帖参数解析与校验：兼容原有 info 字段，供开奖等其他流程使用
  # 增加 raise_on_error 参数，后台任务用 false，发帖用默认 true
  def self.parse_choujiang_info(post, raise_on_error: true)
    require_relative "choujiang_validator"
    errors, info = ::ChoujiangValidator.parse_and_validate(post.raw)
    if errors.any? && raise_on_error
      raise Discourse::InvalidParameters, errors.join("，")
    end
    [errors, info]
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
end
