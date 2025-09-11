# frozen_string_literal: true

require_dependency "application_controller"

module DiscourseChoujiang
  class PointsController < ::ApplicationController
    requires_plugin ::Plugin::Metadata.current.name

    before_action :ensure_logged_in, only: [:show]

    def show
      topic_id = params.require(:topic_id)
      topic = Topic.find_by(id: topic_id)
      raise Discourse::NotFound unless topic
      guardian.ensure_can_see!(topic)

      cfg = DiscourseChoujiang::Parser.extract_config_from_topic(topic)
      min = cfg[:minimum_points].to_i
      user_pts = DiscourseChoujiang::GamificationPoints.user_points(current_user.id)

      render_json_dump(
        topic_id: topic.id,
        minimum_points: min,
        user_points: user_pts,
        eligible: (min <= 0 || user_pts >= min)
      )
    end
  end
end
