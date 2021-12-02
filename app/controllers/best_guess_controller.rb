class BestGuessController < ApplicationController
  before_action :viewed
  skip_before_action :require_login
  
  def show
    params[:search_id].present? ? @search = true : @search = false
    if @search
      session[:search_entry_number] = params[:search_entry] if params[:search_entry].present?
      @search_record_number = session[:search_entry_number]
      @anchor_entry = @search_record_number
      redirect_back(fallback_location: new_search_query_path) && return unless show_value_check
    end
    get_user_info_from_userid if cookies.signed[:userid].present?
    @saved_record = params[:saved_record] if params[:saved_record].present?
    @page_number = params[:page_number].to_i
    @option = params[:filter_option] if params[:filter_option].present?
    record_from_page = params[:record_of_page].to_i if params[:record_of_page].present?
    record_id = params[:id]
     #@search_record = BestGuess.where(RecordNumber: params[:id]).first
    #@current_record_number = current_record_number_to_display(params[:id].to_i, record_from_page)
    #@search_record_number = session[:search_entry_number] #params[:search_entry].present? ? params[:search_entry] : params[:id]
    @search_record = BestGuess.find(@search_record_number)
    @current_record_number = current_record_number_to_display(@search_record_number.to_i, record_from_page)
    @current_record = BestGuess.find(record_id)
    #@anchor_entry = params[:search_entry].present? ? params[:search_entry] : @current_record.RecordNumber if @search
    page_entries = @current_record.entries_in_the_page
    @next_record_of_page, @previous_record_of_page = next_and_previous_entries_of_page(record_id, page_entries)
    @display_date = false
    show_postem_or_scan
    if @search_query.present?
      @search_result = @search_query.search_result
      @viewed_records = @search_result.viewed_records
      @viewed_records << params[:id] unless @viewed_records.include?(params[:id])
      @search_result.update_attribute(:viewed_records, @viewed_records)
    end
  end

  def current_record_number_to_display(search_record_number, page_record_number = nil)
    if page_record_number.present?
      record_number = page_record_number
    else
      record_number = search_record_number
    end
    record_number
  end

  def from_quarter_to_year(quarter)
    (quarter-1)/4 + 1837
  end

  def next_and_previous_entries_of_page(current, sorted_array)
    array = sorted_array.map(&:to_i)
    current = current.to_i
    current_index = array.index(current)
    next_record_id = nil
    previous_record_id = nil
    next_record_id = array[current_index + 1] unless current_index.nil? || array.nil? || current_index >= array.length - 1
    previous_record_id = array[current_index - 1] unless array.nil? || current_index.nil? || current_index.zero?
    next_record_of_page = BestGuess.find(next_record_id) if next_record_id.present?
    previous_record_of_page = BestGuess.find(previous_record_id) if previous_record_id.present?
    [next_record_of_page, previous_record_of_page]
  end

  def show_marriage
    params[:search_id].present? ? @search = true : @search = false
    record_number = params[:entry_id]
    @search_id = params[:search_id] if @search
    @record = BestGuess.where(RecordNumber: record_number).first
    spouse_surname = @record.AssociateName
    volume = @record.Volume
    page = @record.Page
    quarter = @record.QuarterNumber
    district_number = @record.DistrictNumber
    record_type = @record.RecordTypeID
    @spouse_record = BestGuess.where(Surname: spouse_surname, Volume: volume, Page: page, QuarterNumber: quarter, DistrictNumber: district_number, RecordTypeID: record_type).first
  end

  def show_reference_entry
    record_number = params[:entry_id]
    @search_id = params[:search_id] if params[:search_id].present?
    @record = BestGuess.where(RecordNumber: record_number).first
    late_entry_pointer_record_numbers = @record.late_entry_pointer
    reference_entry_record_numbers = @record.late_entry_detail
    (@record.Confirmed & BestGuess::ENTRY_LINK).zero? ? late_entry_pointer_record_numbers.unshift(record_number) : reference_entry_record_numbers.unshift(record_number)
    @primary_array, @secondary_array = primary_and_secondary_array(@record, late_entry_pointer_record_numbers, reference_entry_record_numbers)
    @primary_referral_record, @primary_next_record, @primary_previous_record = record_cycle params[:primary_referral_number], @primary_array
    @secondary_referral_record, @secondary_next_record, @secondary_previous_record = record_cycle params[:secondary_referral_number], @secondary_array
  end


  def notes_vino
     #referral = @record.reference_record_information
    #current_record_number =  referral.first
    #current_record_number = params[:referral_number] if params[:primary_referral_number].present?
    #@referral_record = BestGuess.where(RecordNumber: current_record_number).first
  end

  def record_cycle current=nil, array
    current.present? ? current_record_number = current : current_record_number = array.first
    referral_record = BestGuess.find(current_record_number) if current_record_number.present?
    next_record, previous_record = next_and_previous_entries_of_page(current_record_number, array)
    [referral_record, next_record, previous_record]
  end

  def primary_and_secondary_array entry, array1, array2
    (entry.Confirmed & BestGuess::ENTRY_LINK).zero? ? primary_array = array1 : primary_array = array2
    (entry.Confirmed & BestGuess::ENTRY_LINK).zero? ? secondary_array = array2 : secondary_array = array1
    [primary_array, secondary_array]
  end


  def same_page_entries
    params[:search_id].present? ? @search = true : @search = false
    @search_id = params[:search_id] if params[:search_id].present?
    record_number = params[:entry_id]
    @record = BestGuess.find(record_number)
    @volume = params[:volume]
    @page = params[:page]
    @district = params[:district]
    @quarter = params[:quarter]
    @page_records = BestGuess.where(Volume: @volume, Page: @page, QuarterNumber: params[:quarter], RecordTypeID: params[:record])
  end

  def sort_records(records)
    results.sort! do |x, y|
      compare_records(y, x, 'Surname','GivenName')
    end
  end

  def compare_records(x, y, order_field, next_order_field=nil)
    if x[order_field] == y[order_field]
      if x[next_order_field].nil? || y[next_order_field].nil?
        return x[next_order_field].to_s <=> y[next_order_field].to_s
      end
      return x[next_order_field] <=> y[next_order_field]
    end
    if x[order_field].nil? || y[order_field].nil?
      return x[order_field].to_s <=> y[order_field].to_s
    end
    return x[order_field] <=> y[order_field]
  end

  def viewed
    session[:viewed] ||= []
  end

  def show_value_check
    messagea = 'We are sorry but the record you requested no longer exists; possibly as a result of some data being edited. You will need to redo the search with the original criteria to obtain the updated version.'
    warning = "#{appname_upcase}::SEARCH::ERROR Missing entry for search record"
    warninga = "#{appname_upcase}::SEARCH::ERROR Missing parameter"
    if @search_record_number.blank?
      flash[:notice] = messagea
      logger.warn(warninga)
      logger.warn " #{params[:id]} no longer exists"
      flash.keep
      return false
    end
    @search_query = SearchQuery.find(session[:query]) if session[:query].present?
    response, @next_record, @previous_record = @search_query.bmd_next_and_previous_records(@search_record_number)
    @search_record = response ? @search_query.locate(@search_record_number) : nil
    return false unless response
    true
  end

  def save_entry
    entry_id = params[:id]
    user = UseridDetail.where(id: cookies.signed[:userid]).first
    @entry = BestGuess.where(RecordNumber: entry_id).first
    record_hash = @entry.record_hash
    user.saved_entry << record_hash
    user.save
    if user.save
      flash[:notice] = 'The entry is saved'
    else
      flash[:notice] = 'unsuccessful'
    end
    if params[:search_id].present? 
      redirect_to friendly_bmd_record_details_path(params[:search_id],entry_id, @entry.friendly_url) 
    else 
      redirect_to best_guess_path(@entry.RecordNumber)
    end
  end

  private

  def show_postem_or_scan
    case @option
    when '1'
      show_scans
    when '2'
      list_postems
    end
  end

  def show_scans
    @scan_links = @current_record.uniq_scanlists if @current_record.uniq_scanlists.present?
    @acc_scans = @current_record.get_non_multiple_scans if @current_record.get_non_multiple_scans.present?
    @acc_mul_scans = @current_record.multiple_best_probable_scans if @current_record.multiple_best_probable_scans.present?
  end

  def list_postems
    record_hash_value = @current_record.record_hash
    record_best_guess_hash = BestGuessHash.where(Hash: record_hash_value).first
    @new_postem = record_best_guess_hash.postems.new
    @postem_honeypot = "postem#{rand.to_s[2..11]}"
    session[:postem_honeypot] = @postem_honeypot
  end

end