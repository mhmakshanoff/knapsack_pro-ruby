describe KnapsackPro::Adapters::RSpecAdapter do
  it 'backwards compatibility with knapsack gem old rspec adapter name' do
    expect(KnapsackPro::Adapters::RspecAdapter.new).to be_kind_of(described_class)
  end

  it do
    expect(described_class::TEST_DIR_PATTERN).to eq 'spec/**{,/*/**}/*_spec.rb'
  end

  context do
    before { expect(::RSpec).to receive(:configure) }
    it_behaves_like 'adapter'
  end

  describe '.test_path' do
    let(:current_example_metadata) do
      {
        file_path: '1_shared_example.rb',
        parent_example_group: {
          file_path: '2_shared_example.rb',
          parent_example_group: {
            file_path: 'a_spec.rb'
          }
        }
      }
    end

    subject { described_class.test_path(current_example_metadata) }

    it { should eql 'a_spec.rb' }

    context 'with turnip features' do
      describe 'when the turnip version is less than 2' do
        let(:current_example_metadata) do
          {
            file_path: "./spec/features/logging_in.feature",
            turnip: true,
            parent_example_group: {
              file_path: "gems/turnip-1.2.4/lib/turnip/rspec.rb"
            }
          }
        end

        before { stub_const("Turnip::VERSION", '1.2.4') }

        it { should eql './spec/features/logging_in.feature' }
      end

      describe 'when turnip is version 2 or greater' do
        let(:current_example_metadata) do
          {
            file_path: "gems/turnip-2.0.0/lib/turnip/rspec.rb",
            turnip: true,
            parent_example_group: {
              file_path: "./spec/features/logging_in.feature",
            }
          }
        end

        before { stub_const("Turnip::VERSION",  '2.0.0') }

        it { should eql './spec/features/logging_in.feature' }
      end
    end
  end

  describe 'bind methods' do
    let(:config) { double }

    describe '#bind_time_tracker' do
      let(:tracker) { instance_double(KnapsackPro::Tracker) }
      let(:logger) { instance_double(Logger) }
      let(:test_path) { 'spec/a_spec.rb' }
      let(:global_time) { 'Global time: 01m 05s' }
      let(:example_group) { double }
      let(:current_example) do
        OpenStruct.new(metadata: {
          example_group: example_group
        })
      end

      it do
        expect(config).to receive(:before).with(:each).and_yield
        expect(config).to receive(:after).with(:each).and_yield
        expect(config).to receive(:after).with(:suite).and_yield
        expect(::RSpec).to receive(:configure).and_yield(config)

        expect(::RSpec).to receive(:current_example).twice.and_return(current_example)
        expect(described_class).to receive(:test_path).with(example_group).and_return(test_path)

        allow(KnapsackPro).to receive(:tracker).and_return(tracker)
        expect(tracker).to receive(:current_test_path=).with(test_path)
        expect(tracker).to receive(:start_timer)

        expect(tracker).to receive(:stop_timer)

        expect(KnapsackPro::Presenter).to receive(:global_time).and_return(global_time)
        expect(KnapsackPro).to receive(:logger).and_return(logger)
        expect(logger).to receive(:debug).with(global_time)

        subject.bind_time_tracker
      end
    end

    describe '#bind_save_report' do
      it do
        expect(config).to receive(:after).with(:suite).and_yield
        expect(::RSpec).to receive(:configure).and_yield(config)

        expect(KnapsackPro::Report).to receive(:save)

        subject.bind_save_report
      end
    end

    describe '#bind_save_queue_report' do
      it do
        expect(config).to receive(:after).with(:suite).and_yield
        expect(::RSpec).to receive(:configure).and_yield(config)

        expect(KnapsackPro::Report).to receive(:save_subset_queue_to_file)

        subject.bind_save_queue_report
      end
    end

    describe '#bind_tracker_reset' do
      it do
        expect(config).to receive(:before).with(:suite).and_yield
        expect(::RSpec).to receive(:configure).and_yield(config)

        tracker = instance_double(KnapsackPro::Tracker)
        expect(KnapsackPro).to receive(:tracker).and_return(tracker)
        expect(tracker).to receive(:reset!)

        subject.bind_tracker_reset
      end
    end

    describe '#bind_before_queue_hook' do
      it do
        expect(config).to receive(:before).with(:suite).and_yield
        expect(::RSpec).to receive(:configure).and_yield(config)

        expect(KnapsackPro::Hooks::Queue).to receive(:call_before_queue)

        subject.bind_before_queue_hook
      end
    end
  end
end
