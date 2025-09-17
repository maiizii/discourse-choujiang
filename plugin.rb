# name: discourse-choujiang
# about: 定时自动开奖的抽奖（choujiang）插件，支持自定义规则与自动开奖
# version: 0.4
# authors: maiizii
# url: https://github.com/maiizii/discourse-choujiang

enabled_site_setting :choujiang_enabled

after_initialize do
  # 现有 require 保持
  require_relative 'lib/discourse_choujiang/gamification_points'
  require_relative 'lib/discourse_choujiang/participant_filter'
  require_relative 'lib/choujiang'
  require_relative 'jobs/auto_choujiang_draw.rb'

  # --- 新增：Engine + 路由 ---
  module ::DiscourseChoujiang
    class Engine < ::Rails::Engine
      engine_name "discourse_choujiang_create"
      isolate_namespace DiscourseChoujiang
    end
  end

  DiscourseChoujiang::Engine.routes.draw do
    post "/create" => "create#create"   # POST /choujiang/create
  end

  Discourse::Application.routes.append do
    mount ::DiscourseChoujiang::Engine, at: "/choujiang"
  end
end
