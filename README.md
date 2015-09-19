# job_tracker_cli

CLI Job Application Tracker

Tracks job applications. Written in Ruby.

## To run

1. Clone repoc

2. bundle install

3. To run the cli, enter `ruby app.rb console`

4. run migrations by entering `migrate` to the console

- To load all the code but not run the console, require the file as usual (`require_relative './app.rb'`)


## Usage

To call a method from the console, enter the method's name.

If a method takes arguments, append them to the method call without quotes

(i.e. `add_company some_company_name`)

Methods: 

- `quit` - exits the program

- `help` - lists available methods

- `add_company(company_name)` - creates a company record

- `find_company(company_name)` - searches for matching companies. company_name can be a partial match, i.e. `find_company obrr` will match the company "Sobrr".

- `all_companies` - lists all companies

- `add_event(company_name)` - add an event record to the given company. Prompts will be subsequently presented for the "content" and "is_response" attributes. If the event is a response from the company, "is_response" should be true. 

- `company_events(company_name)` - lists events associated with the given company

- `responses` - list all events which are responses from companies
