# name: discourse-choujiang
# about: 定时自动开奖的抽奖（choujiang）插件，支持自定义规则与自动开奖
# version: 0.2
# authors: macgow
# url: https://github.com/macgowge/discourse-choujiang

enabled_site_setting :choujiang_enabled

after_initialize do
  require_relative 'lib/choujiang'
  require_relative 'jobs/auto_choujiang_draw.rb'

  # 测试 after_initialize 是否执行
  Rails.logger.warn("choujiang plugin after_initialize called!")

  # Discourse 3.x 官方推荐内容校验方法
  register_post_custom_validator("choujiang_validator") do |raw, topic, user|
    Rails.logger.warn("choujiang custom validator called!")
    # 只校验主题首贴且有“抽奖活动”标签
    if topic && topic.first_post_id == topic.id
      tags = topic.tags.map(&:name) rescue []
      if tags.include?("抽奖活动")
        errors = []
        errors << "缺少抽奖名称" unless raw.match?(/抽奖名称[:：]\s*.+/)
        errors << "缺少奖品" unless raw.match?(/奖品[:：]\s*.+/)
        errors << "缺少获奖人数" unless raw.match?(/获奖人数[:：]\s*\d+/)
        errors << "缺少开奖时间" unless raw.match?(/开奖时间[:：]\s*[\d\- :]+/)
        errors # 返回 errors 数组，内容会显示在前端
      end
    end
  end
end
