require 'rspec'
require 'income_report'

RSpec.describe IncomeReport do
  subject(:report) { described_class.new }

  before do
    report.instance_variable_set(:@patient_data, {})
  end

  # ─────────────────────────────────────────────
  # #handle_created
  # ─────────────────────────────────────────────
  describe '#handle_created' do
    context 'when the patient does not exist' do
      it 'adds the patient with zeroed counters' do
        report.handle_created('Nick')
        expect(report.instance_variable_get(:@patient_data)['Nick']).to eq([0, 0])
      end
    end

    context 'when the patient already exists' do
      it 'prints an error and does not overwrite existing data' do
        report.handle_created('Nick')
        report.handle_filled('Nick')

        expect { report.handle_created('Nick') }
          .to output(/Invalid 'created' record. Patient Nick already exists./).to_stdout

        expect(report.instance_variable_get(:@patient_data)['Nick']).to eq([1, 5])
      end
    end
  end

  # ─────────────────────────────────────────────
  # #handle_filled
  # ─────────────────────────────────────────────
  describe '#handle_filled' do
    context 'when the patient exists' do
      before { report.handle_created('Nick') }

      it 'increments the fill count by 1' do
        expect { report.handle_filled('Nick') }
          .to change { report.instance_variable_get(:@patient_data)['Nick'][0] }.from(0).to(1)
      end

      it 'increments the income by $5' do
        expect { report.handle_filled('Nick') }
          .to change { report.instance_variable_get(:@patient_data)['Nick'][1] }.from(0).to(5)
      end

      it 'accumulates correctly across multiple fills' do
        3.times { report.handle_filled('Nick') }
        expect(report.instance_variable_get(:@patient_data)['Nick']).to eq([3, 15])
      end
    end

    context 'when the patient does not exist' do
      it 'prints an error' do
        expect { report.handle_filled('Paul') }
          .to output(/Invalid 'filled' record. No 'created' record for patient Paul./).to_stdout
      end

      it 'does not create a patient entry' do
        report.handle_filled('Paul')
        expect(report.instance_variable_get(:@patient_data)).not_to have_key('Paul')
      end
    end
  end

  # ─────────────────────────────────────────────
  # #handle_returned
  # ─────────────────────────────────────────────
  describe '#handle_returned' do
    context 'when the patient exists and has fills' do
      before do
        report.handle_created('Nick')
        report.handle_filled('Nick')
      end

      it 'decrements the fill count by 1' do
        expect { report.handle_returned('Nick') }
          .to change { report.instance_variable_get(:@patient_data)['Nick'][0] }.from(1).to(0)
      end

      it 'decrements income by $6' do
        expect { report.handle_returned('Nick') }
          .to change { report.instance_variable_get(:@patient_data)['Nick'][1] }.from(5).to(-1)
      end
    end

    context 'when the patient exists but has no fills' do
      before { report.handle_created('Nick') }

      it 'prints an error' do
        expect { report.handle_returned('Nick') }
          .to output(/Invalid 'returned' record. No matching 'filled' record for patient Nick./).to_stdout
      end

      it 'does not modify patient data' do
        report.handle_returned('Nick')
        expect(report.instance_variable_get(:@patient_data)['Nick']).to eq([0, 0])
      end
    end

    context 'when the patient does not exist' do
      it 'prints an error' do
        expect { report.handle_returned('Paul') }
          .to output(/Invalid 'returned' record. No 'created' record for patient Paul./).to_stdout
      end
    end
  end

  # ─────────────────────────────────────────────
  # #process_input_record
  # ─────────────────────────────────────────────
  describe '#process_input_record' do
    it 'routes a created record correctly' do
      expect(report).to receive(:handle_created).with('Nick')
      report.process_input_record('Nick prescription created')
    end

    it 'routes a filled record correctly' do
      expect(report).to receive(:handle_filled).with('Nick')
      report.process_input_record('Nick prescription filled')
    end

    it 'routes a returned record correctly' do
      expect(report).to receive(:handle_returned).with('Nick')
      report.process_input_record('Nick prescription returned')
    end

    it 'prints an error for an unknown record type' do
      expect { report.process_input_record('Nick prescription deleted') }
        .to output(/'deleted' is an invalid record type./).to_stdout
    end
  end

  # ─────────────────────────────────────────────
  # #process_input_file
  # ─────────────────────────────────────────────
  describe '#process_input_file' do
    context 'when the file exists' do
      let(:file_content) do
        "Nick prescription created\nNick prescription filled\n"
      end

      it 'processes each line' do
        allow(File).to receive(:foreach).and_yield('Nick prescription created')
                                        .and_yield('Nick prescription filled')

        expect(report).to receive(:process_input_record).twice
        report.process_input_file('dummy.txt')
      end
    end

    context 'when the file is not found' do
      it 'prints a file not found error' do
        allow(File).to receive(:foreach).and_raise(Errno::ENOENT)
        expect { report.process_input_file('missing.txt') }
          .to output(/Error: File 'missing.txt' not found./).to_stdout
      end
    end

    context 'when permission is denied' do
      it 'prints a permission denied error' do
        allow(File).to receive(:foreach).and_raise(Errno::EACCES)
        expect { report.process_input_file('secret.txt') }
          .to output(/Error: Permission denied for 'secret.txt'./).to_stdout
      end
    end

    context 'when an unexpected error occurs' do
      it 'prints a generic error message' do
        allow(File).to receive(:foreach).and_raise(StandardError, 'something went wrong')
        expect { report.process_input_file('bad.txt') }
          .to output(/An error occurred: something went wrong/).to_stdout
      end
    end
  end

  # ─────────────────────────────────────────────
  # #report_income
  # ─────────────────────────────────────────────
  describe '#report_income' do
    it 'prints positive income correctly' do
      report.instance_variable_set(:@patient_data, { 'Nick' => [3, 15] })
      expect { report.report_income }
        .to output("Nick: 3 fills $15 income\n").to_stdout
    end

    it 'prints negative income with a minus sign and no double negative' do
      report.instance_variable_set(:@patient_data, { 'Mark' => [0, -1] })
      expect { report.report_income }
        .to output("Mark: 0 fills -$1 income\n").to_stdout
    end

    it 'prints zero income correctly' do
      report.instance_variable_set(:@patient_data, { 'John' => [0, 0] })
      expect { report.report_income }
        .to output("John: 0 fills $0 income\n").to_stdout
    end

    it 'prints all patients' do
      report.instance_variable_set(:@patient_data, {
        'Nick' => [2, 10],
        'Mark'   => [1, -1]
      })
      output = capture_output { report.report_income }
      expect(output).to include('Nick: 2 fills $10 income')
      expect(output).to include('Mark: 1 fills -$1 income')
    end
  end

  # ─────────────────────────────────────────────
  # Integration
  # ─────────────────────────────────────────────
  describe 'integration: full record sequence' do
    it 'produces the correct final state for a mixed sequence' do
      [
        'Nick prescription created',
        'Mark prescription created',
        'Nick prescription filled',
        'Nick prescription filled',
        'Mark prescription filled',
        'Nick prescription returned',
      ].each { |line| report.process_input_record(line) }

      data = report.instance_variable_get(:@patient_data)
      expect(data['Nick']).to eq([1, 4])   # 2 fills (+10), 1 return (-6) = $4
      expect(data['Mark']).to eq([1, 5])
    end
  end

  private

  def capture_output(&block)
    original = $stdout
    $stdout = StringIO.new
    block.call
    $stdout.string
  ensure
    $stdout = original
  end
end