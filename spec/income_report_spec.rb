require 'rspec'
require 'stringio'
require 'tempfile'
require 'income_report' 
 
RSpec.describe IncomeReport do
  subject(:report) { described_class.new }
 
  # ── shared helpers ────────────────────────────────────────────────────────
 
  # Suppress puts noise; return everything that was printed.
  def capture
    old = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = old
  end
 
  # Expose the private hash so expectations don't have to call public methods.
  def data
    report.instance_variable_get(:@patient_data)
  end
 
  # Seed @patient_data before a test that needs pre-existing entries.
  def seed(hash)
    report.instance_variable_set(:@patient_data, hash)
  end
 
  # Write lines to a Tempfile and return the path.
  def tmp(*lines)
    f = Tempfile.new(['income_report', '.txt'])
    f.write(lines.join("\n"))
    f.close
    f.path
  end
 
  # ══════════════════════════════════════════════════════════════════════════
  # start_errors / end_errors
  # ══════════════════════════════════════════════════════════════════════════
 
  describe '#start_errors' do
    it 'prints the opening banner' do
      out = capture { report.start_errors }
      expect(out).to include('**** Error messages begin ****')
    end
  end
 
  describe '#end_errors' do
    it 'prints the closing banner' do
      out = capture { report.end_errors }
      expect(out).to include('**** Error messages end ****')
    end
  end
 
  # ══════════════════════════════════════════════════════════════════════════
  # handle_created
  # ══════════════════════════════════════════════════════════════════════════
 
  describe '#handle_created' do
    before { seed({}) }
 
    context 'when the patient/medication pair is new' do
      it 'adds the key with fill count 0 and income 0' do
        report.handle_created('Mark A')
        expect(data['Mark A']).to eq([0, 0])
      end
 
      it 'does not print any error' do
        out = capture { report.handle_created('Mark A') }
        expect(out).to be_empty
      end
    end
 
    context 'when the patient/medication pair already exists' do
      before { data['Mark A'] = [2, 10] }
 
      it 'prints an invalid-created error naming the patient' do
        out = capture { report.handle_created('Mark A') }
        expect(out).to include("Invalid 'created' record")
        expect(out).to include('Mark')
      end
 
      it 'prints an invalid-created error naming the medication' do
        out = capture { report.handle_created('Mark A') }
        expect(out).to include('A')
      end
 
      it 'leaves the existing entry unchanged' do
        capture { report.handle_created('Mark A') }
        expect(data['Mark A']).to eq([2, 10])
      end
 
      it 'does not add a second entry' do
        capture { report.handle_created('Mark A') }
        expect(data.size).to eq(1)
      end
    end
  end
 
  # ══════════════════════════════════════════════════════════════════════════
  # handle_filled
  # ══════════════════════════════════════════════════════════════════════════
 
  describe '#handle_filled' do
    before { seed({}) }
 
    context 'when no created record exists for the key' do
      it 'prints an invalid-filled error naming the patient' do
        out = capture { report.handle_filled('Nick B') }
        expect(out).to include("Invalid 'filled' record")
        expect(out).to include('Nick')
      end
 
      it 'prints an invalid-filled error naming the medication' do
        out = capture { report.handle_filled('Nick B') }
        expect(out).to include('B')
      end
 
      it 'does not create a new entry' do
        capture { report.handle_filled('Nick B') }
        expect(data).not_to have_key('Nick B')
      end
    end
 
    context 'when a created record exists' do
      before { data['Nick B'] = [0, 0] }
 
      it 'increments the fill count by 1' do
        report.handle_filled('Nick B')
        expect(data['Nick B'][0]).to eq(1)
      end
 
      it 'increases income by $5' do
        report.handle_filled('Nick B')
        expect(data['Nick B'][1]).to eq(5)
      end
 
      it 'accumulates correctly across multiple fills' do
        4.times { report.handle_filled('Nick B') }
        expect(data['Nick B']).to eq([4, 20])
      end
 
      it 'prints nothing' do
        out = capture { report.handle_filled('Nick B') }
        expect(out).to be_empty
      end
    end
  end
 
  # ══════════════════════════════════════════════════════════════════════════
  # handle_returned
  # ══════════════════════════════════════════════════════════════════════════
 
  describe '#handle_returned' do
    before { seed({}) }
 
    context 'when no created record exists for the key' do
      it 'prints an invalid-returned error naming the patient' do
        out = capture { report.handle_returned('John C') }
        expect(out).to include("Invalid 'returned' record")
        expect(out).to include('John')
      end
 
      it 'prints an invalid-returned error naming the medication' do
        out = capture { report.handle_returned('John C') }
        expect(out).to include('C')
      end
 
      it 'does not create a new entry' do
        capture { report.handle_returned('John C') }
        expect(data).not_to have_key('John C')
      end
    end
 
    context 'when the record exists but fill count is 0' do
      before { data['John C'] = [0, 0] }
 
      it 'prints a no-matching-filled error' do
        out = capture { report.handle_returned('John C') }
        expect(out).to include("Invalid 'returned' record")
        expect(out).to include("No matching 'filled' record")
      end
 
      it 'names the patient in the error' do
        out = capture { report.handle_returned('John C') }
        expect(out).to include('John')
      end
 
      it 'names the medication in the error' do
        out = capture { report.handle_returned('John C') }
        expect(out).to include('C')
      end
 
      it 'does not modify the entry' do
        capture { report.handle_returned('John C') }
        expect(data['John C']).to eq([0, 0])
      end
    end
 
    context 'when a matching filled record exists' do
      before { data['John C'] = [3, 15] }
 
      it 'decrements the fill count by 1' do
        report.handle_returned('John C')
        expect(data['John C'][0]).to eq(2)
      end
 
      it 'reduces income by $6' do
        report.handle_returned('John C')
        expect(data['John C'][1]).to eq(9)
      end
 
      it 'allows income to go negative after enough returns' do
        # 1 fill (+5) then 1 return (-6) => -1
        seed({ 'John C' => [1, 5] })
        report.handle_returned('John C')
        expect(data['John C'][1]).to eq(-1)
      end
 
      it 'prints nothing' do
        out = capture { report.handle_returned('John C') }
        expect(out).to be_empty
      end
    end
  end
 
  # ══════════════════════════════════════════════════════════════════════════
  # process_input_record
  # ══════════════════════════════════════════════════════════════════════════
 
  describe '#process_input_record' do
    before { seed({}) }
 
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
      out = capture { report.process_input_record('Paul D dissolved') }
      expect(out).to include("'dissolved' is an invalid record type")
    end
 
    it 'constructs the key from the first two tokens' do
      seed({ 'Paul D' => [0, 0] })
      expect(report).to receive(:handle_filled).with('Paul D')
      capture { report.process_input_record('Paul D filled extra tokens ignored') }
    end
  end
 
  # ══════════════════════════════════════════════════════════════════════════
  # process_input_file
  # ══════════════════════════════════════════════════════════════════════════
 
  describe '#process_input_file' do
    before { seed({}) }
 
    it 'prints the opening error banner' do
      path = tmp('Nick A created')
      out = capture { report.process_input_file(path) }
      expect(out).to include('**** Error messages begin ****')
    end
 
    it 'processes every record in the file' do
      path = tmp(
        'Nick A created',
        'Nick A filled',
        'Nick A filled',
        'Nick A returned'
      )
      capture { report.process_input_file(path) }
      # 2 fills → +10, 1 return → -6 : net [1, 4]
      expect(data['Nick A']).to eq([1, 4])
    end
 
    it 'handles a file with multiple patients' do
      path = tmp(
        'Nick A created',
        'Mark B created',
        'Nick A filled',
        'Mark B filled',
        'Mark B filled'
      )
      capture { report.process_input_file(path) }
      expect(data['Nick A']).to eq([1, 5])
      expect(data['Mark B']).to eq([2, 10])
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
        path = tmp('Nick A created')
        File.chmod(0o000, path)
        path
      end
 
      after { File.chmod(0o644, locked_file) }
 
      it 'prints a permission-denied error' do
        out = capture { report.process_input_file(locked_file) }
        expect(out).to include('Permission denied')
      end
 
      it 'includes the filename in the permission error' do
        out = capture { report.process_input_file(locked_file) }
        expect(out).to include(locked_file)
      end
 
      it 'does not raise an uncaught exception' do
        expect { capture { report.process_input_file(locked_file) } }.not_to raise_error
      end
    end
  end
 
  # ══════════════════════════════════════════════════════════════════════════
  # report_income
  # ══════════════════════════════════════════════════════════════════════════
 
  describe '#report_income' do
    it 'prints the closing error banner' do
      seed({})
      out = capture { report.report_income }
      expect(out).to include('**** Error messages end ****')
    end
 
    it 'formats positive income with a dollar sign' do
      seed({ 'John F' => [3, 15] })
      out = capture { report.report_income }
      expect(out).to include('John: 3 fills $15 income')
    end
 
    it 'formats zero income without a minus sign' do
      seed({ 'John F' => [0, 0] })
      out = capture { report.report_income }
      expect(out).to include('John: 0 fills $0 income')
    end
 
    it 'formats negative income with a leading minus sign' do
      seed({ 'John F' => [0, -6] })
      out = capture { report.report_income }
      expect(out).to include('John: 0 fills -$6 income')
    end
 
    it 'does not print a double-negative for negative income' do
      seed({ 'John F' => [0, -6] })
      out = capture { report.report_income }
      expect(out).not_to include('$-6')
    end
 
    it 'prints one income line per patient key' do
      seed({
        'John F' => [1, 5],
        'Mark G' => [2, 10]
      })
      out = capture { report.report_income }
      expect(out).to include('John:')
      expect(out).to include('Mark:')
    end
 
    it 'uses only the first token of the key as the patient name' do
      seed({ 'Paul C' => [1, 5] })
      out = capture { report.report_income }
      expect(out).to include('Paul:')
      expect(out).not_to include('C:')
    end
  end
 
  # ══════════════════════════════════════════════════════════════════════════
  # income_report  (full integration)
  # ══════════════════════════════════════════════════════════════════════════
 
  describe '#income_report' do
    def run_with(lines)
      path = tmp(*lines)
      stub_const('ARGV', [path])
      capture { report.income_report }
    end
 
    it 'initialises @patient_data to an empty hash before processing' do
      # Pre-pollute to verify it is reset
      report.instance_variable_set(:@patient_data, { 'stale' => [99, 99] })
      path = tmp('Nick A created')
      stub_const('ARGV', [path])
      capture { report.income_report }
      expect(data).not_to have_key('stale')
    end
 
    it 'prints both banners surrounding any errors' do
      out = run_with([
        'Mark A created',
        'Mark A created'  # duplicate triggers an error
      ])
      begin_pos = out.index('**** Error messages begin ****')
      error_pos = out.index("Invalid 'created' record")
      end_pos   = out.index('**** Error messages end ****')
      expect(begin_pos).to be < error_pos
      expect(error_pos).to be < end_pos
    end
 
    it 'reports correct totals after a sequence of creates, fills, and returns' do
      out = run_with([
        'John C created',
        'John C filled',    # +1 fill, +$5
        'John C filled',    # +1 fill, +$5
        'John C returned',  # -1 fill, -$6
        'John C filled'     # +1 fill, +$5  → net: 2 fills, $9
      ])
      expect(out).to include('John: 2 fills $9 income')
    end
 
    it 'reports negative net income correctly' do
      out = run_with([
        'Nick B created',
        'Nick B filled',    # +$5
        'Nick B returned',  # -$6  → net: 0 fills, -$1
      ])
      expect(out).to include('Nick: 0 fills -$1 income')
    end
 
    it 'handles multiple independent patients in one file' do
      out = run_with([
        'John D created',
        'John D filled',
        'Mark B created',
        'Mark B filled',
        'Mark B filled'
      ])
      expect(out).to include('John: 1 fills $5 income')
      expect(out).to include('Mark: 2 fills $10 income')
    end
 
    it 'reports all error types that appear in the file' do
      out = run_with([
        'Paul A created',
        'Paul A created',        # duplicate created
        'Bill Z filled',           # filled without created
        'Bill Z returned',         # returned without created
        'Paul A returned',       # returned with fill count 0
        'Paul A badtype'         # invalid record type
      ])
      expect(out).to include("Invalid 'created' record")
      expect(out).to include("Invalid 'filled' record")
      expect(out).to include("Invalid 'returned' record")
      expect(out).to include("No matching 'filled' record")
      expect(out).to include("'badtype' is an invalid record type")
    end
 
    it 'does not raise when the file is missing' do
      stub_const('ARGV', ['/no/such/file.txt'])
      expect { capture { report.income_report } }.not_to raise_error
    end
  end
end
 