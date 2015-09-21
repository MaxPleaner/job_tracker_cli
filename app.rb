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
  end
  def down
    drop_table :companies
    drop_table :events
  end
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

class App
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
    ap methods(false)
  end
  def self.add_company(company_name)
    company = Company.create(name: company_name)
    if company.valid?
      ap(company.attributes)
      puts "create an event for this company? (y for yes)"
      if gets.chomp.downcase == "y" 
        add_event(company_name)
      end
    else
      raise StandardError, company.errors.full_messages
    end
  end
  def self.find_company(company_name="")
    ap Company
        .where("name LIKE ?", "%#{company_name}%").order(created_at: :asc)
        .map(&:attributes)
  end
  def self.all_companies
    find_company
    # when called without args, find_company lists all
  end
  def self.rejected_companies
    ap Company
    .where(rejected: true).order(created_at: :asc).map(&:attributes)
  end
  def self.non_rejected_companies
    ap Company
      .where(rejected: false).order(created_at: :asc).map(&:attributes)
  end
  def self.responded_companies
    ap Company
      .where(responded: true).order(created_at: :asc).map(&:attributes)
  end
  def self.non_responded_companies
    ap Company
      .where(responded: false).order(created_at: :asc).map(&:attributes)
  end
  def self.pending_responded_companies
    # companies which have responded and not rejected
    ap Company.where(responded: true, rejected: false)
      .order(created_at: :asc).map(&:attributes)
  end
  def self.responded_percentage
    ap ((
      Company.where(responded: true).order(created_at: :asc).count.to_f /
      Company.count.to_f
    ) * 100).round(2).to_s + "%"
  end
  def self.rejected_percentage
    ap ((
      Company.where(rejected: true).order(created_at: :asc).count.to_f /
      Company.count.to_f
    ) * 100).round(2).to_s + "%"
  end
  def self.mark_rejected(company_name)
    company = Company.find_by(name: company_name)
    raise CompanyNotFoundError unless company
    company.update(rejected: true)
  end
  def self.mark_responded(company_name)
    company = Company.find_by(name: company_name)
    raise CompanyNotFoundError unless company
    company.update(responded: true)
  end
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
      is_scheduled = (gets.chomp.downcase == "y")
    end
    event = company.events.create(
      content:content,
      is_response: is_response,
      is_scheduled: is_scheduled
    )
    ap event.attributes
  end
  def self.company_events(company_name)
    company = Company.find_by(name: company_name)
    raise CompanyNotFoundError unless company
    ap company.events.order(created_at: :asc).map(&:attributes)
  end
  def self.responses
    ap Event
      .where(is_response: true).order(created_at: :asc).map(&:attributes)
  end
  def self.scheduled_events
    ap Event
      .where(is_scheduled: true).order(created_at: :asc).map(&:attributes)
  end
  def self.mark_unscheduled(event_id)
    # for when a scheduled event has already passed
    Event.find(event_id).update(is_scheduled: false)
  end
  def self.total_applied_count
      ap Company.count
  end
  def self.last_day_applied_count
    ap Company
      .where(created_at: (Time.now - 24.hours)..Time.now).count
  end
end

class CompanyNotFoundError < StandardError
end

case ARGV.shift # needs to be shifted, otherwise it interferes with gets
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

