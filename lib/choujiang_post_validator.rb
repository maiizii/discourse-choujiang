class ChoujiangPostValidator < ActiveModel::Validator
  def validate(record)
    # 只校验首帖 且 带 choujiang_tag
    return unless record.post_number == 1
    topic_tags = record.topic&.tags&.map(&:name) || []
    tag = SiteSetting.choujiang_tag
    return unless topic_tags.include?(tag)

    errors, _info = ::ChoujiangValidator.parse_and_validate(record.raw)
    errors.each { |e| record.errors.add(:base, e) } if errors.any?
  end
end
