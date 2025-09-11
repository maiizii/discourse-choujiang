# name: discourse-choujiang
# about: 定时自动开奖的抽奖（choujiang）插件，支持自定义规则与自动开奖
# version: 0.4
# authors: maiizii
# url: https://github.com/maiizii/discourse-choujiang

enabled_site_setting :choujiang_enabled

after_initialize do
  # 新增：积分查询与参与者过滤（仅用于“最低积分”功能）
  require_relative 'lib/discourse_choujiang/gamification_points'
  require_relative 'lib/discourse_choujiang/participant_filter'

  # 原有逻辑
  require_relative 'lib/choujiang'
  require_relative 'jobs/auto_choujiang_draw.rb'
end
