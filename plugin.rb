# name: discourse-choujiang
# about: 定时自动开奖的抽奖（choujiang）插件，支持自定义规则与自动开奖
# version: 0.2
# authors: macgow
# url: https://github.com/macgowge/discourse-choujiang

register_asset "javascripts/discourse/initializers/add-choujiang-template-button.js"
register_asset "javascripts/discourse/components/choujiang-template-modal.js"
register_asset "javascripts/discourse/templates/components/choujiang-template-modal.hbs"

enabled_site_setting :choujiang_enabled

after_initialize do
  require_relative 'lib/choujiang'
  require_relative 'jobs/auto_choujiang_draw.rb'
end
