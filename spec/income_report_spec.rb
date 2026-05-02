# frozen_string_literal: true

require 'rspec'
require 'stringio'
require 'tempfile'
require 'income_report'

RSpec.describe IncomeReport do
  subject(:report) { described_class.new }
 
  # ── helpers ───────────────────────────────────────────────────────────────
 
  # Capture everything written to $stdout and return it as a string.
  def capture
    old = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = old
  end
 
  # Direct read access to instance variables — keeps tests from calling
  # unrelated public methods just to inspect state.
  def patient_data
    report.instance_variable_get(:@patient_data)
  end
 
  def report_data
    report.instance_variable_get(:@report_data)
  end
 
  # Seed state before a test that needs pre-existing data.
  def seed_patient_data(hash)
    report.instance_variable_set(:@patient_data, hash)
  end
 
  def seed_report_data(hash)
    report.instance_variable_set(:@report_data, hash)
  end
 
  # Write lines to a Tempfile and return the path.
  def tmp(*lines)
    f = Tempfile.new(['income_report', '.txt'])
    f.write(lines.join("\n"))
    f.close
    f.path
  end
 
  # ══════════════════════════════════════════════════════════════════════════
  # start_errors
  # ══════════════════════════════════════════════════════════════════════════
 
  describe '#start_errors' do
    it 'prints the opening error banner' do
      out = capture { report.start_errors }
      expect(out).to include('**** Error messages begin ****')
    end
  end
 
  # ══════════════════════════════════════════════════════════════════════════
  # end_errors
  # ══════════════════════════════════════════════════════════════════════════
 
  describe '#end_errors' do
    it 'prints the closing error banner' do
      out = capture { report.end_errors }
      expect(out).to include('**** Error messages end ****')
    end
  end
 
  # ══════════════════════════════════════════════════════════════════════════
  # handle_created
  # ══════════════════════════════════════════════════════════════════════════
 
  describe '#handle_created' do
    before { seed_patient_data({}) }
 
    context 'when the patient/medication pair is new' do
      it 'creates the entry initialised to [0, 0]' do
        report.handle_created('Nick A')
        expect(patient_data['Nick A']).to eq([0, 0])
      end
 
      it 'does not print anything' do
        out = capture { report.handle_created('Nick A') }
        expect(out).to be_empty
      end
    end
 
    context 'when the patient/medication pair already exists' do
      before { patient_data['Nick A'] = [2, 10] }
 
      it 'prints an invalid-created error' do
        out = capture { report.handle_created('Nick A') }
        expect(out).to include("Invalid 'created' record")
      end
 
      it 'includes the patient name in the error' do
        out = capture { report.handle_created('Nick A') }
        expect(out).to include('Nick')
      end
 
      it 'includes the medication name in the error' do
        out = capture { report.handle_created('Nick A') }
        expect(out).to include('A')
      end
 
      it 'leaves the existing entry unchanged' do
        capture { report.handle_created('Nick A') }
        expect(patient_data['Nick A']).to eq([2, 10])
      end
 
      it 'does not add a duplicate entry' do
        capture { report.handle_created('Nick A') }
        expect(patient_data.size).to eq(1)
      end
    end
  end
 
  # ══════════════════════════════════════════════════════════════════════════
  # handle_filled
  # ══════════════════════════════════════════════════════════════════════════
 
  describe '#handle_filled' do
    before { seed_patient_data({}) }
 
    context 'when no created record exists for the key' do
      it 'prints an invalid-filled error' do
        out = capture { report.handle_filled('Mark B') }
        expect(out).to include("Invalid 'filled' record")
      end
 
      it 'includes the patient name in the error' do
        out = capture { report.handle_filled('Mark B') }
        expect(out).to include('Mark')
      end
 
      it 'includes the medication name in the error' do
        out = capture { report.handle_filled('Mark B') }
        expect(out).to include('B')
      end
 
      it 'does not create a new entry' do
        capture { report.handle_filled('Mark B') }
        expect(patient_data).not_to have_key('Mark B')
      end
    end
 
    context 'when a created record exists' do
      before { patient_data['Mark B'] = [0, 0] }
 
      it 'increments the fill count by 1' do
        report.handle_filled('Mark B')
        expect(patient_data['Mark B'][0]).to eq(1)
      end
 
      it 'increases income by $5' do
        report.handle_filled('Mark B')
        expect(patient_data['Mark B'][1]).to eq(5)
      end
 
      it 'accumulates correctly across multiple fills' do
        4.times { report.handle_filled('Mark B') }
        expect(patient_data['Mark B']).to eq([4, 20])
      end
 
      it 'does not print anything' do
        out = capture { report.handle_filled('Mark B') }
        expect(out).to be_empty
      end
    end
  end
 
  # ══════════════════════════════════════════════════════════════════════════
  # handle_returned
  # ══════════════════════════════════════════════════════════════════════════
 
  describe '#handle_returned' do
    before { seed_patient_data({}) }
 
    context 'when no created record exists for the key' do
      it 'prints an invalid-returned error' do
        out = capture { report.handle_returned('John C') }
        expect(out).to include("Invalid 'returned' record")
      end
 
      it 'includes the patient name in the error' do
        out = capture { report.handle_returned('John C') }
        expect(out).to include('John')
      end
 
      it 'includes the medication name in the error' do
        out = capture { report.handle_returned('John C') }
        expect(out).to include('C')
      end
 
      it 'does not create a new entry' do
        capture { report.handle_returned('John C') }
        expect(patient_data).not_to have_key('John C')
      end
    end
 
    context 'when the created record exists but the fill count is 0' do
      before { patient_data['John C'] = [0, 0] }
 
      it 'prints a no-matching-filled error' do
        out = capture { report.handle_returned('John C') }
        expect(out).to include("No matching 'filled' record")
      end
 
      it 'includes the patient name in the error' do
        out = capture { report.handle_returned('John C') }
        expect(out).to include('John')
      end
 
      it 'includes the medication name in the error' do
        out = capture { report.handle_returned('John C') }
        expect(out).to include('C')
      end
 
      it 'does not modify the entry' do
        capture { report.handle_returned('John C') }
        expect(patient_data['John C']).to eq([0, 0])
      end
    end
 
    context 'when a matching filled record exists' do
      before { patient_data['John C'] = [3, 15] }
 
      it 'decrements the fill count by 1' do
        report.handle_returned('John C')
        expect(patient_data['John C'][0]).to eq(2)
      end
 
      it 'reduces income by $6' do
        report.handle_returned('John C')
        expect(patient_data['John C'][1]).to eq(9)
      end
 
      it 'allows income to go negative' do
        seed_patient_data({ 'John C' => [1, 5] })
        report.handle_returned('John C')
        expect(patient_data['John C'][1]).to eq(-1)
      end
 
      it 'does not print anything' do
        out = capture { report.handle_returned('John C') }
        expect(out).to be_empty
      end
    end
  end
 
  # ══════════════════════════════════════════════════════════════════════════
  # process_input_record
  # ══════════════════════════════════════════════════════════════════════════
 
  describe '#process_input_record' do
    before { seed_patient_data({}) }
 
    it 'routes a created line to handle_created' do
      expect(report).to receive(:handle_created).with('Paul D')
      capture { report.process_input_record('Paul D created') }
    end
 
    it 'routes a filled line to handle_filled' do
      expect(report).to receive(:handle_filled).with('Paul D')
      capture { report.process_input_record('Paul D filled') }
    end
 
    it 'routes a returned line to handle_returned' do
      expect(report).to receive(:handle_returned).with('Paul D')
      capture { report.process_input_record('Paul D returned') }
    end
 
    it 'prints an error for an unknown record type' do
      out = capture { report.process_input_record('Paul D deleted') }
      expect(out).to include("'deleted' is an invalid record type")
    end
 
    it 'builds the key from the first two tokens only' do
      seed_patient_data({ 'Paul D' => [0, 0] })
      expect(report).to receive(:handle_filled).with('Paul D')
      capture { report.process_input_record('Paul D filled extra ignored') }
    end
  end
 
  # ══════════════════════════════════════════════════════════════════════════
  # process_input_file
  # ══════════════════════════════════════════════════════════════════════════
 
  describe '#process_input_file' do
    before { seed_patient_data({}) }
 
    it 'prints the opening error banner' do
      out = capture { report.process_input_file(tmp('Bill A created')) }
      expect(out).to include('**** Error messages begin ****')
    end
 
    it 'processes every record in the file' do
      path = tmp(
        'Bill A created',
        'Bill A filled',
        'Bill A filled',
        'Bill A returned'
      )
      capture { report.process_input_file(path) }
      # 2 fills (+10), 1 return (-6) → [1, 4]
      expect(patient_data['Bill A']).to eq([1, 4])
    end
 
    it 'processes records for multiple patients independently' do
      path = tmp(
        'Bill A created',
        'Bob B created',
        'Bill A filled',
        'Bob B filled',
        'Bob B filled'
      )
      capture { report.process_input_file(path) }
      expect(patient_data['Bill A']).to eq([1, 5])
      expect(patient_data['Bob B']).to eq([2, 10])
    end
 
    context 'when the file does not exist' do
      it 'prints a file-not-found error' do
        out = capture { report.process_input_file('/no/such/file.txt') }
        expect(out).to include('not found')
      end
 
      it 'includes the filename in the error' do
        out = capture { report.process_input_file('/no/such/file.txt') }
        expect(out).to include('/no/such/file.txt')
      end
 
      it 'does not raise an uncaught exception' do
        expect { capture { report.process_input_file('/no/such/file.txt') } }.not_to raise_error
      end
    end
 
    context 'when the file is unreadable', unless: Process.uid.zero? do
      let(:locked_file) do
        path = tmp('Bill A created')
        File.chmod(0o000, path)
        path
      end
 
      after { File.chmod(0o644, locked_file) }
 
      it 'prints a permission-denied error' do
        out = capture { report.process_input_file(locked_file) }
        expect(out).to include('Permission denied')
      end
 
      it 'includes the filename in the error' do
        out = capture { report.process_input_file(locked_file) }
        expect(out).to include(locked_file)
      end
 
      it 'does not raise an uncaught exception' do
        expect { capture { report.process_input_file(locked_file) } }.not_to raise_error
      end
    end
  end
 
  # ══════════════════════════════════════════════════════════════════════════
  # load_report_data
  # ══════════════════════════════════════════════════════════════════════════
 
  describe '#load_report_data' do
    before { seed_report_data({}) }
 
    it 'creates one report entry for a patient with a single medication' do
      seed_patient_data({ 'Nick F' => [3, 15] })
      report.load_report_data
      expect(report_data['Nick']).to eq([3, 15])
    end
 
    it 'sums fills across multiple medications for the same patient' do
      seed_patient_data({
        'Nick F' => [2, 10],
        'Nick D'  => [3, 15]
      })
      report.load_report_data
      expect(report_data['Nick']).to eq([5, 25])
    end
 
    it 'keeps different patients as separate report entries' do
      seed_patient_data({
        'Nick F' => [1, 5],
        'Paul B'   => [2, 10]
      })
      report.load_report_data
      expect(report_data['Nick']).to eq([1, 5])
      expect(report_data['Paul']).to eq([2, 10])
    end
 
    it 'handles negative income correctly when aggregating across medications' do
      seed_patient_data({
        'Mark G' => [1, 5],
        'Mark C'   => [0, -6]
      })
      report.load_report_data
      expect(report_data['Mark']).to eq([1, -1])
    end
 
    it 'produces an empty report_data hash when patient_data is empty' do
      seed_patient_data({})
      report.load_report_data
      expect(report_data).to be_empty
    end
 
    it 'uses only the patient name (first token) as the report key' do
      seed_patient_data({ 'Okonkwo C' => [1, 5] })
      report.load_report_data
      expect(report_data).to have_key('Okonkwo')
      expect(report_data).not_to have_key('C')
    end
  end
 
  # ══════════════════════════════════════════════════════════════════════════
  # print_report
  # ══════════════════════════════════════════════════════════════════════════
 
  describe '#print_report' do
    it 'prints the closing error banner' do
      seed_report_data({})
      out = capture { report.print_report }
      expect(out).to include('**** Error messages end ****')
    end
 
    it 'formats positive income with a dollar sign' do
      seed_report_data({ 'Williams' => [3, 15] })
      out = capture { report.print_report }
      expect(out).to include('Williams: 3 fills $15 income')
    end
 
    it 'formats zero income without a minus sign' do
      seed_report_data({ 'Williams' => [0, 0] })
      out = capture { report.print_report }
      expect(out).to include('Williams: 0 fills $0 income')
    end
 
    it 'formats negative income with a leading minus before the dollar sign' do
      seed_report_data({ 'Williams' => [0, -6] })
      out = capture { report.print_report }
      expect(out).to include('Williams: 0 fills -$6 income')
    end
 
    it 'does not produce a double-negative for negative income' do
      seed_report_data({ 'Williams' => [0, -6] })
      out = capture { report.print_report }
      expect(out).not_to include('$-6')
    end
 
    it 'prints one income line per patient' do
      seed_report_data({ 'Nick' => [1, 5], 'Paul' => [2, 10] })
      out = capture { report.print_report }
      expect(out).to include('Nick:')
      expect(out).to include('Paul:')
    end
 
    it 'prints no patient lines when report_data is empty' do
      seed_report_data({})
      out = capture { report.print_report }
      fills_lines = out.lines.select { |l| l.include?('fills') }
      expect(fills_lines).to be_empty
    end
  end
 
  # ══════════════════════════════════════════════════════════════════════════
  # report_income  (orchestration)
  # ══════════════════════════════════════════════════════════════════════════
 
  describe '#report_income' do
    it 'resets @report_data to an empty hash before loading' do
      # Pre-pollute to confirm it is wiped
      report.instance_variable_set(:@report_data, { 'Stale' => [99, 99] })
      seed_patient_data({})
      capture { report.report_income }
      expect(report_data).not_to have_key('Stale')
    end
 
    it 'delegates data loading to load_report_data' do
      seed_patient_data({})
      expect(report).to receive(:load_report_data)
      capture { report.report_income }
    end
 
    it 'delegates printing to print_report' do
      seed_patient_data({})
      expect(report).to receive(:print_report)
      capture { report.report_income }
    end
  end
 
  # ══════════════════════════════════════════════════════════════════════════
  # income_report  (full integration)
  # ══════════════════════════════════════════════════════════════════════════
 
  describe '#income_report' do
    def run_with(*lines)
      stub_const('ARGV', [tmp(*lines)])
      capture { report.income_report }
    end
 
    it 'resets @patient_data to an empty hash on every run' do
      report.instance_variable_set(:@patient_data, { 'stale' => [99, 99] })
      run_with('Bill A created')
      expect(patient_data).not_to have_key('stale')
    end
 
    it 'prints the opening banner before any error messages' do
      out = run_with('Green A created', 'Green A created')
      expect(out.index('**** Error messages begin ****'))
        .to be < out.index("Invalid 'created' record")
    end
 
    it 'prints the closing banner after all error messages' do
      out = run_with('Green A created', 'Green A created')
      expect(out.index("Invalid 'created' record"))
        .to be < out.index('**** Error messages end ****')
    end
 
    it 'reports correct totals after a mix of creates, fills, and returns' do
      out = run_with(
        'Miller C created',
        'Miller C filled',    # +1 fill, +$5
        'Miller C filled',    # +1 fill, +$5
        'Miller C returned',  # -1 fill, -$6
        'Miller C filled'     # +1 fill, +$5  → 2 fills, $9
      )
      expect(out).to include('Miller: 2 fills $9 income')
    end
 
    it 'aggregates multiple medications into one patient output line' do
      out = run_with(
        'Nick F created',
        'Nick F filled',   # +$5
        'Nick D created',
        'Nick D filled',    # +$5
        'Nick D filled'     # +$5  → Nick: 3 fills, $15
      )
      expect(out).to include('Nick: 3 fills $15 income')
    end
 
    it 'keeps different patients on separate output lines' do
      out = run_with(
        'Allen D created',
        'Allen D filled',
        'Bob B created',
        'Bob B filled',
        'Bob B filled'
      )
      expect(out).to include('Allen: 1 fills $5 income')
      expect(out).to include('Bob: 2 fills $10 income')
    end
 
    it 'reports negative net income for a single medication' do
      out = run_with(
        'Mark G created',
        'Mark G filled',    # +$5
        'Mark G returned'   # -$6  → 0 fills, -$1
      )
      expect(out).to include('Mark: 0 fills -$1 income')
    end
 
    it 'reports negative net income aggregated across two medications' do
      out = run_with(
        'Mark G created',
        'Mark G filled',
        'Mark G returned',   # -$1 so far
        'Mark C created',
        'Mark C filled',
        'Mark C returned'      # -$1 more → Mark: 0 fills, -$2
      )
      expect(out).to include('Mark: 0 fills -$2 income')
    end
 
    it 'surfaces all five error types present in the file' do
      out = run_with(
        'John A created',
        'John A created',   # duplicate created
        'Tim Z filled',      # filled without created
        'Tim Z returned',    # returned without created
        'John A returned',  # returned with fill count 0
        'John A badtype'    # unknown record type
      )
      expect(out).to include("Invalid 'created' record")
      expect(out).to include("Invalid 'filled' record")
      expect(out).to include("Invalid 'returned' record")
      expect(out).to include("No matching 'filled' record")
      expect(out).to include("'badtype' is an invalid record type")
    end
 
    it 'does not raise when the input file is missing' do
      stub_const('ARGV', ['/no/such/file.txt'])
      expect { capture { report.income_report } }.not_to raise_error
    end
  end
end
 