import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  name: "add-choujiang-template-button",

  initialize() {
    withPluginApi("0.8.7", api => {
      api.addComposerButton("choujiang-template", {
        title: "插入抽奖模板",
        icon: "gift",
        click() {
          api.container.lookup("controller:composer").send("openChoujiangTemplateModal");
        }
      });
    });
  }
}