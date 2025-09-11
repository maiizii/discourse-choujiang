# frozen_string_literal: true

module DiscourseChoujiang
  class GamificationPoints
    class << self
      # 返回用户在 discourse-gamification 插件中的积分总和（整数）
      def user_points(user_id)
        return 0 if user_id.blank?

        score = 0
        if ActiveRecord::Base.connection.table_exists?(:gamification_scores)
          result = DB.query_single(
            "SELECT COALESCE(SUM(score), 0) FROM gamification_scores WHERE user_id = ?",
            user_id
          )
          score = result.first.to_i
        else
          Rails.logger.warn("[discourse-choujiang] 'gamification_scores' table not found. Gamification plugin may be disabled or schema differs.")
        end

        score
      rescue => e
        Rails.logger.warn("[discourse-choujiang] Gamification points lookup failed for user_id=#{user_id}: #{e.class} #{e.message}")
        0
      end
    end
  end
end
