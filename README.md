## Job tracker cli

I've recently changed the CLI interface to this to use my [ruby-cli-skeleton](http://github.com/maxpleaner/ruby-cli-skeleton).

To run this, `clone`, `bundle`, then run the `job_tracker_cli` executable, which starts
a ruby REPL. You can type `help` to see commands.

Some useful commands:
- `migrate` _need to run this first to set up the db_
- `remigrate` _deletes everything_
- `add_company(name)`
- `add_event(company_name)`
- `find(company_name_to_search)`
- `all_companies`
- `backup` - writes to backup.yml
- `read_backup` prints the backup file
- `import_backup` from backup.yml

The source for these commands is `db/job_tracker_api.rb`, where the CLI
base is in `job_tracker_cli`.

The database by default is `job_tracker_cli.db` (sqlite). The db/ folder is ignored by git.
The backup doesnt include todos.

By default, the `backup` command will write a concise summary of the database into
`backup.yml`. To do a full export which can be re-imported, use `backup(true)`

It's helpful to add the cloned folder to the $PATH and add a consice alias for `job_tracker_cli`.

Mine is `job`.