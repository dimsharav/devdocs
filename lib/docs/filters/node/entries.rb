module Docs
  class Node
    class EntriesFilter < Docs::EntriesFilter
      REPLACE_NAMES = {
        'debugger' => 'Debugger',
        'addons'   => 'C/C++ Addons',
        'modules'  => 'module' }

      REPLACE_TYPES = {
        'Addons'                 => 'Miscellaneous',
        'Debugger'               => 'Miscellaneous',
        'os'                     => 'OS',
        'StringDecoder'          => 'String Decoder',
        'TLS (SSL)'              => 'TLS/SSL',
        'UDP / Datagram Sockets' => 'UDP/Datagram',
        'Executing JavaScript'   => 'VM' }

      IGNORE_DEFAULT_ENTRY = %w(globals timers domain buffer)

      def include_default_entry?
        !IGNORE_DEFAULT_ENTRY.include?(slug)
      end

      def get_name
        REPLACE_NAMES[slug] || slug
      end

      def get_type
        type = at_css('h1').content.strip
        REPLACE_TYPES[type] || "#{type.first.upcase}#{type[1..-1]}"
      end

      def additional_entries
        return [] if type == 'Miscellaneous'

        klass = nil
        entries = []

        css('> [id]').each do |node|
          next if node.name == 'h1'

          klass = nil if node.name == 'h2'
          name = node.content.strip

          # Skip constructors
          if name.start_with? 'new '
            next
          end

          # Ignore most global objects (found elsewhere)
          if type == 'Global Objects'
            entries << [name, node['id']] if name.start_with?('_') || name == 'global'
            next
          end

          # Classes
          if name.sub! 'Class: ', ''
            name.sub! 'events.', '' # EventEmitter
            klass = name
            entries << [name, node['id']]
            next
          end

          # Events
          if name.sub! %r{\AEvent: '(.+)'\z}, '\1'
            name << " event (#{klass || type})"
            entries << [name, node['id']]
            next
          end

          name.gsub! %r{\(.*?\)}, '()'
          name.gsub! %r{\[.+?\]}, '[]'
          name.sub! 'assert(), ', '' # assert/assert.ok

          # Skip all that start with an uppercase letter ("Example") or include a space ("exports alias")
          next unless (name.first.upcase! && !name.include?(' ')) || name.start_with?('Class Method')

          # Differentiate server classes (http, https, net, etc.)
          name.sub!('server.') { "#{(klass || 'https').sub('.', '_').downcase!}." }
          # Differentiate socket classes (net, dgram, etc.)
          name.sub!('socket.') { "#{klass.sub('.', '_').downcase!}." }

          name.sub! 'Class Method:', ''
          name.sub! 'buf.',          'buffer.'
          name.sub! 'buf[',          'buffer['
          name.sub! 'child.',        'childprocess.'
          name.sub! 'decoder.',      'stringdecoder.'
          name.sub! 'emitter.',      'eventemitter.'
          name.sub! %r{\Arl\.},      'interface.'
          name.sub! 'rs.',           'readstream.'
          name.sub! 'ws.',           'writestream.'

          # Skip duplicates (listen, connect, etc.)
          unless name == entries[-1].try(:first) || name == entries[-2].try(:first)
            entries << [name, node['id']]
          end
        end

        entries
      end
    end
  end
end
