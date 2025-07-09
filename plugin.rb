# name: discourse-choujiang
# about: 定时自动开奖的抽奖（choujiang）插件，支持自定义规则与自动开奖
# version: 0.2
# authors: macgow
# url: https://github.com/macgowge/discourse-choujiang

enabled_site_setting :choujiang_enabled

after_initialize do
  require_relative 'lib/choujiang'
  require_relative 'jobs/auto_choujiang_draw.rb'

  module ::ChoujiangPostValidatorPatch
    def validate_choujiang_post
      Rails.logger.warn("choujiang validator called!")
      if self.post.post_number == 1
        tags = if self.post.respond_to?(:tags) && self.post.tags.present?
          self.post.tags
        elsif self.post.topic && self.post.topic.respond_to?(:tags)
          self.post.topic.tags.map(&:name)
        else
          []
        end

        if tags.include?("抽奖活动")
          self.errors.add(:base, "缺少抽奖名称") unless self.post.raw.match?(/抽奖名称[:：]\s*.+/)
          self.errors.add(:base, "缺少奖品") unless self.post.raw.match?(/奖品[:：]\s*.+/)
          self.errors.add(:base, "缺少获奖人数") unless self.post.raw.match?(/获奖人数[:：]\s*\d+/)
          self.errors.add(:base, "缺少开奖时间") unless self.post.raw.match?(/开奖时间[:：]\s*[\d\- :]+/)
        end
      end
      super if defined?(super)
    end
  end

  # 通过 prepend，将自定义校验方法挂载到 PostValidator
  PostValidator.prepend(::ChoujiangPostValidatorPatch)
end
