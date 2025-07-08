# name: discourse-choujiang
# about: 定时自动开奖的抽奖（choujiang）插件，支持自定义规则与自动开奖
# version: 0.2
# authors: macgow
# url: https://github.com/macgowge/discourse-choujiang

enabled_site_setting :choujiang_enabled

after_initialize do
  require_relative 'lib/choujiang'
  require_relative 'lib/choujiang_validator'
  require_relative 'jobs/auto_choujiang_draw.rb'

  # 发帖时自动参数校验
  on(:post_created) do |post, opts, user|
    # 只处理主题帖且标签为抽奖活动
    next unless post.is_first_post?
    next unless post.topic.tags.pluck(:name).include?(SiteSetting.choujiang_tag)

    # 校验并解析参数
    ::Choujiang.parse_choujiang_info(post)
    # 校验不通过会自动 raise 错误，前端弹窗提示
    # 校验通过可在此处继续抽奖记录逻辑
  end
end
