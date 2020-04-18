module KnapsackPro
  module Adapters
    class BaseAdapter
      # Just example, please overwrite constant in subclass
      TEST_DIR_PATTERN = 'test/**{,/*/**}/*_test.rb'

      def self.slow_test_file?(path)
        @slow_test_file_paths ||=
          if KnapsackPro::Config::Env.slow_test_file_pattern
            KnapsackPro::TestFileFinder.call(
              KnapsackPro::Config::Env.slow_test_file_pattern,
              test_file_list_enabled: false).map { |t| t.fetch('path') }
          else
            # TODO get slow test file paths from JSON file based on data from API
            []
          end
        clean_path = KnapsackPro::TestFileCleaner.clean(path)
        @slow_test_file_paths.include?(clean_path)
      end

      def self.bind
        adapter = new
        adapter.bind
        adapter
      end

      def bind
        if KnapsackPro::Config::Env.recording_enabled?
          KnapsackPro.logger.debug('Test suite time execution recording enabled.')
          bind_time_tracker
          bind_save_report
        end

        if KnapsackPro::Config::Env.queue_recording_enabled?
          KnapsackPro.logger.debug('Test suite time execution queue recording enabled.')
          bind_queue_mode
        end
      end

      def bind_time_tracker
        raise NotImplementedError
      end

      def bind_save_report
        raise NotImplementedError
      end

      def bind_before_queue_hook
        raise NotImplementedError
      end

      def bind_queue_mode
        bind_before_queue_hook
        bind_time_tracker
      end
    end
  end
end
