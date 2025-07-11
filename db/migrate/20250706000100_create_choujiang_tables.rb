# frozen_string_literal: true

class CreateChoujiangTables < ActiveRecord::Migration[7.0]
  def change
    # 主表：记录每次抽奖的关键信息
    create_table :choujiang_records do |t|
      t.integer :topic_id, null: false, index: true
      t.integer :post_id, null: false, index: true         # 发起抽奖的帖子ID
      t.integer :user_id, null: false, index: true         # 发起人ID
      t.string  :choujiang_title, null: false              # 抽奖名称
      t.string  :choujiang_prize, null: false              # 活动奖品
      t.integer :winner_count, null: false, default: 1     # 中奖人数
      t.datetime :draw_time, null: false                   # 开奖时间
      t.text    :description                               # 简单说明
      t.boolean :drawn, default: false                     # 是否已开奖
      t.datetime :drawn_at                                 # 实际开奖时间
      t.timestamps
    end

    # 参与表：记录每次抽奖的每个参与用户
    create_table :choujiang_participants do |t|
      t.integer :choujiang_record_id, null: false, index: true
      t.integer :user_id, null: false, index: true
      t.integer :post_id, null: false, index: true         # 参与回复的帖子ID
      t.integer :winner, default: nil                      # 中奖排名（1,2,3...，未中奖为NULL）
      t.timestamps
    end

    add_index :choujiang_participants, [:choujiang_record_id, :user_id], unique: true, name: 'idx_choujiang_participants_unique'
  end
end
