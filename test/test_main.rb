require 'base_test'
require 'methadone'
require 'stringio'

class TestMain < BaseTest
  include Methadone::Main

  def setup
    @logged = []
    @original_argv = ARGV.clone
    ARGV.clear
  end

  # Override error so we can capture what's being logged at this level
  def error(string)
    @logged << string
  end

  def teardown
    set_argv @original_argv
  end

  test "my main block gets called by run and has access to CLILogging" do
    called = false
    main do
      begin
      debug "debug"
      info "info"
      warn "warn"
      error "error"
      fatal "fatal"
      called = true
      rescue => ex
        puts ex.message
      end
    end
    safe_go!
    assert called,"main block wasn't called"
  end

  test "my main block gets the command-line parameters" do
    params = []
    main do |param1,param2,param3|
      params << param1
      params << param2
      params << param3
    end
    set_argv %w(one two three)
    safe_go!
    assert_equal %w(one two three),params
  end

  test "my main block can freely ignore arguments given" do
    called = false
    main do
      called = true
    end
    set_argv %w(one two three)
    safe_go!
    assert called,"Main block wasn't called?!"
  end

  test "my main block can ask for arguments that it might not receive" do
    params = []
    main do |param1,param2,param3|
      params << param1
      params << param2
      params << param3
    end
    set_argv %w(one two)
    safe_go!
    assert_equal ['one','two',nil],params
  end

  test "go exits zero when main evaluates to nil or some other non number" do
    [nil,'some string',Object.new,[],4.5].each do |non_number|
      main { non_number }
      assert_exits(0,"for value #{non_number}") { go! }
    end
  end

  test "go exits with the numeric value that main evaluated to" do
    [0,1,2,3].each do |exit_status|
      main { exit_status }
      assert_exits(exit_status) { go! }
    end
  end

  test "go exits with 70, which is the Linux sysexits.h code for this sort of thing, if there's an exception" do
    main do
      raise "oh noes"
    end
    assert_exits(70) { go! }
    assert_logged_at_error "oh noes"
  end

  test "go exits with the exit status included in the special-purpose excepiton" do
    main do
      raise Methadone::Error.new(4,"oh noes")
    end
    assert_exits(4) { go! }
    assert_logged_at_error "oh noes"
  end

  test "can exit with a specific status by using the helper method instead of making a new exception" do
    main do
      exit_now!(4,"oh noes")
    end
    assert_exits(4) { go! }
    assert_logged_at_error "oh noes"
  end

  test "opts allows us to more expediently set up OptionParser" do
    switch = nil
    flag = nil
    main do
      switch = options[:switch]
      flag = options[:flag]
    end

    opts.on("--switch") { options[:switch] = true }
    opts.on("--flag FLAG") { |value| options[:flag] = value }

    set_argv %w(--switch --flag value)

    safe_go!

    assert switch
    assert_equal 'value',flag
  end

  test "when the command line is invalid, we exit with 1" do
    main do
    end

    opts.on("--switch") { options[:switch] = true }
    opts.on("--flag FLAG") { |value| options[:flag] = value }

    set_argv %w(--invalid --flag value)

    assert_exits(1) { go! }
  end

  test "omitting the block to opts simply sets the value in the options hash and returns itself" do
    switch = nil
    negatable = nil
    flag = nil
    f = nil
    other = nil
    some_other = nil
    main do
      switch = options[:switch]
      flag = options[:flag]
      f = options[:f]
      negatable = options[:negatable]
      other = options[:other]
      some_other = options[:some_other]
    end

    on("--switch")
    on("--[no-]negatable")
    on("--flag FLAG","-f","Some documentation string")
    on("--other") do 
      options[:some_other] = true
    end

    set_argv %w(--switch --flag value --negatable --other)

    safe_go!

    assert switch
    assert some_other
    refute other
    assert_equal 'value',flag
    assert_equal 'value',f,opts.to_s
    assert_match /Some documentation string/,opts.to_s
  end

  private

  # Calls go!, but traps the exit
  def safe_go!
    go!
  rescue SystemExit
  end

  def assert_logged_at_error(expected_message)
    assert @logged.include?(expected_message),"#{@logged} didn't include '#{expected_message}'"
  end

  def assert_exits(exit_code,message='',&block)
    block.call
    fail "Expected an exit of #{exit_code}, but we didn't even exit!"
  rescue SystemExit => ex
    assert_equal exit_code,ex.status,message
  end

  def set_argv(args)
    ARGV.clear
    args.each { |arg| ARGV << arg }
  end
end