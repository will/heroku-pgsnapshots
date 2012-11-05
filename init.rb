require 'uri'
require "heroku/command/base"
PGSNAPSHOTS_URL = ENV['PGSNAPSHOTS_URL'] || 'https://pgsnapshots.herokuapp.com'

class Heroku::Command::Pgsnapshots < Heroku::Command::Base
  include Heroku::Helpers::HerokuPostgresql

  # index
  #
  # show status
  #
  def index
    info = hpg_databases.map do |(name, att)|
     [ name, att.resource_name, status(att.resource_name) ]
    end

    varname_max = info.map{ |line| line[0].size}.max
    resname_max = info.map{ |line| line[1].size}.max

    info.each_with_index.each do |(varname, resname, status)|
      puts [varname.ljust(varname_max), resname.ljust(resname_max), status].join ' '
    end
  end

  # on
  #
  # active a resource
  #
  def on
    attachment = hpg_resolve(shift_argument)
    action("Activating #{attachment.config_var} (#{attachment.resource_name})") do
      RestClient.post( authed_pgsnapshot_url('/client/resource'),
                      json_encode({"name" => attachment.resource_name}) )
    end
  end

  # on
  #
  # deactive a resource
  #
  def off
    attachment = hpg_resolve(shift_argument)
    return unless confirm_command(attachment.config_var, 'Deactiving will destroy all backups')
    action("Dectivating #{attachment.config_var} (#{attachment.resource_name})") do
      RestClient.delete( authed_pgsnapshot_url("/client/resource/#{attachment.resource_name}"))
    end
  end

  # list
  #
  # list backups
  #
  def list
    client = client_from_attachment( hpg_resolve(shift_argument) )

     backups = []
     client.get_transfers.each do |t|
       next unless t['error_at'].nil? && t['destroyed_at'].nil? && backup_types.include?(t['to_name'])
       backups << {
         'id'         => backup_name(t['to_url']),
         'created_at' => t['created_at'],
         'status'     => transfer_status(t),
         'size'       => t['size']
       }
     end

     display_table(
       backups,
       %w[id created_at status size],
       ["ID", "Backup Time", "Status", "Size"]
     )
  end

  # url db [ id ]
  #
  # url for a backup
  #
  def url
    client = client_from_attachment( hpg_resolve(shift_argument) )
    id = shift_argument

    if id
      b = client.get_backup(id)
    else
      b = client.get_latest_backup
    end

    if $stdout.isatty
      display '"'+b['public_url']+'"'
    else
      display b['public_url']
    end
  end

  def authed_pgsnapshot_url(path)
    uri = URI.parse "#{PGSNAPSHOTS_URL}#{path}"
    uri.user     = Heroku::Auth.user.gsub '@', '%40'
    uri.password = Heroku::Auth.password
    uri.to_s
  end

  def client_from_attachment(attachment)
    url = authed_pgsnapshot_url "/client/resource/#{attachment.resource_name}"
    pgbackups_url = json_decode(RestClient.get url)['pgbackups_url']
    Heroku::Client::Pgbackups.new(pgbackups_url)
  end

  def backup_types
    Heroku::Command::Pgbackups.new.send(:backup_types)
  end

  def backup_name(name)
    Heroku::Command::Pgbackups.new.send(:backup_name, name)
  end

  def transfer_status(t)
    Heroku::Command::Pgbackups.new.send(:transfer_status, t)
  end

  def status(name)
    @memo ||= Hash.new
    return @memo[name] if @memo[name]
    RestClient.get( authed_pgsnapshot_url("/client/resource/#{name}")) do |response|
      if response.code == 200
        @memo[name] = 'active'
      elsif response.code == 404
        @memo[name] = 'inactive'
      else
        @memo[name] = 'error'
      end
    end
    @memo[name]
  end
end
