require "heroku/command/base"
PGSNAPSHOTS_URL = 'http://localhost:3000'

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
      RestClient.post(PGSNAPSHOTS_URL + '/client/resource',
                      json_encode({"name" => attachment.resource_name}) )
    end
  end

  def status(name)
    @memo = {}
    return @memo[name] if @memo[name]
    RestClient.get(PGSNAPSHOTS_URL + "/client/resource/#{name}") do |response|
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