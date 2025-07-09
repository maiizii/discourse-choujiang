# name: discourse-choujiang
# about: 定时自动开奖的抽奖（choujiang）插件，支持自定义规则与自动开奖
# version: 0.2
# authors: macgow
# url: https://github.com/macgowge/discourse-choujiang

enabled_site_setting :choujiang_enabled

after_initialize do
  require_relative 'lib/choujiang'
  require_relative 'jobs/auto_choujiang_draw.rb'

  # 新增：发帖时内容格式校验
  on(:validate_post) do |post|
    next unless post.post_number == 1
    tags = (post.respond_to?(:tags) && post.tags.presence) || (post.topic&.tags&.map(&:name) || [])
    next unless tags.include?("抽奖活动")
    # 校验四个字段
    required = [
      [/抽奖名称[:：]\s*.+/, "缺少抽奖名称"],
      [/奖品[:：]\s*.+/, "缺少奖品"],
      [/获奖人数[:：]\s*\d+/, "缺少获奖人数"],
      [/开奖时间[:：]\s*[\d\- :]+/, "缺少开奖时间"]
    ]
    required.each do |regex, errmsg|
      post.errors.add(:base, errmsg) unless post.raw.match?(regex)
    end
  end
end
