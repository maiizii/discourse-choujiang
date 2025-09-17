# name: discourse-choujiang
# about: 定时自动开奖的抽奖（choujiang）插件，支持自定义规则与自动开奖
# version: 0.5
# authors: maiizii
# url: https://github.com/maiizii/discourse-choujiang

enabled_site_setting :choujiang_enabled

# 提前定义命名空间 & Engine，避免自动加载顺序问题
module ::DiscourseChoujiang
  class Engine < ::Rails::Engine
    engine_name "discourse_choujiang_create"
    isolate_namespace DiscourseChoujiang
  end
end

after_initialize do
  # 依赖加载
  begin
    require_relative 'lib/discourse_choujiang/gamification_points'
  rescue => e
    Rails.logger.warn("[discourse-choujiang] gamification_points load failed: #{e.message}")
  end
  begin
    require_relative 'lib/discourse_choujiang/participant_filter'
  rescue => e
    Rails.logger.warn("[discourse-choujiang] participant_filter load failed: #{e.message}")
  end

  require_relative 'lib/choujiang'
  require_relative 'jobs/auto_choujiang_draw.rb'

  # 路由（带一个调试 ping）
  DiscourseChoujiang::Engine.routes.draw do
    post "/create" => "create#create"
    get "/ping" => proc { [200, { "Content-Type" => "application/json" }, ['{"ok":true}']] }
  end

  unless defined?(@@choujiang_routes_mounted) && @@choujiang_routes_mounted
    Discourse::Application.routes.append do
      mount ::DiscourseChoujiang::Engine, at: "/lottery"
    end
    @@choujiang_routes_mounted = true
    Rails.logger.info("[discourse-choujiang] Mounted /lottery routes (create, ping)")
  end
end
