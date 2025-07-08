# name: discourse-choujiang
# about: 定时自动开奖的抽奖（choujiang）插件，支持自定义规则与自动开奖
# version: 0.3
# authors: macgow
# url: https://github.com/macgowge/discourse-choujiang

enabled_site_setting :choujiang_enabled

after_initialize do
  require_relative 'lib/choujiang'
  require_relative 'lib/choujiang_validator'
  require_relative 'lib/choujiang_post_validator'
  require_relative 'jobs/auto_choujiang_draw.rb'

  # 注册到 Post 模型（不是 PostValidator）
  Post.register_validator(ChoujiangPostValidator)
end
