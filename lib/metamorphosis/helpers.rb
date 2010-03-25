module Metamorphosis
  # Goal: retrieve the caller base path, that is the very place where
  # the script extending Metamorphosis is located. This is the location
  # of Metamorphosis local "circe" (by default) configuration directory.

  # stollen from Sinatra:
  
  # TODO/FIXME: add configuration option to add custom callers regexp
  CALLERS_TO_IGNORE = [
    /\/metamorphosis(\/(core|helpers))?\.rb$/, # all metamorphosis code
    #/\(.*\)/, # any generated code
    /custom_require\.rb$/, # rubygems require hacks
  ]

  # add Rubinius (and hopefully other VM impls) ignore patterns...
  CALLERS_TO_IGNORE.concat(RUBY_IGNORE_CALLERS) if defined?(RUBY_IGNORE_CALLERS)

  def self.caller_locations
    caller.map    { |line| line.split(/:(?=\d|in )/)[0,2] }
    .reject { |file, line| CALLERS_TO_IGNORE.any? { |pattern| file =~ pattern } }
  end

  # Like Kernel#caller but excluding certain magic entries and without
  # line / method information; the resulting array contains filenames only
  def self.caller_files
    caller_locations.map { |file,line| file }
  end

  # returns the full path of the script which Metamorphosis has
  # been called from by Receiver.extend Metamorphosis.
  def self.receiver_base_path
    Pathname.new(caller_files.first).realpath.dirname
  end
end
