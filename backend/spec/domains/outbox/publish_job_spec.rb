require "rails_helper"

RSpec.describe Outbox::Jobs::PublishJob do
  let(:producer) { instance_double(WaterDrop::Producer, produce_many_sync: nil) }

  before { allow(Karafka).to receive(:producer).and_return(producer) }

  it "publishes unpublished events in order and marks them" do
    first, second = create_list(:outbox_event, 2)
    create(:outbox_event, published_at: 1.hour.ago)

    described_class.perform_now

    expect(producer).to have_received(:produce_many_sync).with([ first.message, second.message ]).once
    expect(Outbox::Event.unpublished).to be_empty
  end

  it "does nothing when the outbox is empty" do
    described_class.perform_now

    expect(producer).not_to have_received(:produce_many_sync)
  end

  it "leaves events unpublished when the broker rejects them" do
    create(:outbox_event)
    allow(producer).to receive(:produce_many_sync).and_raise(WaterDrop::Errors::ProduceManyError.new(nil, nil))

    expect { described_class.perform_now }.to raise_error(WaterDrop::Errors::ProduceManyError)
    expect(Outbox::Event.unpublished.count).to eq(1)
  end
end
