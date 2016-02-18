#!/usr/bin/env ruby
require 'byebug'
require 'awesome_print'
require 'colored'
require 'sqlite3'
require 'active_record'
require 'yaml'
require 'active_support/all'

BasePath = "/home/max/job_tracker_cli"

DATABASE_FILENAME = File.expand_path("#{BasePath}/job_tracker_cli.db", __FILE__)
SQLite3::Database.new(DATABASE_FILENAME)
ActiveRecord::Base.establish_connection(
  adapter: 'sqlite3',
  database: DATABASE_FILENAME
)

class CompanyNotFoundError < StandardError
end

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
  def attributes
  end
end

class Company < ActiveRecord::Base
  has_many :events
  validates :name, presence: true, uniqueness: {case_sensitive: false}
  def public_attrs(verbose=false)
    return self.attributes if verbose
    created_str = ->(timestamp) {
      DateTime.new(timestamp)
              .strftime("%b %d (%A)")
              .in_time_zone("Pacific Time (US & Canada)")
    }
    {
      'company' => "#{name} #{"- rejected" if rejected} #{"- responsed" if responded} - #{created_str.call(created_at.to_i)}",
      "#{name} events" => events.map(&:public_attrs)
    }.reject { |k,v| v.blank? }
  end
end

class Event < ActiveRecord::Base
  belongs_to :company
  validates :content, presence: true
  def public_attrs(verbose=false)
    return self.attributes if verbose
    created_str = ->(timestamp) {
      DateTime.new(timestamp)
              .strftime("%b %d (%A)")
              .in_time_zone("Pacific Time (US & Canada)")
    }
    {
      'event' => "#{company.name} event #{"#" + id.to_s} #{"- response" if is_response} #{"- scheduled" if is_scheduled} #{content} - #{created_str.call(created_at.to_i)} "
    }
  end
end

class Print
  def self.print_companies(companies)
    ap companies.map(&:public_attrs)
  end
  def self.print_events(events)
    ap events.map(&:public_attrs)
  end
end

class JobTrackerApi
  def initialize(options={})
  end
  def backup(verbose=false)
    companies = Company.all.includes(:events).map do |company|
      company.public_attrs(verbose)
    end
    File.open("#{BasePath}/backup.yml", 'w') do |file|
      file.write(YAML.dump(companies))
    end
  end
  def readme
    puts File.read('./README.md')
  end
  def migrate
    Migrations.migrate(:up)
  end
  def remigrate
    puts "are you sure? Database contents will be deleted. (y to continue)"
    if gets.chomp.downcase == "y"
      Migrations.migrate(:down)
      Migrations.migrate(:up)
    else
      puts "cancelled".yellow
    end
  end
  def exit
    super
  end
  def quit
    exit
  end
  def help
#     puts <<-TXT
# help() 
# quit() 
# readme() 
# find_record(company)
# all_companies() 
# add_company(company_name)
# find(*company_name)
# non_rejected() 
# non_responded() 
# rejected() 
# responded() 
# responded_non_rejected() 

# Events
# ---------
# events(company_name)
# add_event(company_name)
# add_rejection(company_name)
# mark_unscheduled(event_id)
# mark_scheduled(event_id)
# responses() 
# scheduled() 

# Todos
# ---------
# todos() 
# add_todo() 
# delete_todo(id)

# Counts
# ---------
# applied_count() 
# last_day_applied_count() 
# rejected_percentage() 
# responded_percentage() 
# responded_rejected_percentage() 

# Migration
# ---------
# migrate()
# remigrate() 

#     TXT
  end
  def add_company(company_name)
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
  def find(company_name="")
    Print.print_companies(Company
      .where("name LIKE ?", "%#{company_name}%")
      .order(updated_at: :asc)
    )
  end
  def find_record(company)
    ap `grep -nri #{company}* ~/Desktop/jobs` 
  end
  def all_companies()
    find
    # when called without args, find lists all
  end
  def rejected
    Print.print_companies(Company
      .where(rejected: true)
      .order(updated_at: :asc)
    )
  end
  def non_rejected
    Print.print_companies(Company
      .where(rejected: false)
      .order(updated_at: :asc)
    )
  end
  def responded
    Print.print_companies(Company
      .where(responded: true).order(updated_at: :asc)
    )
  end
  def non_responded
    Print.print_companies(Company
      .where(responded: false).order(updated_at: :asc)
    )
  end
  def responded_non_rejected
    Print.print_companies(Company.where(responded: true, rejected: false)
      .order(updated_at: :asc)
    )
  end
  def responded_percentage
    ap ((
      Company.where(responded: true).count.to_f /
      Company.count.to_f
    ) * 100).round(2).to_s + "%"
  end
  def rejected_percentage
    ap ((
      Company.where(rejected: true).count.to_f /
      Company.count.to_f
    ) * 100).round(2).to_s + "%"
  end
  def responded_rejected_percentage
    rejected = Company.where(rejected: true).count.to_f
    responded = Company.where(responded: true).count.to_f
    ap ((
      rejected /
      (responded + rejected)
    ) * 100).round(2).to_s + "%"
  end
  # def mark_rejected(company_name)
  #   company = Company.find_by(name: company_name)
  #   raise CompanyNotFoundError unless company
  #   company.update(rejected: true)
  # end
  def add_event(company_name)
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
  def add_rejection(company_name)
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
  def events(company_name)
    company = Company.find_by(name: company_name)
    raise CompanyNotFoundError unless company
    Print.print_events(company.events.order(updated_at: :asc))
  end
  def responses
    Print.print_events(Event
      .where(is_response: true)
      .order(updated_at: :asc)
    )
  end
  def scheduled
    Print.print_events(Event
      .where(is_scheduled: true)
      .order(updated_at: :asc)
    )
  end
  def mark_scheduled(event_id)
    Event.find(event_id).update(is_scheduled: true)
  end
  def mark_unscheduled(event_id)
    # for when a scheduled event has already passed
    Event.find(event_id).update(is_scheduled: false)
  end
  def applied_count
      ap Company.count
  end
  def last_day_applied_count
    ap Company
      .where(created_at: (Time.now - 24.hours)..Time.now).count
  end
  def add_todo
    puts "enter todo content (1 line only)".yellow
    input = gets.chomp
    Todo.create(content: input)
  end
  def todos
    ap Todo.all.map { |t| {id: t.id, content: t.content} }
  end
  def delete_todo(id)
    Todo.find(id).delete
  end
end


# case ARGV.shift # needs to be shifted, otherwise it interferes with gets
# when "server"
#   File.open("./html/index.html")
# when "byebug"
#   require 'byebug'
#   byebug
#   true
# when "script"
#   begin
#     # Db test connection
#     Company.count
#   rescue StandardError => e
#     JobTrackerCli.migrate
#   end
#   arg = ARGV.shift
#   case arg
#   when "all_companies"
#     JobTrackerCli.all_companies
#   when "non_responded"
#     JobTrackerCli.non_responded
#   when "responded_non_rejected"
#     JobTrackerCli.responded_non_rejected
#   when "events"
#     company_name = ARGV.shift
#     unless company_name.blank?
#       JobTrackerCli.events(company_name)
#     end
#   when "scheduled"
#     JobTrackerCli.scheduled
#   when "responses"
#     JobTrackerCli.responses
#   when "todos"
#     JobTrackerCli.todos
#   else
#     unless arg.blank?
#       company_name = ARGV.shift
#       unless company_name.blank?
#         JobTrackerCli.find company_name
#       end
#     end
#   end
# when "console"
#   puts "Job JobTrackerClilication Tracker".bold
#   puts "to see commands, type help"
#   puts "to exit, type quit"
#   while true
#     begin
#       print "> "
#       input = gets
#       next if input.nil? || input.empty?
#       args = input.chomp.split(" ")
#       method = args.shift.to_sym
#       unless JobTrackerCli.methods(false).include?(method)
#         puts "method not found (type help to see methods)"
#         next
#       end
#       JobTrackerCli.send(method, *args)
#       puts "ok".green
#     rescue CompanyNotFoundError => error
#       puts "company not found".yellow
#     rescue StandardError => error
#       puts error, error.backtrace
#       if error.message.scan(/table.+already\sexists/)
#         puts "Migrations have already been run.".yellow
#       elsif error.class == ActiveRecord::StatementInvalid
#         puts "Active Record error - did you run the migrations?".yellow
#       end
#       if error.class == SQLite3::SQLException
#         true
#       end
#       puts "error".red
#     end
#   end
# end
