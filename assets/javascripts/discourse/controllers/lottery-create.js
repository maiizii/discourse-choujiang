import Controller from "@ember/controller";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default Controller.extend({
  submitting: false,
  created: false,
  topicUrl: null,

  canSubmit: function () {
    if (!this.get("currentUser")) return false;
    const m = this.model;
    if (!m) return false;
    return (
      m.title.trim() &&
      m.prize.trim() &&
      m.winners > 0 &&
      m.draw_time.trim()
    );
  }.property(
    "currentUser",
    "model.title",
    "model.prize",
    "model.winners",
    "model.draw_time"
  ),

  actions: {
    submit() {
      if (!this.get("canSubmit") || this.submitting) return;
      this.set("submitting", true);

      const m = this.model;
      ajax("/lottery/create", {
        type: "POST",
        data: {
          title: m.title,
            prize: m.prize,
            winners: m.winners,
            draw_time: m.draw_time,
            minimum_points: m.minimum_points,
            description: m.description,
            extra_body: m.extra_body,
            category_id: m.category_id,
        },
      })
        .then((r) => {
          this.set("created", true);
          this.set("topicUrl", r.topic_url);
        })
        .catch(popupAjaxError)
        .finally(() => this.set("submitting", false));
    },

    goTopic() {
      const url = this.topicUrl;
      if (url) {
        window.location = url;
      }
    },
  },
});
