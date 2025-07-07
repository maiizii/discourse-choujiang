import Component from "@ember/component";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";

export default class ChoujiangTemplateModal extends Component {
  @service composer;
  title = "";
  prize = "";
  numWinners = 1;
  drawTime = null;
  extraInfo = "";

  @action
  setDrawTime(val) {
    this.set("drawTime", val);
  }

  @action
  insertTemplate() {
    const template = `抽奖名称：${this.title}
奖品：${this.prize}
获奖人数：${this.numWinners}
开奖时间：${this.drawTime ? this.drawTime.replace("T", " ").substring(0, 16) : ""}
其他说明：${this.extraInfo}`;

    this.composer.addText(template);
    this.closeModal();
  }
}