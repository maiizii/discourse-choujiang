# frozen_string_literal: true
module DiscourseChoujiang
  class CreateController < ::ApplicationController
    requires_plugin ::DiscourseChoujiang

    before_action :ensure_logged_in
    before_action :ensure_enabled

    def create
      title        = params[:title].to_s.strip
      prize        = params[:prize].to_s.strip
      winners      = params[:winners].to_i
      draw_time    = params[:draw_time].to_s.strip
      min_points   = params[:minimum_points].to_s.strip
      description  = params[:description].to_s
      extra_body   = params[:extra_body].to_s
      category_id  = params[:category_id]
      tag_name     = SiteSetting.choujiang_tag

      if title.blank? || prize.blank? || winners <= 0 || draw_time.blank?
        return render_json_error(I18n.t("choujiang.create.missing_fields"))
      end

      # 非严格校验，仅确认格式基本合理（YYYY-MM-DD HH:MM）
      unless draw_time =~ /\A\d{4}-\d{2}-\d{2} \d{2}:\d{2}\z/
        return render_json_error(I18n.t("choujiang.create.invalid_draw_time_format"))
      end

      # 组装 raw（保持既有解析格式）
      raw_lines = []
      raw_lines << "[抽奖]"
      raw_lines << "抽奖名称：#{title}"
      raw_lines << "活动奖品：#{prize}"
      raw_lines << "获奖人数：#{winners}"
      raw_lines << "开奖时间：#{draw_time}"
      unless min_points.blank?
        raw_lines << "最低积分：#{min_points}"
      end
      unless description.strip.empty?
        raw_lines << "简单说明：#{description.strip.gsub(/\r?\n+/, ' ')}"
      else
        raw_lines << "简单说明："
      end
      raw_lines << "[/抽奖]"
      raw_lines << ""
      raw_lines << extra_body unless extra_body.blank?

      raw = raw_lines.join("\n")

      guardian.ensure_can_create!(Post)

      creator = PostCreator.create!(
        current_user,
        title: title,
        raw: raw,
        category: category_id,
        tags: [tag_name]
      )

      render json: {
        topic_id: creator.topic.id,
        topic_url: creator.topic.url
      }
    rescue => e
      render_json_error(e.message)
    end

    private

    def ensure_enabled
      raise Discourse::InvalidAccess.new unless SiteSetting.choujiang_enabled?
    end
  end
end
