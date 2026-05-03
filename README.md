# Income Report README
This application takes a text input file containing patient prescription history data and outputs a report to stdout of the number of 'filled' prescriptions and the dollar value generated for each patient.

## Environment

The application uses 
* Ruby version 3.4.4

## Running the code

Run 'bundle install' to install the gems

To run the tests navigate to the main directory of the repo and run 
'bundle exec rspec spec/income_report_spec.rb'

To run the code navigate to the lib directory of the repo and run 
'ruby report_income.rb input_file.txt'

## Code design

A runner file (report_income.rb) was used to separate the execution of the application from the IncomeReport class (income_report.rb), which contains all the reporting code. This allowed RSpec tests to be written only for the class, making them easier to write.

A hash was used to store the data for the report, with the key containing the patient name and the medication, and a value array containing a count of 'filled' events and a dollar amount total. This seemed to be the simplest way to store the incoming data. Each of the entries in the hash were then processed to create a new hash with a key of patient name and a value array containing a count of 'filled' events and a dollar amount total for all the drugs the patient has taken. This second hash is then used to generate the report. I could have sorted the input data by name and record type, and then accumulated the 'filled' events and a dollar amounts for each patient, but I think this approach would have resulted in code that would be more difficult to understand.

I think that it is important to account for all of the input data and not just the data that is included in the output report. So an error report is also produced. I could have persisted the rejected data in a new text file, but I thought that a report to stdout would be sufficient.

RSpec was used as the testing tool, rather than Minitest or Cucumber, as I have more experience using RSpec.

## Assumptions

1. The input file is located in the 'lib' folder of the project
2. The value in the 'name' input field uniquely identifies a patient (i.e. only one patient has a specific name)
3. All input data are strings
4. No database is required to persist the processed data
5. Errors can be sent to stdout

## License

The application is available as open source under the terms of the [MIT License](https://opensource.org).
