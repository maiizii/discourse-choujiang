import { apiInitializer } from "discourse/lib/api";
import { ajax } from "discourse/lib/ajax";

export default apiInitializer("0.8.7", (api) => {
  api.onPageChange(async (url, title) => {
    const topic = api.getCurrentTopic?.();
    if (!topic) return;

    try {
      const data = await ajax("/choujiang/points", {
        type: "GET",
        data: { topic_id: topic.id },
      });

      if (data?.minimum_points > 0 && data?.eligible === false) {
        // 在话题流上方添加警告信息
        api.addGlobalNotice(
          I18n.t("choujiang.minimum_points_notice", {
            minimum_points: data.minimum_points,
            user_points: data.user_points,
          }),
          "warning",
          {
            id: `choujiang-minimum-points-${topic.id}`,
            dismissable: true,
          }
        );
      }
    } catch (e) {
      // 静默失败，不影响页面
      // console.warn("choujiang points fetch failed", e);
    }
  });
});
