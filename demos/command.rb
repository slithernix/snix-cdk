#!/usr/bin/env ruby
# frozen_string_literal: true

require 'ostruct'
require 'optparse'
require_relative '../lib/slithernix/cdk'

class Command
  MAXHISTORY = 5000

  def self.help(entry)
    # Create the help message.
    mesg = [
      '<C></B/14>Help',
      '',
      '</B/24>When in the command line.',
      '<B=history   > Displays the command history.',
      '<B=Ctrl-^    > Displays the command history.',
      '<B=Up Arrow  > Scrolls back one command.',
      '<B=Down Arrow> Scrolls forward one command.',
      '<B=Tab       > Activates the scrolling window.',
      '<B=help      > Displays this help window.',
      '',
      '</B/24>When in the scrolling window.',
      '<B=l or L    > Loads a file into the window.',
      '<B=s or S    > Saves the contents of the window to a file.',
      '<B=Up Arrow  > Scrolls up one line.',
      '<B=Down Arrow> Scrolls down one line.',
      '<B=Page Up   > Scrolls back one page.',
      '<B=Page Down > Scrolls forward one page.',
      '<B=Tab/Escape> Returns to the command line.',
      '',
      '<C> (</B/24>Refer to the scrolling window online manual ' \
      'for more help<!B!24>.)'
    ]
    entry.screen.popupLabel(mesg, mesg.size)
  end

  def self.main
    intro_mesg = [
      '<C></B/16>Little Command Interface',
      '',
      '<C>Written by Chris Sauro',
      '',
      '<C>Type </B>help<!B> to get help.'
    ]
    command = String.new
    prompt = '</B/24>Command >'
    title = '<C></B/5>Command Output Window'

    # Set up the history
    history = OpenStruct.new
    history.count = 0
    history.current = 0
    history.command = []

    # Check the command line for options
    opts = OptionParser.getopts('t:p:')
    prompt = opts['p'] if opts['p']
    title = opts['t'] if opts['t']

    # Set up CDK
    curses_win = Curses.init_screen
    cdkscreen = Slithernix::Cdk::Screen.new(curses_win)

    # Set up CDK colors
    Slithernix::Cdk::Draw.init_color

    # Create the scrolling window.
    command_output = Slithernix::Cdk::Widget::SWindow.new(
      cdkscreen,
      Slithernix::Cdk::CENTER,
      Slithernix::Cdk::TOP,
      -8,
      -2,
      title,
      1000,
      true,
      false
    )

    # Convert the prompt to a chtype and determine its length
    prompt_len = []
    Slithernix::Cdk.char2Chtype(
      prompt,
      prompt_len,
      []
    )

    prompt_len = prompt_len[0]
    command_field_width = Curses.cols - prompt_len - 4

    # Create the entry field.
    command_entry = Slithernix::Cdk::Widget::Entry.new(
      cdkscreen,
      Slithernix::Cdk::CENTER,
      Slithernix::Cdk::BOTTOM,
      '',
      prompt,
      Curses::A_BOLD | Curses.color_pair(8),
      Curses.color_pair(24) | '_'.ord, :MIXED,
      command_field_width,
      1,
      512,
      false,
      false
    )

    # Create the key bindings.
    history_up_cb = lambda do |_cdktype, entry, history, _key|
      # Make sure we don't go out of bounds
      if history.current.zero?
        Slithernix::Cdk.Beep
        return false
      end

      # Decrement the counter.
      history.current -= 1

      # Display the command.
      entry.setValue(history.command[history.current])
      entry.draw(entry.box)
      false
    end

    history_down_cb = lambda do |_cdktype, entry, history, _key|
      # Make sure we don't go out of bounds
      if history.current == @count
        Slithernix::Cdk.Beep
        return false
      end

      # Increment the counter.
      history.current += 1

      # If we are at the end, clear the entry field.
      if history.current == history.count
        entry.clean
        entry.draw(entry.box)
        return false
      end

      # Display the command.
      entry.setValue(history.command[history.current])
      entry.draw(entry.box)
      false
    end

    view_history_cb = lambda do |_cdktype, entry, swindow, _key|
      # Let them play...
      swindow.activate([])

      # Redraw the entry field.
      entry.draw(entry.box)
      false
    end

    list_history_cb = lambda do |_cdktype, entry, history, _key|
      height = history.count < 10 ? history.count + 3 : 13

      # No history, no list.
      if history.count.zero?
        # Popup a little message telling the user there are no comands.
        mesg = [
          '<C></B/16>No Commands Entered',
          '<C>No History',
        ]
        entry.screen.popupLabel(mesg, 2)

        # Redraw the screen.
        entry.erase
        entry.screen.draw

        # And leave...
        return false
      end

      # Create the scrolling list of previous commands.
      scroll_list = Slithernix::Cdk::Widget::Scroll.new(
        entry.screen,
        Slithernix::Cdk::CENTER,
        Slithernix::Cdk::CENTER,
        Slithernix::Cdk::RIGHT,
        height,
        20,
        '<C></B/29>Command History',
        history.command,
        history.count,
        true,
        Curses::A_REVERSE,
        true,
        false
      )

      # Get the command to execute.
      selection = scroll_list.activate([])
      scroll_list.destroy

      # Check the results of the selection.
      if selection >= 0
        # Get the command and stick it back in the entry field
        entry.setValue(history.command[selection])
      end

      # Redraw the screen.
      entry.erase
      entry.screen.draw
      false
    end

    jump_window_cb = lambda do |_cdktype, entry, swindow, _key|
      # Ask them which line they want to jump to.
      scale = Slithernix::Cdk::Widget::Scale.new(
        entry.screen, Slithernix::Cdk::CENTER,
        Slithernix::Cdk::CENTER,
        '<C>Jump To Which Line',
        'Line',
        Curses::A_NORMAL,
        5,
        0,
        0,
        swindow.list_size,
        1,
        2,
        true,
        false
      )

      # Get the line.
      line = scale.activate([])

      # Clean up.
      scale.destroy

      # Jump to the line.
      swindow.jumpToLine(line)

      # Redraw the widget.
      entry.draw(entry.box)
      false
    end

    command_entry.bind(:Entry, Curses::KEY_UP, history_up_cb, history)
    command_entry.bind(:Entry, Curses::KEY_DOWN, history_down_cb, history)
    command_entry.bind(:Entry, Slithernix::Cdk::KEY_TAB, view_history_cb,
                       command_output)
    command_entry.bind(:Entry, Slithernix::Cdk.CTRL('^'), list_history_cb,
                       history)
    command_entry.bind(:Entry, Slithernix::Cdk.CTRL('G'), jump_window_cb,
                       command_output)

    # Draw the screen.
    cdkscreen.refresh

    # Show them who wrote this and how to get help.
    cdkscreen.popupLabel(intro_mesg, intro_mesg.size)
    command_entry.erase

    # Do this forever.
    loop do
      # Get the command
      command_entry.draw(command_entry.box)
      command = command_entry.activate([])
      upper = command.upcase

      # Check the output of the command
      if %w[QUIT EXIT Q E].include?(upper) ||
         command_entry.exit_type == :ESCAPE_HIT
        # All done.
        command_entry.destroy
        command_output.destroy
        cdkscreen.destroy

        Slithernix::Cdk::Screen.endCDK

        exit # EXIT_SUCCESS
      elsif command == 'clear'
        # Keep the history.
        history.command << command
        history.count += 1
        history.current = history.count
        command_output.clean
        command_entry.clean
      elsif command == 'history'
        # Display the history list.
        list_history_cb.call(:Entry, command_entry, history, 0)

        # Keep the history.
        history.command << command
        history.count += 1
        history.current = history.count
      elsif command == 'help'
        # Keep the history
        history.command << command
        history.count += 1
        history.current = history.count

        # Display the help.
        Command.help(command_entry)

        # Clean the entry field.
        command_entry.clean
        command_entry.erase
      else
        # Keep the history
        history.command << command
        history.count += 1
        history.current = history.count

        # Jump to the bottom of the scrolling window.
        command_output.jumpToLine(Slithernix::Cdk::BOTTOM)

        # Insert a line providing the command.
        command_output.add(format('Command: </R>%s', command),
                           Slithernix::Cdk::BOTTOM)

        # Run the command
        command_output.exec(command, Slithernix::Cdk::BOTTOM)

        # Clean out the entry field.
        command_entry.clean
      end
    end
  end
end

Command.main
