class CreateOutboxEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :outbox_events, comment: "Transactional outbox: domain events written with the data they describe, relayed to Kafka by Outbox::Jobs::PublishJob" do |t|
      t.string :topic, null: false, comment: "Kafka topic"
      t.string :key, null: false, comment: "Kafka partition key, e.g. user:<id> for per-user ordering"
      t.string :event_type, null: false, comment: "e.g. application.recorded"
      t.jsonb :payload, null: false, default: {}
      t.datetime :published_at, comment: "NULL until the relay delivered it to Kafka"
      t.datetime :created_at, null: false
    end
    add_index :outbox_events, :id, where: "published_at IS NULL", name: "index_outbox_events_unpublished"
  end
end
