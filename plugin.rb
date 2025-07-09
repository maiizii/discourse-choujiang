# name: discourse-choujiang
# about: 定时自动开奖的抽奖（choujiang）插件，支持自定义规则与自动开奖
# version: 0.2
# authors: macgow
# url: https://github.com/macgowge/discourse-choujiang

enabled_site_setting :choujiang_enabled

after_initialize do
  require_relative 'lib/choujiang'
  require_relative 'jobs/auto_choujiang_draw.rb'

  class ::ChoujiangPostValidator
    def self.valid?(post)
      return true unless post.post_number == 1
      tags = (post.respond_to?(:tags) && post.tags.presence) || (post.topic&.tags&.map(&:name) || [])
      return true unless tags.include?("抽奖活动")
      errors = []
      errors << "缺少抽奖名称" unless post.raw.match?(/抽奖名称[:：]\s*.+/)
      errors << "缺少奖品" unless post.raw.match?(/奖品[:：]\s*.+/)
      errors << "缺少获奖人数" unless post.raw.match?(/获奖人数[:：]\s*\d+/)
      errors << "缺少开奖时间" unless post.raw.match?(/开奖时间[:：]\s*[\d\- :]+/)
      errors.each { |e| post.errors.add(:base, e) }
      errors.empty?
    end
  end

  # 注册到Discourse的PostValidator链
  validate_post_custom = lambda do |post|
    ::ChoujiangPostValidator.valid?(post)
  end
  DiscourseEvent.on(:validate_post, &validate_post_custom)
end
