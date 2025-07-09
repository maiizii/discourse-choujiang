# name: discourse-choujiang
# about: 定时自动开奖的抽奖（choujiang）插件，支持自定义规则与自动开奖
# version: 0.3
# authors: macgow
# url: https://github.com/macgowge/discourse-choujiang

enabled_site_setting :choujiang_enabled

after_initialize do
  require_relative 'lib/choujiang'
  require_relative 'jobs/auto_choujiang_draw.rb'

  Rails.logger.warn("choujiang after_initialize!")

  # 只对主题首帖做内容强校验
  module ::ChoujiangPostValidation
    extend ActiveSupport::Concern

    included do
      validate :choujiang_topic_format, if: :is_choujiang_topic?
    end

    def is_choujiang_topic?
      # 只校验主题首帖
      is_first_post = self.post_number == 1
      tags = self.topic&.tags&.map(&:name) || []
      is_choujiang = tags.include?("抽奖活动")
      Rails.logger.warn("choujiang post validate hook: is_first_post=#{is_first_post}, tags=#{tags.inspect}, is_choujiang=#{is_choujiang}")
      is_first_post && is_choujiang
    end

    def choujiang_topic_format
      Rails.logger.warn("choujiang post validate: raw=#{self.raw.inspect}")
      errors.add(:base, "缺少抽奖名称") unless self.raw =~ /抽奖名称[:：]\s*.+/
      errors.add(:base, "缺少奖品") unless self.raw =~ /奖品[:：]\s*.+/
      errors.add(:base, "缺少获奖人数") unless self.raw =~ /获奖人数[:：]\s*\d+/
      errors.add(:base, "缺少开奖时间") unless self.raw =~ /开奖时间[:：]\s*[\d\- :]+/
    end
  end

  # 只 prepend 一次，防止重复
  unless Post.included_modules.include?(::ChoujiangPostValidation)
    Post.prepend(::ChoujiangPostValidation)
    Rails.logger.warn("choujiang post validation prepended!")
  end
end
