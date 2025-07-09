# name: discourse-choujiang
# about: 定时自动开奖的抽奖（choujiang）插件，支持自定义规则与自动开奖
# version: 0.2
# authors: macgow
# url: https://github.com/macgowge/discourse-choujiang

enabled_site_setting :choujiang_enabled

after_initialize do
  require_relative 'lib/choujiang'
  require_relative 'jobs/auto_choujiang_draw.rb'

  # 极简钩子：所有新主题首贴一律禁止发帖，测试validate_post钩子是否生效
  on(:validate_post) do |post|
    next unless post.post_number == 1
    post.errors.add(:base, "自定义测试错误：你看到这个说明validate_post钩子已生效")
  end
end
