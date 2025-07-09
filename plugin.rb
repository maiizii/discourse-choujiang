# name: discourse-choujiang
# about: 定时自动开奖的抽奖（choujiang）插件，支持自定义规则与自动开奖
# version: 0.2
# authors: macgow
# url: https://github.com/macgowge/discourse-choujiang

enabled_site_setting :choujiang_enabled

after_initialize do
  require_relative 'lib/choujiang'
  require_relative 'jobs/auto_choujiang_draw.rb'

  Rails.logger.warn("choujiang after_initialize!")

  module ::ChoujiangPostCreatorPatch
    def validate
      Rails.logger.warn("choujiang postcreator validate called! opts: #{(@opts || {}).inspect}")
      super
      if @opts[:topic_id].blank? && @opts[:raw].present? && @opts[:tags].present?
        Rails.logger.warn("choujiang postcreator validate: checking tags: #{@opts[:tags].inspect}")
        tags = Array(@opts[:tags]).map(&:to_s)
        if tags.include?("抽奖活动")
          Rails.logger.warn("choujiang postcreator validate: in choujiang tag branch!")
          @errors.add(:base, "缺少抽奖名称") unless @opts[:raw].match?(/抽奖名称[:：]\s*.+/)
          @errors.add(:base, "缺少奖品") unless @opts[:raw].match?(/奖品[:：]\s*.+/)
          @errors.add(:base, "缺少获奖人数") unless @opts[:raw].match?(/获奖人数[:：]\s*\d+/)
          @errors.add(:base, "缺少开奖时间") unless @opts[:raw].match?(/开奖时间[:：]\s*[\d\- :]+/)
        end
      end
    end
  end

  ::PostCreator.prepend(::ChoujiangPostCreatorPatch)
end
