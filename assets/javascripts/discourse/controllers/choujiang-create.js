import Controller from "@ember/controller";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default class ChoujiangCreateController extends Controller {
  submitting = false;
  created = false;
  topicUrl = null;

  get canSubmit() {
    const m = this.model;
    return m.title.trim() && m.prize.trim() && m.winners > 0 && m.draw_time.trim();
  }

  @action
  submit() {
    if (!this.canSubmit || this.submitting) return;
    this.submitting = true;

    ajax("/choujiang/create", {
      type: "POST",
      data: {
        title: this.model.title,
        prize: this.model.prize,
        winners: this.model.winners,
        draw_time: this.model.draw_time,
        minimum_points: this.model.minimum_points,
        description: this.model.description,
        extra_body: this.model.extra_body,
        category_id: this.model.category_id
      }
    })
      .then((r) => {
        this.created = true;
        this.topicUrl = r.topic_url;
      })
      .catch(popupAjaxError)
      .finally(() => (this.submitting = false));
  }

  @action
  goTopic() {
    if (this.topicUrl) window.location = this.topicUrl;
  }
}
