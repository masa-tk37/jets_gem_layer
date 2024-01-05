# frozen_string_literal: true

require 'spec_helper'

RSpec.describe JetsGemLayer do
  it 'has the correct version' do
    expect(described_class::VERSION).to eq '1.0.0'
  end

  describe '.load_tasks' do
    before { allow(described_class::TaskHelper).to receive(:install) }

    it 'delegates to TaskHelper.install' do
      described_class.load_tasks
      expect(described_class::TaskHelper).to have_received(:install).with(no_args)
    end
  end

  describe '.arn' do
    before { allow(described_class::TaskHelper).to receive(:arn) }

    it 'delegates to TaskHelper.arn' do
      described_class.arn
      expect(described_class::TaskHelper).to have_received(:arn).with(no_args)
    end
  end
end
