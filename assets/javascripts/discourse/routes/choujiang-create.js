import DiscourseRoute from "discourse/routes/discourse";

export default class ChoujiangCreateRoute extends DiscourseRoute {
  beforeModel() {
    if (!this.currentUser) {
      this.replaceWith("login");
    }
  }

  model() {
    return {
      title: "",
      prize: "",
      winners: 1,
      draw_time: "",
      minimum_points: "",
      description: "",
      extra_body: "",
      category_id: null
    };
  }
}
