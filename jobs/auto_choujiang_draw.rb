# frozen_string_literal: true

module ::Jobs
  class AutoChoujiangDraw < ::Jobs::Scheduled
    every 5.minutes

    def execute(args)
      return unless SiteSetting.choujiang_enabled?

      ::Choujiang.choujiang_topics.each do |topic|
        first_post = topic.first_post
        info = ::Choujiang.parse_choujiang_info(first_post)
        next unless info[:draw_time] && Time.now >= info[:draw_time]
        next if topic.tags.include?("choujiang_drawn")
        winners = ::Choujiang.select_winners(topic, info)
        ::Choujiang.announce_winners(topic, winners, info)
        topic.tags << "choujiang_drawn"
        topic.save
      end
    end
  end
end