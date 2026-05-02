# Income Report README
This application takes a text input file containing patient prescription history data and outputs a report to stdout of the dollar value generated for each patient.

## Environment

The application uses 
* Ruby version 3.0.3

## Running the code

Run 'bundle install' to install the gems

To run the tests navigate to the main directory of the repo and run 
'bundle exec rspec spec/income_report_spec.rb'

To run the code navigate to the lib directory of the repo and run 
'ruby report_income.rb input_file.txt'

## Code design

A runner file (report_income) was used to separate out the IncomeReport class containing all the reporting code. This allowed RSpec tests to be written only for the class, making testing cleaner.

A hash was used to store the data for the report, with the key containing the patient name and the medication. This seemed to be the most efficient way to store the data. It could also have been done by sorting the input data by name and record type, but this approach is more verbose and less efficient.
The hash key = name + ' ' + medication. The hash value is an array consisting of a count of filled prescriptions and the dollar value generated.

The report is created with one line for each patient that has data to report. It is possible that a patient could have data for multiple drugs, so this is combined in a new hash with only patient name as the key. 

RSpec was used as the testing tool, rather than Minitest or Cucumber, as I have more experience using RSpec.

## Assumptions

1. The input file is located in the 'lib' folder of the project
2. The value in the 'name' input field uniquely identifies a patient (i.e. only one patient has a specific name)
3. All input data are strings
4. No database is required to persist the processed data
5. Errors can be sent to stdout

## License

The application is available as open source under the terms of the [MIT License](https://opensource.org).
