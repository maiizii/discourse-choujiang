import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  name: "lottery-create-link",
  initialize() {
    withPluginApi("1.8.0", (api) => {
      api.onPageChange(() => {}); // 保证加载
      // 显示给已登录用户（未登录访问直接输入 URL 也能看到提示）
      if (!api.getCurrentUser()) return;
      api.addHeaderDropdownEntry({
        name: "lottery-create",
        displayName: "发布抽奖",
        href: "/lottery/create",
        icon: "gift"
      });
    });
  }
};
