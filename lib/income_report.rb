# frozen_string_literal: true

# This class contains income report logic
class IncomeReport
  def income_report
    @patient_data = {}
    process_input_file(ARGV[0])
    report_income
  end

  def process_input_file(file_name)
    start_errors
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

  def start_errors
    puts ' '
    puts '**** Error messages begin ****'
    puts ' '
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
    @report_data = {}
    load_report_data

    print_report
  end

  def load_report_data
    @patient_data.each do |key, value|
      split_key = key.split(' ')
      name = split_key[0]
      if @report_data.key?(name)
        # a hash entry already exists so add the data for this drug to
        # the value
        @report_data[name][0] += value[0]
        @report_data[name][1] += value[1]
      else
        # need to create a hash entry for this patient
        @report_data[name] = [value[0], value[1]]
      end
    end
  end

  def print_report
    end_errors
    @report_data.each do |key, value|
      if value[1].negative?
        puts "#{key}: #{value[0]} fills -$#{value[1].abs} income"
      else
        puts "#{key}: #{value[0]} fills $#{value[1]} income"
      end
    end
  end

  def end_errors
    puts ' '
    puts '**** Error messages end ****'
    puts ' '
  end
end
