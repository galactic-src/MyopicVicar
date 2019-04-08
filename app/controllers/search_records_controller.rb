# Copyright 2012 Trustees of FreeBMD
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
#
class SearchRecordsController < ApplicationController
  before_action :viewed
  skip_before_action :require_login
  require 'csv'
  rescue_from Mongo::Error::OperationFailure, with: :catch_error

  def catch_error
    logger.warn("FREEREG:RECORD: Record encountered a problem #{params}")
    flash[:notice] = 'We are sorry but the record you requested no longer exists; possibly as a result of some data being edited. You will need to redo the search with the original criteria to obtain the updated version.'
    redirect_back(fallback_location: new_search_query_path)
  end

  def index
    flash[:notice] = 'That action does not exist'
    redirect_back(fallback_location: new_search_query_path) && return
  end

  def show
    redirect_back(fallback_location: new_search_query_path) && return unless show_value_check

    @display_date = false
    @entry.display_fields(@search_record)
    @entry.acknowledge
    @place_id, @church_id, @register_id, extended_def = @entry.get_location_ids
    @annotations = Annotation.find(@search_record[:annotation_ids]) if @search_record[:annotation_ids]
    if @search_query.present?
      @search_result = @search_query.search_result
      @viewed_records = @search_result.viewed_records
      @viewed_records << params[:id] unless @viewed_records.include?(params[:id])
      @search_result.update_attribute(:viewed_records, @viewed_records)
    end
    @image_id = @entry.get_the_image_id(@church, @user, session[:manage_user_origin], session[:image_server_group_id], session[:chapman_code])
    @order, @array_of_entries, @json_of_entries = @entry.order_fields_for_record_type(@search_record[:record_type], @entry.freereg1_csv_file.def, current_authentication_devise_user.present?)
  end

  def show_print_version
    redirect_back(fallback_location: new_search_query_path) && return unless show_value_check

    @printable_format = true
    @display_date = true
    @entry.display_fields(@search_record)
    @entry.acknowledge
    @place_id, @church_id, @register_id, extended_def = @entry.get_location_ids
    @annotations = Annotation.find(@search_record[:annotation_ids]) if @search_record[:annotation_ids]
    #@search_result = @search_query.search_result
    @all_data = true
    @order, @array_of_entries, @json_of_entries = @entry.order_fields_for_record_type(@search_record[:record_type], @entry.freereg1_csv_file.def, current_authentication_devise_user.present?)
    respond_to do |format|
      format.html { render 'show', layout: false }
      format.json do
        file_name = "search-record-#{@entry.id}.json"
        send_data @json_of_entries.to_json, :type => 'application/json; header=present', :disposition => "attachment; filename=\"#{file_name}\""
      end
      format.csv do
        header_line = CSV.generate_line(@order, options = { :row_sep => "\r\n" })
        data_line = CSV.generate_line(@array_of_entries, options = { :row_sep => "\r\n", :force_quotes => true })
        file_name = "search-record-#{@entry.id}.csv"
        send_data (header_line + data_line), :type => 'text/csv', :disposition => "attachment; filename=\"#{file_name}\""
      end
    end
  end

  def show_value_check
    messagea = 'We are sorry but the record you requested no longer exists; possibly as a result of some data being edited. You will need to redo the search with the original criteria to obtain the updated version.'
    warning = 'FREEREG::SEARCH::ERROR Missing entry for search record'
    warninga = 'FREEREG::SEARCH::ERROR Missing parameter'
    if params[:id].blank?
      flash[:notice] = messagea
      logger.warn(warninga)
      logger.warn " #{params[:id]} no longer exists"
      flash.keep
      return false
    end
    @search_query = SearchQuery.find(session[:query]) if session[:query].present?

    if session[:query].blank? || params[:ucf] == 'true'
      @search_record = SearchRecord.find(params[:id])
    else
      response, @next_record, @previous_record = @search_query.next_and_previous_records(params[:id])
      @search_record = response ? @search_query.locate(params[:id]) : nil
      return false unless response
    end
    if @search_record.blank?
      flash[:notice] = messagea
      logger.warn(warning)
      logger.warn "#{@search_record} no longer exists"
      flash.keep
      return false
    end
    if @search_record[:freereg1_csv_entry_id].blank?
      logger.warn(warning)
      logger.warn "#{@search_record} no longer exists"
      flash[:notice] = messagea
      flash.keep
      return false
    end
    @entry = Freereg1CsvEntry.find(@search_record[:freereg1_csv_entry_id])
    if @entry.blank?
      logger.warn(warning)
      logger.warn "#{@search_record} no longer exists"
      flash[:notice] = messagea
      flash.keep
      return false
    end
    if @entry.freereg1_csv_file.blank?
      logger.warn(warning)
      logger.warn "#{@search_record} no longer exists"
      flash[:notice] = messagea
      flash.keep
      return false
    end
    true
  end

  def viewed
    session[:viewed] ||= []
  end

  # implementation of the citation generator
  def show_citation
    redirect_back(fallback_location: new_search_query_path) && return unless show_value_check

    @printable_format = true
    @display_date = true
    @all_data = true
    @entry.display_fields(@search_record)
    @entry.acknowledge
    @place_id, @church_id, @register_id = @entry.get_location_ids
    @annotations = Annotation.find(@search_record[:annotation_ids]) if @search_record[:annotation_ids]
    #@search_result = @search_query.search_result

    respond_to do |format|
      @viewed_date = Date.today.strftime("%e %b %Y")
      @type = params[:citation_type]
      format.html { render :citation, layout: false }
    end
  end
end
