import DiscourseRoute from "discourse/routes/discourse";

export default class LotteryCreateRoute extends DiscourseRoute {
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
