require 'byebug'
require 'awesome_print'
require 'colored'
require 'sqlite3'
require 'active_record'

DATABASE_FILENAME = "job_tracker_cli.db"
SQLite3::Database.new(DATABASE_FILENAME)
ActiveRecord::Base.establish_connection(
  adapter: 'sqlite3',
  database: 'job_tracker_cli.db'
)

class Migrations < ActiveRecord::Migration
  def up
    create_table :companies do |t|
      t.string :name
      t.boolean :rejected, default: false
      t.boolean :responded, default: false
      t.timestamps null: false
    end
    create_table :events do |t|
      t.integer :company_id
      t.text :content
      t.boolean :is_response, default: false
      t.boolean :is_scheduled, default: false
      t.timestamps null: false
    end
    create_table :todos do |t|
      t.text :content
      t.timestamps null: false
    end
  end
  def down
    drop_table :companies
    drop_table :todos
    drop_table :events
  end
end

class Todo < ActiveRecord::Base
end

class Company < ActiveRecord::Base
  has_many :events
  validates :name, presence: true, uniqueness: {case_sensitive: false}
end

class Event < ActiveRecord::Base
  belongs_to :company
  validates :content, presence: true
  def attributes
    super.merge("company_name" => company.name)
  end
end

class Print
  def self.print_companies(companies)
    ap companies.map(&:attributes)
  end
  def self.print_events(events)
    ap events.map(&:attributes)
  end
end

class App
  def self.readme
    puts File.read('./README.md')
  end
  def self.migrate
    Migrations.migrate(:up)
  end
  def self.remigrate
    puts "are you sure? Database contents will be deleted. (y to continue)"
    if gets.chomp.downcase == "y"
      Migrations.migrate(:down)
      Migrations.migrate(:up)
    else
      puts "cancelled".yellow
    end
  end
  def self.quit
    exit
  end
  def self.help
    puts <<-TXT
Help / Quit
---------
help() 
quit() 
readme() 
find_record(company)

Companies
---------
all_companies() 
add_company(company_name)
find(*company_name)
non_rejected() 
non_responded() 
rejected() 
responded() 
responded_non_rejected() 

Events
---------
events(company_name)
add_event(company_name)
add_rejection(company_name)
mark_unscheduled(event_id)
mark_scheduled(event_id)
responses() 
scheduled() 

Todos
---------
todos() 
add_todo() 
delete_todo(id)

Counts
---------
applied_count() 
last_day_applied_count() 
rejected_percentage() 
responded_percentage() 
responded_rejected_percentage() 

Migration
---------
migrate()
remigrate() 

    TXT
  end
  def self.add_company(company_name)
    company = Company.create(name: company_name)
    if company.valid?
      Print.print_companies([company])
      puts "create an event for this company? (y for yes)"
      if gets.chomp.downcase == "y" 
        add_event(company_name)
      end
    else
      raise StandardError, company.errors.full_messages
    end
  end
  def self.find(company_name="")
    Print.print_companies(Company
      .where("name LIKE ?", "%#{company_name}%")
      .order(updated_at: :asc)
    )
  end
  def self.find_record(company)
    ap `grep -nri #{company}* ~/Desktop/jobs` 
  end
  def self.all_companies
    find
    # when called without args, find lists all
  end
  def self.rejected
    Print.print_companies(Company
      .where(rejected: true)
      .order(updated_at: :asc)
    )
  end
  def self.non_rejected
    Print.print_companies(Company
      .where(rejected: false)
      .order(updated_at: :asc)
    )
  end
  def self.responded
    Print.print_companies(Company
      .where(responded: true).order(updated_at: :asc)
    )
  end
  def self.non_responded
    Print.print_companies(Company
      .where(responded: false).order(updated_at: :asc)
    )
  end
  def self.responded_non_rejected
    Print.print_companies(Company.where(responded: true, rejected: false)
      .order(updated_at: :asc)
    )
  end
  def self.responded_percentage
    ap ((
      Company.where(responded: true).count.to_f /
      Company.count.to_f
    ) * 100).round(2).to_s + "%"
  end
  def self.rejected_percentage
    ap ((
      Company.where(rejected: true).count.to_f /
      Company.count.to_f
    ) * 100).round(2).to_s + "%"
  end
  def self.responded_rejected_percentage
    rejected = Company.where(rejected: true).count.to_f
    responded = Company.where(responded: true).count.to_f
    ap ((
      rejected /
      (responded + rejected)
    ) * 100).round(2).to_s + "%"
  end
  # def self.mark_rejected(company_name)
  #   company = Company.find_by(name: company_name)
  #   raise CompanyNotFoundError unless company
  #   company.update(rejected: true)
  # end
  def self.add_event(company_name)
    company = Company.find_by(name: company_name)
    raise CompanyNotFoundError unless company
    puts "enter content (to end input, type enter then control+d )".yellow
    content = $stdin.readlines.join
    puts "is the event a response from the company? ('y' for yes)".yellow
    is_response = (gets.chomp.downcase == "y")
    company.update(responded: true) if is_response
    puts "is the event a rejection? ('y' for yes)".yellow
    is_rejection = gets.chomp.downcase == 'y'
    if is_rejection
      company.update(rejected: true)
      is_scheduled = false
    else
      puts "is the event scheduled for some time in the future? ('y' for yes)".yellow
      is_scheduled = gets.chomp.downcase
      puts is_scheduled
      puts (is_scheduled == 'y')
      is_scheduled = (is_scheduled == 'y')
    end
    event = company.events.create(
      content: content,
      is_response: is_response,
      is_scheduled: is_scheduled
    )
    Print.print_events([event])
  end
  def self.add_rejection(company_name)
    company = Company.find_by(name: company_name)
    raise CompanyNotFOundError unless company
    company.events.create(
      content: "rejected"
    )
    company.events
      .select { |e| e.is_scheduled }
      .each { |e| e.update(is_scheduled: false) }
    company.update(rejected: true)
  end
  def self.events(company_name)
    company = Company.find_by(name: company_name)
    raise CompanyNotFoundError unless company
    Print.print_events(company.events.order(updated_at: :asc))
  end
  def self.responses
    Print.print_events(Event
      .where(is_response: true)
      .order(updated_at: :asc)
    )
  end
  def self.scheduled
    Print.print_events(Event
      .where(is_scheduled: true)
      .order(updated_at: :asc)
    )
  end
  def self.mark_scheduled(event_id)
    Event.find(event_id).update(is_scheduled: true)
  end
  def self.mark_unscheduled(event_id)
    # for when a scheduled event has already passed
    Event.find(event_id).update(is_scheduled: false)
  end
  def self.applied_count
      ap Company.count
  end
  def self.last_day_applied_count
    ap Company
      .where(created_at: (Time.now - 24.hours)..Time.now).count
  end
  def self.add_todo
    puts "enter todo content".yellow
    input = readlines
    Todo.create(content: input.join)
  end
  def self.todos
    ap Todo.all.map { |t| {id: t.id, content: t.content} }
  end
  def self.delete_todo(id)
    Todo.find(id).delete
  end
end

class CompanyNotFoundError < StandardError
end



case ARGV.shift # needs to be shifted, otherwise it interferes with gets
when "server"
  File.open("./html/index.html")
when "byebug"
  require 'byebug'
  byebug
  true
when "console"
  puts "Job Application Tracker".bold
  puts "to see commands, type help"
  puts "to exit, type quit"
  while true
    begin
      print "> "
      input = gets
      next if input.nil? || input.empty?
      args = input.chomp.split(" ")
      method = args.shift.to_sym
      unless App.methods(false).include?(method)
        puts "method not found (type help to see methods)"
        next
      end
      App.send(method, *args)
      puts "ok".green
    rescue CompanyNotFoundError => error
      puts "company not found".yellow
    rescue StandardError => error
      puts error, error.backtrace
      if error.message.scan(/table.+already\sexists/)
        puts "Migrations have already been run.".yellow
      elsif error.class == ActiveRecord::StatementInvalid
        puts "Active Record error - did you run the migrations?".yellow
      end
      if error.class == SQLite3::SQLException
        true
      end
      puts "error".red
    end
  end
end