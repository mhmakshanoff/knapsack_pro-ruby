describe KnapsackPro::QueueAllocator do
  let(:test_files) { double }
  let(:ci_node_total) { double }
  let(:ci_node_index) { double }
  let(:ci_node_build_id) { double }
  let(:repository_adapter) { instance_double(KnapsackPro::RepositoryAdapters::EnvAdapter, commit_hash: double, branch: double) }

  let(:queue_allocator) do
    described_class.new(
      test_files: test_files,
      ci_node_total: ci_node_total,
      ci_node_index: ci_node_index,
      ci_node_build_id: ci_node_build_id,
      repository_adapter: repository_adapter
    )
  end

  describe '#test_file_paths' do
    let(:can_initialize_queue) { double }
    let(:executed_test_files) { [] }
    let(:response) { double }

    subject { queue_allocator.test_file_paths(can_initialize_queue, executed_test_files) }

    before do
      encrypted_test_files = double
      expect(KnapsackPro::Crypto::Encryptor).to receive(:call).with(test_files).and_return(encrypted_test_files)

      encrypted_branch = double
      expect(KnapsackPro::Crypto::BranchEncryptor).to receive(:call).with(repository_adapter.branch).and_return(encrypted_branch)

      action = double
      expect(KnapsackPro::Client::API::V1::Queues).to receive(:queue).with(
        can_initialize_queue: can_initialize_queue,
        commit_hash: repository_adapter.commit_hash,
        branch: encrypted_branch,
        node_total: ci_node_total,
        node_index: ci_node_index,
        node_build_id: ci_node_build_id,
        test_files: encrypted_test_files,
      ).and_return(action)

      connection = instance_double(KnapsackPro::Client::Connection,
                                   call: response,
                                   success?: success?,
                                   errors?: errors?)
      expect(KnapsackPro::Client::Connection).to receive(:new).with(action).and_return(connection)
    end

    context 'when successful request to API' do
      let(:success?) { true }

      context 'when response has errors' do
        let(:errors?) { true }

        it do
          expect { subject }.to raise_error(ArgumentError)
        end
      end

      context 'when response has no errors' do
        let(:errors?) { false }
        let(:response) do
          {
            'test_files' => [
              { 'path' => 'a_spec.rb' },
              { 'path' => 'b_spec.rb' },
            ]
          }
        end

        before do
          expect(KnapsackPro::Crypto::Decryptor).to receive(:call).with(test_files, response['test_files']).and_call_original
        end

        it { should eq ['a_spec.rb', 'b_spec.rb'] }
      end
    end

    context 'when not successful request to API' do
      let(:success?) { false }
      let(:errors?) { false }

      context 'when fallback mode is disabled' do
        before do
          expect(KnapsackPro::Config::Env).to receive(:fallback_mode_enabled?).and_return(false)
        end

        it do
          expect { subject }.to raise_error(RuntimeError, 'Fallback Mode was disabled with KNAPSACK_PRO_FALLBACK_MODE_ENABLED=false. Please restart this CI node to retry tests. Most likely Fallback Mode was disabled due to https://github.com/KnapsackPro/knapsack_pro-ruby#required-ci-configuration-if-you-use-retry-single-failed-ci-node-feature-on-your-ci-server-when-knapsack_pro_fixed_queue_splittrue-in-queue-mode-or-knapsack_pro_fixed_test_suite_splittrue-in-regular-mode')
        end
      end

      context 'when CI node retry count > 0' do
        before do
          expect(KnapsackPro::Config::Env).to receive(:ci_node_retry_count).and_return(1)
        end

        context 'when fixed_queue_split=true' do
          before do
            expect(KnapsackPro::Config::Env).to receive(:fixed_queue_split).and_return(true)
          end

          it do
            expect { subject }.to raise_error(RuntimeError, 'knapsack_pro gem could not connect to Knapsack Pro API and the Fallback Mode cannot be used this time. Running tests in Fallback Mode are not allowed for retried parallel CI node to avoid running the wrong set of tests. Please manually retry this parallel job on your CI server then knapsack_pro gem will try to connect to Knapsack Pro API again and will run a correct set of tests for this CI node. Learn more https://github.com/KnapsackPro/knapsack_pro-ruby#required-ci-configuration-if-you-use-retry-single-failed-ci-node-feature-on-your-ci-server-when-knapsack_pro_fixed_queue_splittrue-in-queue-mode-or-knapsack_pro_fixed_test_suite_splittrue-in-regular-mode')
          end
        end

        context 'when fixed_queue_split=false' do
          before do
            expect(KnapsackPro::Config::Env).to receive(:fixed_queue_split).and_return(false)
          end

          it do
            expect { subject }.to raise_error(RuntimeError, 'knapsack_pro gem could not connect to Knapsack Pro API and the Fallback Mode cannot be used this time. Running tests in Fallback Mode are not allowed for retried parallel CI node to avoid running the wrong set of tests. Please manually retry this parallel job on your CI server then knapsack_pro gem will try to connect to Knapsack Pro API again and will run a correct set of tests for this CI node. Learn more https://github.com/KnapsackPro/knapsack_pro-ruby#required-ci-configuration-if-you-use-retry-single-failed-ci-node-feature-on-your-ci-server-when-knapsack_pro_fixed_queue_splittrue-in-queue-mode-or-knapsack_pro_fixed_test_suite_splittrue-in-regular-mode Please ensure you have set KNAPSACK_PRO_FIXED_QUEUE_SPLIT=true to allow Knapsack Pro API remember the recorded CI node tests so when you retry failed tests on the CI node then the same set of tests will be executed. See more https://github.com/KnapsackPro/knapsack_pro-ruby#knapsack_pro_fixed_queue_split-remember-queue-split-on-retry-ci-node')
          end
        end
      end

      context 'when fallback mode started' do
        before do
          test_flat_distributor = instance_double(KnapsackPro::TestFlatDistributor)
          expect(KnapsackPro::TestFlatDistributor).to receive(:new).with(test_files, ci_node_total).and_return(test_flat_distributor)
          expect(test_flat_distributor).to receive(:test_files_for_node).with(ci_node_index).and_return([
            { 'path' => 'c_spec.rb' },
            { 'path' => 'd_spec.rb' },
          ])
        end

        context 'when no test files were executed yet' do
          let(:executed_test_files) { [] }

          it 'enables fallback mode and returns fallback test files' do
            expect(subject).to eq ['c_spec.rb', 'd_spec.rb']
          end
        end

        context 'when test files were already executed' do
          let(:executed_test_files) { ['c_spec.rb', 'additional_executed_spec.rb'] }

          it 'enables fallback mode and returns fallback test files' do
            expect(subject).to eq ['d_spec.rb']
          end
        end
      end
    end
  end
end
