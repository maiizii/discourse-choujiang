module ::ChoujiangValidator
  REQUIRED_FIELDS = {
    title:    /抽奖名称[:：]\s*(.+)/,
    prize:    /奖品[:：]\s*(.+)/,
    winners:  /获奖人数[:：]\s*(\d+)/,
    draw_time:/开奖时间[:：]\s*([0-9\- :]+)/
  }

  def self.parse_and_validate(raw)
    info = {}
    errors = []

    REQUIRED_FIELDS.each do |field, regex|
      val = raw[regex, 1]&.strip
      info[field] = field == :winners ? val&.to_i : val
      errors << "#{field_label(field)}不能为空" unless val.present?
    end

    # 校验获奖人数
    if info[:winners] && info[:winners].to_i <= 0
      errors << "获奖人数必须为正整数"
    end

    # 校验开奖时间
    if info[:draw_time]
      begin
        info[:draw_time] = ActiveSupport::TimeZone['Beijing'].parse(info[:draw_time]).utc
        errors << "开奖时间必须是将来时间" if info[:draw_time] <= Time.now
      rescue
        begin
          info[:draw_time] = Time.parse(info[:draw_time]).utc
          errors << "开奖时间必须是将来时间" if info[:draw_time] <= Time.now
        rescue
          info[:draw_time] = nil
          errors << "开奖时间格式无效（正确格式2025-01-01 20:00）"
        end
      end
    end

    [errors, info]
  end

  def self.field_label(key)
    case key
    when :title then "抽奖名称"
    when :prize then "奖品"
    when :winners then "获奖人数"
    when :draw_time then "开奖时间"
    else key.to_s
    end
  end

  # 供Discourse PostValidator注册自定义校验
  def self.add_post_validator(validator)
    validator.class_eval do
      validate :choujiang_post_format, if: -> { is_choujiang_topic? && is_first_post? }

      def choujiang_post_format
        errors, _info = ::ChoujiangValidator.parse_and_validate(post_raw)
        errors.each { |e| self.errors.add(:base, e) } if errors.any?
      end

      def is_first_post?
        self.post_number == 1
      end

      def is_choujiang_topic?
        topic_tags = self.topic&.tags&.map(&:name) || []
        tag = SiteSetting.choujiang_tag
        topic_tags.include?(tag)
      end
    end
  end
end
