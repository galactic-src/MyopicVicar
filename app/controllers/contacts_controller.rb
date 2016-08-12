class ContactsController < ApplicationController

  require 'freereg_options_constants'

  skip_before_filter :require_login, only: [:new, :report_error, :create]

  def convert_to_issue
    @contact = Contact.id(params[:id]).first
    if @contact.present?
      if @contact.github_issue_url.blank?
        @contact.github_issue
        flash.notice = "Issue created on Github."
        redirect_to contact_path(@contact.id)
        return
      else
        flash.notice = "Issue has already been created on Github."
        redirect_to :action => "show"
        return
      end
    else
      go_back("contact",params[:id])
    end
  end

  def create
    @contact = Contact.new(contact_params)
    if @contact.contact_name.blank? #spam trap
      session.delete(:flash)
      @contact.session_data = session
      @contact.previous_page_url= request.env['HTTP_REFERER']
      if @contact.selected_county == 'nil'
        @contact.selected_county = nil
      end
      if @contact.save
        flash[:notice] = "Thank you for contacting us!"
        @contact.communicate
        if @contact.query
          redirect_to search_query_path(@contact.query, :anchor => "#{@contact.record_id}")
          return
        else
          redirect_to @contact.previous_page_url
          return
        end
      else
        @options = FreeregOptionsConstants::ISSUES
        @contact.contact_type = FreeregOptionsConstants::ISSUES[0]
        render :new
        return
      end
    else
      redirect_to :action => 'new'
      return
    end
  end

  def destroy
    @contact = Contact.id(params[:id]).first
    if @contact.present?
      @contact.delete
      flash.notice = "Contact destroyed"
      redirect_to :action => 'index'
      return
    else
      go_back("contact",params[:id])
    end
  end

  def edit
    @contact = Contact.id(params[:id]).first
    if @contact.present?
      if @contact.github_issue_url.present?
        flash[:notice] = "Issue cannot be edited as it is already committed to GitHub. Please edit there"
        redirect_to :action => 'show'
        return
      end
    else
      go_back("contact",params[:id])
    end
  end

  def index
    get_user_info_from_userid
    if @user.person_role == 'county_coordinator' || @user.person_role == 'country_coordinator'
      @county = @user.county_groups
      @contacts = Contact.in(:county => @county).all.order_by(contact_time: -1)
    else
      @contacts = Contact.all.order_by(contact_time: -1)
    end
  end

  def list_by_date
    get_user_info_from_userid
    @contacts = Contact.all.order_by(contact_time: 1)
    render :index
  end

  def list_by_identifier
    get_user_info_from_userid
    @contacts = Contact.all.order_by(identifier: -1)
    render :index
  end

  def list_by_name
    get_user_info_from_userid
    @contacts = Contact.all.order_by(name: 1)
    render :index
  end

  def list_by_type
    get_user_info_from_userid
    @contacts = Contact.all.order_by(contact_type: 1)
    render :index
  end

  def new
    @contact = Contact.new
    @options = FreeregOptionsConstants::ISSUES
    @contact.contact_time = Time.now
    @contact.contact_type = FreeregOptionsConstants::ISSUES[0]
  end

  def report_error
    @contact = Contact.new
    @contact.contact_time = Time.now
    @contact.contact_type = 'Data Problem'
    @contact.query = params[:query]
    @contact.record_id = params[:id]
    if MyopicVicar::Application.config.template_set == 'freereg'
      @contact.entry_id = SearchRecord.find(params[:id]).freereg1_csv_entry._id
      @freereg1_csv_entry = Freereg1CsvEntry.find( @contact.entry_id)
      @contact.county = @freereg1_csv_entry.freereg1_csv_file.county
      @contact.line_id  = @freereg1_csv_entry.line_id
    elsif MyopicVicar::Application.config.template_set == 'freecen'
      rec = SearchRecord.where("id" => @contact.record_id).first
      unless rec.nil?
        ind_id = rec.freecen_individual_id if rec.freecen_individual_id.present?
        @contact.fc_individual_id = ind_id.to_s unless ind_id.nil?
        @contact.county = rec.chapman_code
        fc_ind = FreecenIndividual.where("id" => ind_id).first if ind_id.present?
        if fc_ind.present?
          @contact.entry_id = fc_ind.freecen1_vld_entry_id.to_s unless fc_ind.freecen1_vld_entry_id.nil?
          if @contact.entry_id.present?
            ent = Freecen1VldEntry.where("id" => @contact.entry_id).first
            if ent.present?
              if ent.freecen1_vld_file.present?
                vldfname = ent.freecen1_vld_file.file_name
              end
              @contact.line_id = '' + (vldfname unless vldfname.nil?) + ':dwelling#' + (ent.dwelling_number.to_s unless  ent.dwelling_number.nil?) + ',individual#'+ (ent.sequence_in_household.to_s unless ent.sequence_in_household.nil?)
            end #ent.present
          end # @contact.entry_id.present?
        end # fc_ind.present    
      end # unless rec.nil?
    end # elsif freecen
  end

  def select_by_identifier
    get_user_info_from_userid
    @options = Hash.new
    @contacts = Contact.all.order_by(identifier: -1).each do |contact|
      @options[contact.identifier] = contact.id
    end
    @contact = Contact.new
    @location = 'location.href= "/contacts/" + this.value'
    @prompt = 'Select Identifier'
    render '_form_for_selection'
  end

  def  set_nil_session_parameters
    session[:freereg1_csv_file_id] = nil
    session[:freereg1_csv_file_name] = nil
    session[:place_name] = nil
    session[:church_name] = nil
    session[:county] = nil
  end

  def set_session_parameters_for_record(file)
    if MyopicVicar::Application.config.template_set == 'freereg'
      church = file.register.church
      place = church.place
      session[:freereg1_csv_file_id] = file._id
      session[:freereg1_csv_file_name] = file.file_name
      session[:place_name] = place.place_name
      session[:church_name] = church.church_name
      session[:county] = place.county
    end
  end

  def show
    @contact = Contact.id(params[:id]).first
    if @contact.present?
      if @contact.entry_id.present? && Freereg1CsvEntry.id(@contact.entry_id).present?
        file = Freereg1CsvEntry.id(@contact.entry_id).first.freereg1_csv_file
        set_session_parameters_for_record(file)
      else
        set_nil_session_parameters
      end
    else
      go_back("contact",params[:id])
    end
  end

  def update
    @contact = Contact.id(params[:id]).first
    if @contact.present?
      @contact.update_attributes(contact_params)
      redirect_to :action => 'show'
      return
    else
      go_back("contact",params[:id])
    end
  end

  private
  def contact_params
    params.require(:contact).permit!
  end

end
