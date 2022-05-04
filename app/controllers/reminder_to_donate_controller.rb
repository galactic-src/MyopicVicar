class ReminderToDonateController < ActionController::Base
	def new
    @reminder_to_donate = ReminderToDonate.new
  end

  def create
  	@reminder_to_donate = ReminderToDonate.new(reminder_to_donate_params.delete_if { |_k, v| v.blank? })
  	if @reminder_to_donate.save
  		flash[:notice] = 'saved'
  	else
  		flash[:notice] = 'failed'
  	end
  	redirect_to new_search_query_path
  end

  private

  def reminder_to_donate_params
    params.require(:reminder_to_donate).permit!
  end
end