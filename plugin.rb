# name: discourse-choujiang
# about: 定时自动开奖的抽奖（choujiang）插件，支持自定义规则与自动开奖
# version: 0.1
# authors: your_name
# url: https://github.com/your_name/discourse-choujiang

enabled_site_setting :choujiang_enabled

after_initialize do
  require_relative 'lib/choujiang'
end