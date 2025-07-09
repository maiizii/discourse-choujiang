# name: discourse-choujiang
# about: 定时自动开奖的抽奖（choujiang）插件，支持自定义规则与自动开奖
# version: 0.2
# authors: macgow
# url: https://github.com/macgowge/discourse-choujiang

enabled_site_setting :choujiang_enabled

after_initialize do
  require_relative 'lib/choujiang'
  require_relative 'jobs/auto_choujiang_draw.rb'

  module ::ChoujiangPostCreatorPatch
    def validate
      super # 先执行原有校验

      # 日志确认是否生效
      Rails.logger.warn("choujiang postcreator validate called!")

      if @opts[:raw].present? && @opts[:tags].present?
        # 只校验主题首贴
        if @opts[:post_number].to_i == 1
          tags = Array(@opts[:tags]).map(&:to_s)
          if tags.include?("抽奖活动")
            errors = []
            errors << "缺少抽奖名称" unless @opts[:raw].match?(/抽奖名称[:：]\s*.+/)
            errors << "缺少奖品" unless @opts[:raw].match?(/奖品[:：]\s*.+/)
            errors << "缺少获奖人数" unless @opts[:raw].match?(/获奖人数[:：]\s*\d+/)
            errors << "缺少开奖时间" unless @opts[:raw].match?(/开奖时间[:：]\s*[\d\- :]+/)
            errors.each { |msg| @errors.add(:base, msg) }
          end
        end
      end
    end
  end

  ::PostCreator.prepend(::ChoujiangPostCreatorPatch)
end
