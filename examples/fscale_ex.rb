#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative 'example'

class FScaleExample < Example
  def self.parse_opts(opts, param)
    opts.banner = 'Usage: fscale_ex.rb [options]'

    param.x_value = Slithernix::Cdk::CENTER
    param.y_value = Slithernix::Cdk::CENTER
    param.box = true
    param.shadow = false
    param.high = 2.4
    param.low = -1.2
    param.inc = 0.2
    param.width = 10
    super

    opts.on('-h HIGH', OptionParser::DecimalNumeric, 'High value') do |h|
      param.high = h
    end

    opts.on('-l LOW', OptionParser::DecimalNumeric, 'Low value') do |l|
      param.low = l
    end

    opts.on('-i INC', OptionParser::DecimalNumeric, 'Increment amount') do |i|
      param.inc = i
    end

    opts.on('-w WIDTH', OptionParser::DecimalInteger, 'Widget width') do |w|
      param.width = w
    end
  end

  # This program demonstrates the Cdk label widget.
  def self.main
    # Declare variables.
    title = '<C>Select a value'
    label = '</5>Current value'
    params = parse(ARGV)

    # Set up CDK
    curses_win = Curses.init_screen
    cdkscreen = Slithernix::Cdk::Screen.new(curses_win)

    # Set up CDK colors
    Slithernix::Cdk::Draw.init_color

    # Create the widget
    widget = Slithernix::Cdk::Widget::FScale.new(cdkscreen, params.x_value, params.y_value,
                                                 title, label, Curses::A_NORMAL, params.width, params.low, params.low,
                                                 params.high, params.inc, (params.inc * 2), 1, params.box, params.shadow)

    # Is the widget nll?
    if widget.nil?
      # Exit CDK.
      cdkscreen.destroy
      Slithernix::Cdk::Screen.endCDK

      puts 'Cannot make the scale widget. Is the window too small?'
      exit # EXIT_FAILURE
    end

    # Activate the widget.
    selection = widget.activate([])

    # Check the exit value of the widget.
    if widget.exit_type == :ESCAPE_HIT
      mesg = [
        '<C>You hit escape. No value selected.',
        '',
        '<C>Press any key to continue.',
      ]
      cdkscreen.popupLabel(mesg, 3)
    elsif widget.exit_type == :NORMAL
      mesg = [
        '<C>You selected %f' % selection,
        '',
        '<C>Press any key to continue.',
      ]
      cdkscreen.popupLabel(mesg, 3)
    end

    # Clean up
    widget.destroy
    cdkscreen.destroy
    Slithernix::Cdk::Screen.endCDK
    # ExitProgram (EXIT_SUCCESS);
  end
end

FScaleExample.main
