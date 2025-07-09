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

  # 发帖内容校验，防止不合格的抽奖帖写入数据库
  on(:validate_post) do |post|
    next unless post.post_number == 1
    # 发帖时标签还未归入topic，只能用post.tags，编辑时topic.tags有
    tags = (post.respond_to?(:tags) && post.tags.presence) || (post.topic&.tags&.map(&:name) || [])
    tag = SiteSetting.choujiang_tag
    next unless tags.include?(tag)

    errors, _info = ::ChoujiangValidator.parse_and_validate(post.raw)
    errors.each { |e| post.errors.add(:base, e) } if errors.any?
  end
end
