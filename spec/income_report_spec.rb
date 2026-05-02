require 'rspec'
require 'income_report'

RSpec.describe IncomeReport do
  subject(:report) { described_class.new }
 
  before { report.instance_variable_set(:@patient_data, {}) }
 
  # ───────────────────────────────────────────────
  # handle_created
  # ───────────────────────────────────────────────
  describe '#handle_created' do
    it 'initialises a new patient/medication entry with zero fills and zero income' do
      report.handle_created('Nick A')
      expect(report.instance_variable_get(:@patient_data)['Nick A']).to eq([0, 0])
    end
 
    it 'prints an error and does not overwrite when the key already exists' do
      report.handle_created('Nick A')
      expect { report.handle_created('Nick A') }
        .to output(/Invalid 'created' record.*Nick.*A/i).to_stdout
      # value must remain unchanged
      expect(report.instance_variable_get(:@patient_data)['Nick A']).to eq([0, 0])
    end
  end
 
  # ───────────────────────────────────────────────
  # handle_filled
  # ───────────────────────────────────────────────
  describe '#handle_filled' do
    context 'when a created record exists' do
      before { report.handle_created('Mark B') }
 
      it 'increments the fill count by 1' do
        expect { report.handle_filled('Mark B') }
          .to change { report.instance_variable_get(:@patient_data)['Mark B'][0] }
          .from(0).to(1)
      end
 
      it 'increments the income by $5' do
        expect { report.handle_filled('Mark B') }
          .to change { report.instance_variable_get(:@patient_data)['Mark B'][1] }
          .from(0).to(5)
      end
 
      it 'accumulates correctly across multiple fills' do
        3.times { report.handle_filled('Mark B') }
        expect(report.instance_variable_get(:@patient_data)['Mark B']).to eq([3, 15])
      end
    end
 
    context 'when no created record exists' do
      it 'prints an error message' do
        expect { report.handle_filled('Paul D') }
          .to output(/Invalid 'filled' record.*Paul.*D/i).to_stdout
      end
 
      it 'does not create a new entry' do
        report.handle_filled('Paul D')
        expect(report.instance_variable_get(:@patient_data)).not_to have_key('Paul D')
      end
    end
  end
 
  # ───────────────────────────────────────────────
  # handle_returned
  # ───────────────────────────────────────────────
  describe '#handle_returned' do
    context 'when no created record exists' do
      it 'prints an error message' do
        expect { report.handle_returned('Paul D') }
          .to output(/Invalid 'returned' record.*No 'created' record/i).to_stdout
      end
    end
 
    context 'when a created record exists but no fills have been made' do
      before { report.handle_created('John E') }
 
      it 'prints an error about no matching filled record' do
        expect { report.handle_returned('John E') }
          .to output(/Invalid 'returned' record.*No matching 'filled' record/i).to_stdout
      end
 
      it 'does not change the fill count' do
        expect { report.handle_returned('John E') }
          .not_to change { report.instance_variable_get(:@patient_data)['John E'][0] }
      end
    end
 
    context 'when at least one fill exists' do
      before do
        report.handle_created('John E')
        report.handle_filled('John E')
      end
 
      it 'decrements the fill count by 1' do
        expect { report.handle_returned('John E') }
          .to change { report.instance_variable_get(:@patient_data)['John E'][0] }
          .from(1).to(0)
      end
 
      it 'decrements the income by $6' do
        expect { report.handle_returned('John E') }
          .to change { report.instance_variable_get(:@patient_data)['John E'][1] }
          .from(5).to(-1)
      end
    end
  end
 
  # ───────────────────────────────────────────────
  # process_input_record
  # ───────────────────────────────────────────────
  describe '#process_input_record' do
    it 'delegates a created line to handle_created' do
      expect(report).to receive(:handle_created).with('Nick A')
      report.process_input_record('Nick A created')
    end
 
    it 'delegates a filled line to handle_filled' do
      expect(report).to receive(:handle_filled).with('Nick A')
      report.process_input_record('Nick A filled')
    end
 
    it 'delegates a returned line to handle_returned' do
      expect(report).to receive(:handle_returned).with('Nick A')
      report.process_input_record('Nick A returned')
    end
 
    it 'prints an error for an unrecognised record type' do
      expect { report.process_input_record('Nick A unknown') }
        .to output(/'unknown' is an invalid record type/i).to_stdout
    end
  end
 
  # ───────────────────────────────────────────────
  # process_input_file
  # ───────────────────────────────────────────────
  describe '#process_input_file' do
    it 'processes every line in the file' do
      lines = ["Nick A created\n", "Nick A filled\n"]
      allow(File).to receive(:foreach).and_yield(lines[0]).and_yield(lines[1])
 
      expect(report).to receive(:process_input_record).with(lines[0])
      expect(report).to receive(:process_input_record).with(lines[1])
      report.process_input_file('dummy.txt')
    end
 
    it 'prints an error when the file does not exist' do
      allow(File).to receive(:foreach).and_raise(Errno::ENOENT)
      expect { report.process_input_file('missing.txt') }
        .to output(/Error: File 'missing.txt' not found/i).to_stdout
    end
 
    it 'prints an error when the file cannot be read due to permissions' do
      allow(File).to receive(:foreach).and_raise(Errno::EACCES)
      expect { report.process_input_file('secret.txt') }
        .to output(/Error: Permission denied for 'secret.txt'/i).to_stdout
    end
 
    it 'prints a generic error message for other exceptions' do
      allow(File).to receive(:foreach).and_raise(StandardError, 'disk failure')
      expect { report.process_input_file('bad.txt') }
        .to output(/An error occurred: disk failure/i).to_stdout
    end
  end
 
  # ───────────────────────────────────────────────
  # report_income
  # ───────────────────────────────────────────────
  describe '#report_income' do
    it 'prints positive income correctly' do
      report.instance_variable_set(:@patient_data, { 'Paul B' => [3, 15] })
      expect { report.report_income }
        .to output(/Paul: 3 fills \$15 income/).to_stdout
    end
 
    it 'prints negative income with a minus sign and no double-negative' do
      report.instance_variable_set(:@patient_data, { 'Mark C' => [1, -1] })
      expect { report.report_income }
        .to output(/Mark: 1 fills -\$1 income/).to_stdout
    end
 
    it 'prints zero income with a positive format' do
      report.instance_variable_set(:@patient_data, { 'Nick A' => [0, 0] })
      expect { report.report_income }
        .to output(/Nick: 0 fills \$0 income/).to_stdout
    end
 
    it 'prints one line per patient entry' do
      report.instance_variable_set(:@patient_data, {
        'Nick A'   => [2, 10],
        'Mark   E' => [1, -1]
      })
      output = capture_output { report.report_income }
      expect(output.lines.count).to eq(2)
    end
  end
 
  # ───────────────────────────────────────────────
  # integration — income_report (full pipeline)
  # ───────────────────────────────────────────────
  describe '#income_report' do
    let(:file_lines) do
      [
        "Nick A created\n",
        "Nick A filled\n",
        "Nick A filled\n",
        "Nick A returned\n",
        "Mark B created\n",
        "Mark B filled\n"
      ]
    end
 
    before do
      stub_const('ARGV', ['test_input.txt'])
      allow(File).to receive(:foreach)
        .with('test_input.txt')
        .and_yield(file_lines[0])
        .and_yield(file_lines[1])
        .and_yield(file_lines[2])
        .and_yield(file_lines[3])
        .and_yield(file_lines[4])
        .and_yield(file_lines[5])
    end
 
    it 'produces the correct income summary for each patient' do
      output = capture_output { report.income_report }
      # Nick: 2 fills, 2×$5 = $10 income, then 1 return at -$6 → net $4, fill count = 1
      expect(output).to match(/Nick: 1 fills \$4 income/)
      # Mark: 1 fill → $5 income
      expect(output).to match(/Mark: 1 fills \$5 income/)
    end
  end
 
  # ───────────────────────────────────────────────
  # helper
  # ───────────────────────────────────────────────
  def capture_output(&block)
    original = $stdout
    $stdout = StringIO.new
    block.call
    $stdout.string
  ensure
    $stdout = original
  end
end