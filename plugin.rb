# name: discourse-choujiang
# about: 定时自动开奖的抽奖（choujiang）插件，支持自定义规则与自动开奖
# version: 0.5
# authors: maiizii
# url: https://github.com/maiizii/discourse-choujiang

enabled_site_setting :choujiang_enabled

after_initialize do
  # 积分与参与者过滤（最低积分功能使用）
  require_relative 'lib/discourse_choujiang/gamification_points'
  require_relative 'lib/discourse_choujiang/participant_filter'

  # 核心逻辑
  require_relative 'lib/choujiang'
  require_relative 'jobs/auto_choujiang_draw.rb'

  # 发布页面引擎（v0.5 新增）
  module ::DiscourseChoujiang
    class Engine < ::Rails::Engine
      engine_name "discourse_choujiang_create"
      isolate_namespace DiscourseChoujiang
    end
  end

  DiscourseChoujiang::Engine.routes.draw do
    post "/create" => "create#create"  # POST /lottery/create
  end

  Discourse::Application.routes.append do
    # 访问路径：/lottery/create
    mount ::DiscourseChoujiang::Engine, at: "/lottery"
  end
end
