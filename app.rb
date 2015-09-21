require 'awesome_print'
require 'colored'
require 'sqlite3'
require 'active_record'

sqlite_db = SQLite3::Database.new("job_tracker_cli.db")
ActiveRecord::Base.establish_connection(
	adapter: 'sqlite3',
	database: 'job_tracker_cli.db'
)

class Migrations < ActiveRecord::Migration
	def up
		create_table :companies do |t|
			t.string :name
			t.timestamps null: false
		end
		create_table :events do |t|
			t.integer :company_id
			t.text :content
			t.boolean :is_response, default: false
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
		Migrations.migrate(:down)
		Migrations.migrate(:up)
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
			add_event(company_name) if gets.chomp.downcase == "y" 
		else
			fail(StandardError, company.errors.full_messages)
		end
	end
	def self.find_company(company_name="")
		ap Company
				.where("name LIKE ?", "%#{company_name}%")
				.order(created_at: :asc)
				.map(&:attributes)
	end
	def self.all_companies
		find_company
		# when called without args, find_company lists all
	end
	def self.add_event(company_name)
		puts "enter content (to end input, type enter then control+d )".yellow
		content = $stdin.readlines.join
		puts "is the event a response from the company? Type 'y' for yes".yellow
		is_response = (gets.chomp.downcase == "y")
		event = Company.find_by(name: company_name).events.create(
			content:content,
			is_response: is_response
		)
		ap event.attributes
	end
	def self.company_events(company_name)
		ap Company.find_by(name: company_name)
			.events
			.order(created_at: :asc)
			.map(&:attributes)
	end
	def self.responses
		ap Event
			.where(is_response: true)
			.order(created_at: :asc)
			.map(&:attributes)
	end
	def self.total_applied_count
		  ap Company.count
	end
	def self.last_day_applied_count
		ap Company
			.where(created_at: (Time.now - 24.hours)..Time.now)
			.count
	end
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
		rescue StandardError => error
			puts error, error.backtrace
			if error.class == ActiveRecord::StatementInvalid
				puts "Active Record error - did you run the migrations?".yellow
				puts "Do so by typing migrate or reset the db by typing remigrate (will wipe data)".yellow
			end
			puts "error".red
		end
	end
end
