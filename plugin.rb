# name: discourse-choujiang
# about: 定时自动开奖的抽奖（choujiang）插件，支持自定义规则与自动开奖
# version: 0.3
# authors: macgow
# url: https://github.com/macgowge/discourse-choujiang

enabled_site_setting :choujiang_enabled

after_initialize do
  require_relative 'lib/choujiang' if File.exist?(File.expand_path('lib/choujiang.rb', __dir__))
  require_relative 'jobs/auto_choujiang_draw.rb' if File.exist?(File.expand_path('jobs/auto_choujiang_draw.rb', __dir__))

  Rails.logger.warn("choujiang after_initialize!")

  module ::ChoujiangPostValidation
    def validate(*)
      super
      begin
        if self.post_number == 1
          tags = self.topic&.tags&.map(&:name) || []
          is_choujiang = tags.include?("抽奖活动")
          Rails.logger.warn("choujiang post validate hook: is_first_post=#{self.post_number == 1}, tags=#{tags.inspect}, is_choujiang=#{is_choujiang}")
          if is_choujiang
            Rails.logger.warn("choujiang post validate: raw=#{self.raw.inspect}")
            errors.add(:base, "缺少抽奖名称") unless self.raw =~ /抽奖名称[:：]\s*.+/
            errors.add(:base, "缺少奖品") unless self.raw =~ /奖品[:：]\s*.+/
            errors.add(:base, "缺少获奖人数") unless self.raw =~ /获奖人数[:：]\s*\d+/
            errors.add(:base, "缺少开奖时间") unless self.raw =~ /开奖时间[:：]\s*[\d\- :]+/
          end
        end
      rescue => e
        Rails.logger.warn("choujiang validate error: #{e.message}")
      end
    end
  end

  unless Post.ancestors.include?(::ChoujiangPostValidation)
    Post.prepend(::ChoujiangPostValidation)
    Rails.logger.warn("choujiang post validation prepended!")
  end
end
