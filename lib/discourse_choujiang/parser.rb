# frozen_string_literal: true

module DiscourseChoujiang
  class Parser
    # 从主题首贴原文解析配置，返回 Hash
    # 支持字段（不区分全角/半角冒号两种常见写法）：
    # - 抽奖名称
    # - 活动奖品
    # - 获奖人数
    # - 开奖时间（如 2025-07-10 20:00）
    # - 最低积分（如 50；为空或 0 表示不限制）
    #
    # 若未找到 [抽奖] 区块，返回 {}
    def self.extract_config_from_topic(topic)
      fp = topic.first_post
      return {} unless fp&.raw.present?

      extract_config_from_raw(fp.raw)
    end

    def self.extract_config_from_raw(raw)
      block = extract_block(raw, "[抽奖]", "[/抽奖]")
      return {} if block.blank?

      lines = block.lines.map(&:strip).reject(&:blank?)
      cfg = {}

      lines.each do |line|
        key, val = split_kv(line)
        next if key.blank?

        case key
        when "抽奖名称"
          cfg[:title] = val
        when "活动奖品"
          cfg[:prize] = val
        when "获奖人数"
          cfg[:winner_count] = val.to_i
        when "开奖时间"
          # 允许 "YYYY-MM-DD HH:MM" 本地时间，交给 Time.zone 解析
          begin
            cfg[:draw_at] = Time.zone.parse(val) if val.present?
          rescue
            # ignore
          end
        when "最低积分"
          cfg[:minimum_points] = val.to_i
        end
      end

      # 默认值处理
      cfg[:winner_count] = 1 if cfg[:winner_count].to_i <= 0
      cfg[:minimum_points] = 0 if cfg[:minimum_points].to_i < 0

      cfg
    end

    def self.extract_block(raw, start_tag, end_tag)
      s = raw.index(start_tag)
      e = raw.index(end_tag)
      return nil if s.nil? || e.nil? || e <= s

      raw[(s + start_tag.length)...e].to_s
    end

    def self.split_kv(line)
      # 支持 "键：值" 或 "键: 值"
      if line.include?("：")
        parts = line.split("：", 2)
      else
        parts = line.split(":", 2)
      end
      key = parts[0].to_s.strip
      val = parts[1].to_s.strip
      [key, val]
    end
  end
end
