#!/usr/bin/ruby

=begin
 Context Free Editor

 Copyright (C) 2005

 This program is free software; you can redistribute it and/or
 modify it under the terms of the GNU General Public License as published
 by the Free Software Foundation; either version 2 of the License, or
 (at your option) any later version.

 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with this program; if not, write to the Free Software
 Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA
 02111-1307  USA
=end
 
require 'libglade2'
require "#{File.dirname(__FILE__)}/lib/open4"

class Test
	TITLE = "Context Free Editor"
	NAME = "ContextFreeEditor"
	VERSION = "1.0"

	def initialize(path)
        @glade = GladeXML.new(path) {|handler| method(handler)}
		@Console = @glade.get_widget("Console")
		@txtConsole = @glade.get_widget("txtConsole")
		
		@imgContext = @glade.get_widget("imgContext")
		@txtContext = @glade.get_widget("txtContext")
		@buffer = @txtContext.buffer
		@mainWindow = @glade.get_widget("mainWindow")
		
		@txt_width = @glade.get_widget("txt_width")
		@txt_height = @glade.get_widget("txt_height")
		@txt_variation = @glade.get_widget("txt_variation")
		
		@chk_crop = @glade.get_widget("chk_crop")
				
		@About = @glade.get_widget("About")
		@Confirmation = @glade.get_widget("Confirmation")

		@statusBar = @glade.get_widget("statusBar")

		@dlgOpen = @glade.get_widget("dlgOpen")
		@dlgSave = @glade.get_widget("dlgSave")
		
		@filename = nil
		@statusLine = 0
		@statusMsg = "Ready"
		
		update_statusbar
		
		@txtContext.buffer.signal_connect("changed") do
			if @filename != nil
				@mainWindow.title = '*' + File.basename(@filename) + ' - Context Free'
			else
				@mainWindow.title = '*Not saved - Context Free'
			end
			update_statusbar
		end
		
		# Undo / Redo
		
		@undopool = Array.new
		@redopool = Array.new

		@buffer.signal_connect("insert_text") do |w, iter, text, length|
			if @user_action
				@undopool <<  ["insert_text", iter.offset, iter.offset + text.scan(/./).size, text]
				@redopool.clear
			end
		end
		
		@buffer.signal_connect("delete_range") do |w, start_iter, end_iter|
			text = @buffer.get_text(start_iter, end_iter)
			@undopool <<  ["delete_range", start_iter.offset, end_iter.offset, text] if @user_action
		end

		@txtContext.signal_connect("move-cursor") do
			update_statusbar
		end
	
		@buffer.signal_connect("mark-set") do |w, iter, mark|
			update_statusbar
		end
	
	    @buffer.signal_connect("begin_user_action") do
			@user_action = true
		end
    
		@buffer.signal_connect("end_user_action") do
			@user_action = false
		end
	end

	def update_statusbar
		@statusLine = @buffer.get_iter_at_mark(@buffer.get_mark("insert")).line + 1
		strReady = @statusBar.get_context_id("main")
		@statusBar.pop(strReady)
		@statusBar.push(strReady,"Ln #{@statusLine}, #{@statusMsg}") 
	end
	
	def on_quit()
		on_cancel_clicked
		if @txtContext.buffer.modified?
			ret = @Confirmation.run
				if ret == Gtk::Dialog::RESPONSE_OK
					Gtk.main_quit
				end
			@Confirmation.hide
		else 
			Gtk.main_quit
		end
	end

	# New cfdg file
	
	def on_new_activate
		@imgContext.file=nil
		@txtContext.buffer.text = ''
		@filename = nil
		@mainWindow.title='Context Free'
		@txtContext.buffer.modified=false
		@statusMsg = "Ready"
		update_statusbar
	end

	# Open file dialog

	def on_open_activate
		ret = @dlgOpen.run
		if ret == Gtk::Dialog::RESPONSE_OK
			text = File.open(@dlgOpen.filename){|f| ret = f.readlines.join }
			@txtContext.buffer.text = text
			@filename = @dlgOpen.filename
			@txtContext.buffer.modified=false
			@imgContext.file = nil
			@mainWindow.title=File.basename(@filename+' - Context Free') # "Context Free"
		@statusMsg = "Ready"
		update_statusbar
		end
		@dlgOpen.hide
	end
	
	# Save cfdg file
	
	def on_save_activate
		save
	end
	
	# Save as... cfdg file
	
	def on_save_as1_activate
		@filename=nil
		save
	end

	# Show save dialog if it's a new file
	
	def save()
		if @filename != nil
			save_file(@filename)
			@mainWindow.title=File.basename(@filename+' - Context Free')
		else
			ret = @dlgSave.run
			if ret == Gtk::Dialog::RESPONSE_OK
				@filename = @dlgSave.filename
				save_file(@filename)
				@mainWindow.title=File.basename(@filename+' - Context Free')
			end
			@dlgSave.hide
		end
		@txtContext.buffer.modified=false
	end
	
	# save file
	
	def save_file(filename)
    	File.open(filename, "w"){|f| f.write(@txtContext.buffer.text)}
	end
	
	# cfdg render file
		
	def on_render_clicked
		render
	end

	def render(w=500,h=500)
		on_cancel_clicked
		w = @txt_width.text.to_i if @txt_width.text.to_i > 0
		h = @txt_height.text.to_i if @txt_height.text.to_i > 0

		options = "-w #{w} -h #{h}"
		
		if @txt_variation.text.length == 3
			variation = @txt_variation.text.upcase
			options += " -v #{variation}"
		end
		
		if @chk_crop.active?
			options += " -c"
		end
		
		save_file(File.dirname($0)+'/input/.__TEMPFILE__.cfdg')
		@txtConsole.buffer.text = ''
		
		@statusMsg = "Rendering. Please wait..."
		update_statusbar
		
		@imgContext.file = nil
		@cfdg=Thread.new {
			out, err = nil
			status =
			  Open4::popen4(File.dirname($0)+'/bin/cfdg '+options+' '+File.dirname($0)+'/input/.__TEMPFILE__.cfdg /tmp/contextfree.png') do |cid, i, o, e|
				@pid = cid
				i.close
				out = o.read
			  end

			  @txtConsole.buffer.text = out.strip

			 strRendering = @statusBar.get_context_id("main")
			
			if status.exitstatus == 0 
			   @imgContext.file = '/tmp/contextfree.png'
			   #@statusBar.push(strRendering,'Render has completed')
			   @statusMsg = "Render has completed"
			else
			   @imgContext.file = nil
			   #@statusBar.push(strRendering,'Render error')
			   @statusMsg = "Render error"
			   on_show_console_activate
			end
			update_statusbar
			@pid = nil
		}

	end

	# Cancel Render
	
	def on_cancel_clicked
		if @pid != nil 
		@statusMsg = "Render has been aborted"
		update_statusbar
			Process.kill(9,@pid)
			@cfdg.kill
			@pid = nil
		end
	end

	# Edit menu :: Cut
	
	def on_cut_activate
		@txtContext.signal_emit("cut_clipboard")
	end
	
	# Edit menu :: Copy
	
	def on_copy_activate
		@txtContext.signal_emit("copy_clipboard")
	end
	
	# Edit menu :: Paste
	
	def on_paste_activate
		@txtContext.signal_emit("paste_clipboard")
	end
	
	# Edit menu :: Select all
	
	def on_select_all_activate
		@txtContext.buffer.place_cursor(@txtContext.buffer.end_iter)
    	@txtContext.buffer.move_mark(@txtContext.buffer.get_mark("selection_bound"), @txtContext.buffer.start_iter)
	end
	
	# Show / hide the render console
	# Render console displays the context free command line
	# exit message.
	
	def on_show_console_activate
		@Console.show
	end
	
	def on_ConsoleClose
		@Console.hide
	end
	
	# Save image
	
	def on_save_image_activate
			ret = @dlgSave.run
			if ret == Gtk::Dialog::RESPONSE_OK
				filename = @dlgSave.filename
						img = File.open("/tmp/contextfree.png"){|f| ret = f.readlines.join }
						f = File.new(filename,  "w+")
						f.write(img)
						f.close
			end
			@dlgSave.hide
	end
	
	# Show the about... window
	
	def on_about_activate
		@About.run	
		@About.hide
	end
	
	
  # undo / redo
  def on_undo(widget)
    return if @undopool.size == 0
    action = @undopool.pop 
    case action[0]
    when "insert_text"
      start_iter = @buffer.get_iter_at_offset(action[1])
      end_iter = @buffer.get_iter_at_offset(action[2])
      @buffer.delete(start_iter, end_iter)
    when "delete_range"
      start_iter = @buffer.get_iter_at_offset(action[1])
      @buffer.insert(start_iter, action[3])
    end
    @redopool << action
	@buffer.place_cursor(start_iter)
	@txtContext.scroll_mark_onscreen(@buffer.get_mark("insert"))
  end

  def on_redo(widget)
    return if @redopool.size == 0
    action = @redopool.pop 
    case action[0]
    when "insert_text"
      start_iter = @buffer.get_iter_at_offset(action[1])
      end_iter = @buffer.get_iter_at_offset(action[2])
      @buffer.insert(start_iter, action[3])
    when "delete_range"
      start_iter = @buffer.get_iter_at_offset(action[1])
      end_iter = @buffer.get_iter_at_offset(action[2])
      @buffer.delete(start_iter, end_iter)
    end
    @undopool << action
	@buffer.place_cursor(start_iter)
	@txtContext.scroll_mark_onscreen(@buffer.get_mark("insert"))
  end
  
end

# Start it all

Gnome::Program.new(Test::NAME, Test::VERSION)
Test.new(File.dirname($0)+'/ContextEditor.glade')
Gtk.main
