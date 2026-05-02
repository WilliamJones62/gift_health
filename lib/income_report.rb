# frozen_string_literal: true

# This class contains income report logic
class IncomeReport
  def income_report
    @patient_data = {}
    process_input_file(ARGV[0])
    report_income
  end

  def process_input_file(file_name)
    File.foreach(file_name) do |line|
      process_input_record(line)
    end
  rescue Errno::ENOENT
    puts "Error: File '#{file_name}' not found."
  rescue Errno::EACCES
    puts "Error: Permission denied for '#{file_name}'."
  rescue StandardError => e
    puts "An error occurred: #{e.message}"
  end

  def process_input_record(line)
    record_data = line.split
    key = "#{record_data[0]} #{record_data[1]}"
    record_type = record_data[2]

    case record_type
    when 'created'
      handle_created(key)
    when 'filled'
      handle_filled(key)
    when 'returned'
      handle_returned(key)
    else
      puts "'#{record_type}' is an invalid record type."
    end
  end

  def handle_created(key)
    if @patient_data.key?(key)
      split_key = key.split(' ')
      puts "Invalid 'created' record. A patient #{split_key[0]} and medication #{split_key[1]} record already exists."
    else
      @patient_data[key] = [0, 0]
    end
  end

  def handle_filled(key)
    split_key = key.split(' ')
    unless @patient_data.key?(key)
      puts "Invalid 'filled' record. No 'created' record for patient #{split_key[0]} and medication #{split_key[1]}."
      return
    end

    @patient_data[key][0] += 1
    @patient_data[key][1] += 5
  end

  def handle_returned(key)
    split_key = key.split(' ')
    unless @patient_data.key?(key)
      puts "Invalid 'returned' record. No 'created' record for patient #{split_key[0]} and medication #{split_key[1]}."
      return
    end

    if @patient_data[key][0] < 1
      puts "Invalid 'returned' record. " \
      "No matching 'filled' record for patient #{split_key[0]} and medication #{split_key[1]}."
    else
      @patient_data[key][0] -= 1
      @patient_data[key][1] -= 6
    end
  end

  def report_income
    @patient_data.each do |key, value|
      split_key = key.split(' ')
      if value[1].negative?
        puts "#{split_key[0]}: #{value[0]} fills -$#{value[1].abs} income"
      else
        puts "#{split_key[0]}: #{value[0]} fills $#{value[1]} income"
      end
    end
  end
end

ir = IncomeReport.new
ir.income_report
