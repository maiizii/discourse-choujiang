# name: discourse-choujiang
# about: 定时自动开奖的抽奖（choujiang）插件，支持自定义规则与自动开奖
# version: 0.4
# authors: maiizii
# url: https://github.com/maiizii/discourse-choujiang

enabled_site_setting :choujiang_enabled

after_initialize do
  # 核心逻辑/服务
  require_relative 'lib/discourse_choujiang/gamification_points'
  require_relative 'lib/discourse_choujiang/participant_filter'
  require_relative 'lib/discourse_choujiang/parser'
  require_relative 'lib/discourse_choujiang/points_controller'

  # 原有定时任务（请确保该文件存在并实现开奖；本文在后续步骤提供一个完整实现范例）
  require_relative 'jobs/auto_choujiang_draw.rb'

  # 为前端提供一个查询接口：返回当前用户积分与该话题最低积分
  Discourse::Application.routes.append do
    get '/choujiang/points' => 'discourse_choujiang/points#show'
  end
end

# 注册前端资源（为话题页展示“未达最低积分”的提示）
register_asset "javascripts/discourse/initializers/choujiang-minimum-points.js", :client
