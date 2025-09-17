import DiscourseRoute from "discourse/routes/discourse";

export default DiscourseRoute.extend({
  model() {
    return {
      title: "",
      prize: "",
      winners: 1,
      draw_time: "",
      minimum_points: "",
      description: "",
      extra_body: "",
      category_id: null,
    };
  },
});
