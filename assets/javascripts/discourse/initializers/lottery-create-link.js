import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  name: "lottery-create-link",
  initialize() {
    withPluginApi("1.8.0", (api) => {
      const currentUser = api.getCurrentUser();
      if (!currentUser) {
        return;
      }
      api.addHeaderDropdownEntry({
        name: "lottery-create",
        displayName: "发布抽奖",
        href: "/lottery/create",
        icon: "gift",
      });
    });
  },
};
