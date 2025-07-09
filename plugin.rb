# name: discourse-choujiang
# about: 定时自动开奖的抽奖（choujiang）插件，支持自定义规则与自动开奖
# version: 0.2
# authors: macgow
# url: https://github.com/macgowge/discourse-choujiang

enabled_site_setting :choujiang_enabled

after_initialize do
  require_relative 'lib/choujiang'
  require_relative 'jobs/auto_choujiang_draw.rb'

  # 新建抽奖主题自动进入待审核，主贴不可编辑
  DiscourseEvent.on(:post_created) do |post, opts, user|
    if post.post_number == 1 && post.topic.tags.pluck(:name).include?("抽奖活动")
      post.topic.update!(visible: false) # 需审核
      post.update!(locked_by_id: Discourse.system_user.id, locked_at: Time.now) # 主贴不可编辑
    end
  end
end
