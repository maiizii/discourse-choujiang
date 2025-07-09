# name: discourse-choujiang
# about: 定时自动开奖的抽奖（choujiang）插件，支持自定义规则与自动开奖
# version: 0.2
# authors: macgow
# url: https://github.com/macgowge/discourse-choujiang

enabled_site_setting :choujiang_enabled

after_initialize do
  require_relative 'lib/choujiang'
  require_relative 'jobs/auto_choujiang_draw.rb'

  # ------- 关键：自定义 PostValidator -------
  class ::ChoujiangPostValidator
    def initialize(post)
      @post = post
    end

    def validate(errors)
      # 只校验主题首贴
      return unless @post.post_number == 1

      # 获取标签名称
      tags = if @post.respond_to?(:tags) && @post.tags.present?
        @post.tags
      elsif @post.topic && @post.topic.respond_to?(:tags)
        @post.topic.tags.map(&:name)
      else
        []
      end

      # 只对含“抽奖活动”标签的主题校验（你可以根据实际标签名修改）
      return unless tags.include?("抽奖活动")

      errors.add(:base, "缺少抽奖名称") unless @post.raw.match?(/抽奖名称[:：]\s*.+/)
      errors.add(:base, "缺少奖品") unless @post.raw.match?(/奖品[:：]\s*.+/)
      errors.add(:base, "缺少获奖人数") unless @post.raw.match?(/获奖人数[:：]\s*\d+/)
      errors.add(:base, "缺少开奖时间") unless @post.raw.match?(/开奖时间[:：]\s*[\d\- :]+/)
    end
  end

  # 注册到 Discourse 的 PostValidator 链
  add_to_class(:post_validator, :validate_choujiang_post) do
    ::ChoujiangPostValidator.new(self.post).validate(self.errors)
  end
end
