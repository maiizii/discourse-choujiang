# name: discourse-choujiang
# about: 定时自动开奖的抽奖（choujiang）插件，支持自定义规则与自动开奖
# version: 0.2
# authors: macgow
# url: https://github.com/macgowge/discourse-choujiang

enabled_site_setting :choujiang_enabled

after_initialize do
  require_relative 'lib/choujiang'
  require_relative 'jobs/auto_choujiang_draw.rb'

  # 官方推荐的注册方式
  DiscourseEvent.register(:post_process_cooked) do |doc, post|
    # 这个事件可以确认插件代码被执行
    Rails.logger.warn("choujiang post_process_cooked called!") # 你应该能在日志中看到这行
  end

  # 重点：注册自定义发帖校验器（3.2+官方推荐）
  register_post_custom_validator("choujiang_validator") do |raw, topic, user|
    Rails.logger.warn("choujiang custom validator called!") # 一定要能看到

    # 只校验主题首贴且有“抽奖活动”标签
    if topic.nil? || topic.first_post_id.nil?
      # 新建主题时topic还未创建，这时没法校验标签
      next
    end

    tags = topic.tags.map(&:name) rescue []
    next unless tags.include?("抽奖活动")

    errors = []
    errors << "缺少抽奖名称" unless raw.match?(/抽奖名称[:：]\s*.+/)
    errors << "缺少奖品" unless raw.match?(/奖品[:：]\s*.+/)
    errors << "缺少获奖人数" unless raw.match?(/获奖人数[:：]\s*\d+/)
    errors << "缺少开奖时间" unless raw.match?(/开奖时间[:：]\s*[\d\- :]+/)
    errors
  end
end
