# frozen_string_literal: true

module DiscourseChoujiang
  module ParticipantFilter
    # 传入用户 ID 数组与最低积分，返回满足最低积分的用户 ID 数组
    # minimum_points <= 0 或 nil 时直接原样返回
    def self.filter_by_min_points(user_ids, minimum_points)
      return Array(user_ids) if minimum_points.to_i <= 0

      Array(user_ids).uniq.select do |uid|
        DiscourseChoujiang::GamificationPoints.user_points(uid) >= minimum_points.to_i
      end
    end
  end
end
