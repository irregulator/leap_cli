module SupplyDrop
  class Rsync
    class << self
      def command(from, to, options={})
        flags = ['-az']
        flags << '--delete' if options[:delete]
        flags << excludes(options[:excludes]) if options.has_key?(:excludes)
        flags << ssh_options(options[:ssh]) if options.has_key?(:ssh)

        "rsync #{flags.compact.join(' ')} #{from} #{to}"
      end

      def remote_address(user, host, path)
        user_with_host = [user, host].compact.join('@')
        [user_with_host, path].join(':')
      end

      def excludes(patterns)
        [patterns].flatten.map { |p| "--exclude=#{p}" }
      end

      def ssh_options(options)
        mapped_options = options.map do |key, value|
          next unless value

          #
          # for a list of the options normally support by Net::SSH (and thus Capistrano), see
          # http://net-ssh.github.com/net-ssh/classes/Net/SSH.html#method-c-start
          #
          case key
          when :keys then [value].flatten.select { |k| File.exist?(k) }.map { |k| "-i #{k}" }
          when :config then "-F #{value}"
          when :port then "-p #{value}"
          when :user_known_hosts_file then "-o 'UserKnownHostsFile=#{value}'"
          when :global_known_hosts_file then "-o 'GlobalKnownHostsFile=#{value}'"
          when :host_key_alias then "-o 'HostKeyAlias=#{value}'"
          when :paranoid then "-o 'StrictHostKeyChecking=yes'"
          when :host_name then "-o 'HostName=#{value}'"
          end
        end.compact

        %[-e "ssh #{mapped_options.join(' ')}"] unless mapped_options.empty?
      end
    end
  end
end
