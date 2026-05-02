# frozen_string_literal: true

# Assumptions
# 1. input file is in the data folder of the project
# 2. patient name is unigue
# 3. all input data are string
# 4. no database is required to persist the processed data

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
    patient_name = record_data[0]
    record_type = record_data[2]

    case record_type
    when 'created'
      handle_created(patient_name)
    when 'filled'
      handle_filled(patient_name)
    when 'returned'
      handle_returned(patient_name)
    else
      puts "'#{record_type}' is an invalid record type."
    end
  end

  def handle_created(patient_name)
    if @patient_data.key?(patient_name)
      puts "Invalid 'created' record. Patient #{patient_name} already exists."
    else
      @patient_data[patient_name] = [0, 0]
    end
  end

  def handle_filled(patient_name)
    unless @patient_data.key?(patient_name)
      puts "Invalid 'filled' record. No 'created' record for patient #{patient_name}."
      return
    end

    @patient_data[patient_name][0] += 1
    @patient_data[patient_name][1] += 5
  end

  def handle_returned(patient_name)
    unless @patient_data.key?(patient_name)
      puts "Invalid 'returned' record. No 'created' record for patient #{patient_name}."
      return
    end

    if @patient_data[patient_name][0] < 1
      puts "Invalid 'returned' record. No matching 'filled' record for patient #{patient_name}."
    else
      @patient_data[patient_name][0] -= 1
      @patient_data[patient_name][1] -= 6
    end
  end

  def report_income
    @patient_data.each do |key, value|
      if value[1].negative?
        puts "#{key}: #{value[0]} fills -$#{value[1].abs} income"
      else
        puts "#{key}: #{value[0]} fills $#{value[1]} income"
      end
    end
  end
end

ir = IncomeReport.new
ir.income_report
