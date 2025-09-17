import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  name: "choujiang-create-link",
  initialize() {
    withPluginApi("1.8.0", (api) => {
      // 仅已登录用户展示
      if (!api.getCurrentUser()) return;
      api.addHeaderDropdownEntry({
        name: "choujiang-create",
        displayName: "发布抽奖",
        href: "/choujiang/create",
        icon: "gift"
      });
    });
  }
};
