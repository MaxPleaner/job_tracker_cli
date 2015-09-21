# job_tracker_cli

CLI Job Application Tracker

Tracks job applications. Written in Ruby.

## To run

1. Clone repo

2. `bundle install` (tested with Ruby 1.9.3 and 2.2.3)

3. To run the cli, enter `ruby app.rb console`

4. run migrations by entering `migrate` to the console

- To load all the code but not run the console, require the file as usual (`require_relative './app.rb'`)

- You can load the app and drop into byebug (if installed) by entering `ruby app.rb byebug`


## Usage

To call a method from the console, enter the method's name.

If a method takes arguments, append them to the method call without quotes

(i.e. `add_company some_company_name`)

`help`: lists available methods

`quit`: exits the program

**Companies** 

`add_company(company_name)`: creates a company record

`find_company(company_name)`: searches for matching companies. company_name can be a partial match, i.e. `find_company sob` will match the company "Sobrr".

`all_companies`: list all companies

`responded_companies`: list companies which have responded

`non_responded_companies`: list companies which have not responded

`responded_percentage`: list percentage of companies which have responded

`rejected_percentage`: list percentage of companies which have rejected

`mark_rejected(company_name)`: mark a company as rejected

`mark_responded(company_name)`: mark a company as responded

`pending_responded_companies`: companies which have responded but not rejected


**Events**

`add_event(company_name)`: add an event record to the given company. Prompts will be subsequently presented for the "content" and "is_response" attributes. If the event is a response from the company, "is_response" should be true.

`company_events(company_name)`: lists events associated with the given company

`responses`: list all events which are responses from companies

`scheduled_events`: list all events with :is_scheduled as true. I.e. homework (coding challenges), scheduled interviews or phone screens. 

`mark_unscheduled(event_id)`: set :is_scheduled to false. For example, when a scheduled phone screen has already happened.
 
**Application Counts**

`last_day_applied_count`: num companies added in last 24 hours

`total_applied_count`: total number of companies

`responded_percentage`: percentage of companies which have responded

`rejected_perecentage`: percentage of companies which have rejected

**Database**

`migrate`: run the migrations

`remigrate`: drop tables and run migrations again

## TODO

- Refactor app.rb into different files
- Use many migrations instead of just one
- Add reminder system for when to follow up with companies
- Add web interface with CRUD forms
- Hack the mainframe
